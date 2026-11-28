import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'database.dart';
import 'models.dart';

/// 备份文件的预览信息
class BackupPreview {
  final int recordCount;
  final int categoryCount;
  final List<String> warnings;
  final String exportedAt;
  final int format;

  const BackupPreview({
    required this.recordCount,
    required this.categoryCount,
    required this.warnings,
    required this.exportedAt,
    required this.format,
  });
}

/// 导入结果
class ImportResult {
  final int imported;
  final int skipped;
  final int categoriesCreated;

  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.categoriesCreated,
  });
}

/// 数据迁移：导出/导入 JSON 备份 + 升级后自动留快照。
///
/// 备份格式（format = 1）：
/// {
///   "app": "my-ledger", "format": 1, "app_version": "1.2.2",
///   "exported_at": "...", "categories": [...], "records": [...]
/// }
///
/// 同时尽量兼容旧版本/不完整的数据：
/// * 没有 categories → 账目按类型归到「其他」
/// * 没有 category_id → 同上
/// * 没有 payment / note / created_at → 用默认值补齐
/// * 金额可能是 amount（元）而不是 amount_cents（分）
/// * 文件顶层直接是数组（只导出了账目）也能导入
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const int formatVersion = 1;
  static const int _keepAutoBackups = 10;
  static const String _prefLastVersion = 'backup_last_version';
  static const String _prefLastAt = 'backup_last_at';
  static const String _prefLastPath = 'backup_last_path';

  final AppDatabase _db = AppDatabase();

  // ---------- 导出 ----------

  Future<Map<String, Object?>> buildPayload() async {
    final categories = await _db.getCategories();
    final records = await _db.getRecords();
    return <String, Object?>{
      'app': 'my-ledger',
      'format': formatVersion,
      'app_version': kAppVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'records': records.map((r) => r.toMap()).toList(),
    };
  }

  Future<String> exportJsonString() async {
    final payload = await buildPayload();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 写一个临时文件用于分享（微信/邮件/网盘）
  Future<File> writeExportFile() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'my-ledger-backup-${_stamp(DateTime.now())}.json'),
    );
    await file.writeAsString(await exportJsonString(), flush: true);
    return file;
  }

  // ---------- 自动备份 ----------

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 版本变化或距上次超过 20 小时时，自动在本机留一份快照。
  /// 返回新快照路径；不需要备份时返回 null。
  Future<String?> autoBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString(_prefLastVersion);
    final lastAt = DateTime.tryParse(prefs.getString(_prefLastAt) ?? '');
    final now = DateTime.now();
    final due = lastVersion != kAppVersion ||
        lastAt == null ||
        now.difference(lastAt) > const Duration(hours: 20);
    if (!due) return null;
    final file = await backupNow();
    return file.path;
  }

  /// 立刻在本机生成一份快照（手动备份/自动备份都走这里）
  Future<File> backupNow() async {
    final dir = await _backupDir();
    final file = File(p.join(dir.path, 'ledger-backup-${_stamp(DateTime.now())}.json'));
    await file.writeAsString(await exportJsonString(), flush: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastVersion, kAppVersion);
    await prefs.setString(_prefLastAt, DateTime.now().toIso8601String());
    await prefs.setString(_prefLastPath, file.path);
    await _prune(dir);
    return file;
  }

  Future<void> _prune(Directory dir) async {
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (var i = _keepAutoBackups; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // 删不掉就留着，不影响主流程
      }
    }
  }

  Future<List<File>> listAutoBackups() async {
    final dir = await _backupDir();
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String?> lastAutoBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLastAt);
  }

  // ---------- 导入 ----------

  Future<BackupPreview> preview(String text) async {
    final root = _rootOf(text);
    final categories = _listOf(root['categories']);
    final records = _listOf(root['records']);

    var valid = 0;
    var missingCategory = 0;
    for (final item in records) {
      if (item is! Map) continue;
      if (_amountOf(item) <= 0) continue;
      valid++;
      if (item['category_id'] == null && item['categoryId'] == null) {
        missingCategory++;
      }
    }

    final warnings = <String>[];
    if (valid == 0) warnings.add('这个文件里没有可导入的账目');
    if (categories.isEmpty) warnings.add('备份里没有分类信息，账目会归到「其他」');
    if (missingCategory > 0) {
      warnings.add('有 $missingCategory 笔没有分类信息，将归到「其他」');
    }
    final app = root['app'];
    if (app != null && app.toString() != 'my-ledger') {
      warnings.add('这不是本 App 导出的文件，会尽量兼容导入');
    }

    return BackupPreview(
      recordCount: valid,
      categoryCount: categories.length,
      warnings: warnings,
      exportedAt: (root['exported_at'] ?? '').toString(),
      format: _asInt(root['format'], 0),
    );
  }

  /// 导入备份。
  /// [replace] 为 true 时用备份覆盖本机全部账目（分类按名称合并，不会丢用户的自定义分类）；
  /// 为 false 时合并，跳过重复的一笔。
  Future<ImportResult> importJson(String text, {bool replace = false}) async {
    final root = _rootOf(text);
    final rawCategories = _listOf(root['categories']);
    final rawRecords = _listOf(root['records']);

    final existing = await _db.getCategories();
    final byNameType = <String, Category>{};
    final byId = <int, Category>{};
    for (final c in existing) {
      byNameType['${c.type}|${c.name}'] = c;
      if (c.id != null) byId[c.id!] = c;
    }

    final idToCat = <String, Category>{};
    var createdCategories = 0;

    for (final item in rawCategories) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final type = item['type'] == 'income' ? 'income' : 'expense';
      final key = '$type|$name';
      var cat = byNameType[key];
      if (cat == null) {
        final color = _asInt(
          item['color'],
          type == 'income' ? 0xFF1D9E75 : 0xFF888780,
        );
        final icon = (item['icon'] ?? name.substring(0, 1)).toString();
        final sortOrder = _asInt(item['sort_order'], 99);
        final isPreset = _asInt(item['is_preset'], 0);
        final id = await _db.insertCategory(Category(
          name: name,
          type: type,
          colorValue: color,
          icon: icon,
          sortOrder: sortOrder,
          isPreset: isPreset,
        ));
        cat = Category(
          id: id,
          name: name,
          type: type,
          colorValue: color,
          icon: icon,
          sortOrder: sortOrder,
          isPreset: isPreset,
        );
        byNameType[key] = cat;
        createdCategories++;
      }
      final oldId = (item['id'] ?? '').toString();
      if (oldId.isNotEmpty) idToCat[oldId] = cat;
    }

    final existingKeys = <String>{};
    if (!replace) {
      for (final r in await _db.getRecords()) {
        existingKeys.add(_keyOf(r));
      }
    }

    final now = DateTime.now();
    final toInsert = <RecordItem>[];
    var skipped = 0;

    for (final item in rawRecords) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final amount = _amountOf(item);
      if (amount <= 0) {
        skipped++;
        continue;
      }
      final type = item['type'] == 'income' ? 'income' : 'expense';
      final date = _asDate(item['date'], now);
      final catKey = (item['category_id'] ?? item['categoryId'] ?? '').toString();
      Category? cat = idToCat[catKey];
      if (cat == null && catKey.isNotEmpty) {
        // 备份里没有分类列表时，尝试直接按原来的 id 对应
        final asId = int.tryParse(catKey);
        if (asId != null) cat = byId[asId];
      }
      cat ??= byNameType['$type|其他'];
      cat ??= _firstOfType(byNameType, type);
      if (cat?.id == null) {
        skipped++;
        continue;
      }
      final record = RecordItem(
        amountCents: amount,
        type: type,
        categoryId: cat!.id!,
        note: (item['note'] ?? '').toString(),
        payment: _paymentOf(item['payment']),
        date: date,
        createdAt: _asDate(item['created_at'] ?? item['createdAt'], date),
      );
      if (!replace && !existingKeys.add(_keyOf(record))) {
        skipped++;
        continue;
      }
      toInsert.add(record);
    }

    if (replace) {
      await _db.replaceRecords(toInsert);
    } else {
      await _db.insertRecords(toInsert);
    }

    return ImportResult(
      imported: toInsert.length,
      skipped: skipped,
      categoriesCreated: createdCategories,
    );
  }

  // ---------- 兼容解析 ----------

  Map<String, dynamic> _rootOf(String text) {
    final dynamic decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    // 旧版本可能只导出了账目数组
    if (decoded is List) return <String, dynamic>{'records': decoded};
    throw const FormatException('不是有效的备份文件');
  }

  List<dynamic> _listOf(dynamic value) => value is List ? value : const [];

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final trimmed = value.trim();
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) return asDouble.round();
    }
    return fallback;
  }

  int _amountOf(Map item) {
    if (item.containsKey('amount_cents')) return _asInt(item['amount_cents']);
    if (item.containsKey('amountCents')) return _asInt(item['amountCents']);
    if (item.containsKey('amount')) {
      final value = item['amount'];
      if (value is num) return (value * 100).round();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return (parsed * 100).round();
    }
    return 0;
  }

  DateTime _asDate(dynamic value, DateTime fallback) {
    if (value is DateTime) return value;
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return fallback;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    // 兼容 "2026-11-20 12:34:56"
    return DateTime.tryParse(text.replaceFirst(' ', 'T')) ?? fallback;
  }

  String _paymentOf(dynamic value) {
    final text = (value ?? '').toString();
    const allowed = {'wechat', 'alipay', 'card', 'cash', 'other'};
    return allowed.contains(text) ? text : 'wechat';
  }

  Category? _firstOfType(Map<String, Category> map, String type) {
    for (final c in map.values) {
      if (c.type == type) return c;
    }
    return null;
  }

  String _keyOf(RecordItem r) =>
      '${r.amountCents}|${r.type}|${r.date.toIso8601String()}|${r.note}';

  String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
