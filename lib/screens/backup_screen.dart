import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../data/backup_service.dart';
import '../theme/app_theme.dart';

/// 数据迁移与备份：导出/导入 JSON、自动快照、恢复旧数据
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  int _count = 0;
  String? _lastBackupAt;
  List<File> _autoBackups = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final count = await appState.db.countRecords();
    final lastAt = await BackupService.instance.lastAutoBackupAt();
    final files = await BackupService.instance.listAutoBackups();
    if (!mounted) return;
    setState(() {
      _count = count;
      _lastBackupAt = lastAt;
      _autoBackups = files;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // ---------- 操作 ----------

  Future<void> _backupNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BackupService.instance.backupNow();
      await _load();
      _toast('已在本机生成一份备份');
    } catch (e) {
      _toast('备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await BackupService.instance.writeExportFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '我的账本备份',
        text: '我的账本备份文件，在「设置 → 数据迁移与备份 → 导入备份」里可以恢复。',
      );
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImport() async {
    if (_busy) return;
    try {
      final group = XTypeGroup(label: '备份文件', mimeTypes: ['*/*']);
      final picked = await openFile(acceptedTypeGroups: [group]);
      if (picked == null) return;
      final text = await picked.readAsString();
      await _doImport(text);
    } catch (e) {
      _toast('读取文件失败：$e');
    }
  }

  Future<void> _restoreAuto(File file) async {
    final ok = await _confirm(
      title: '恢复这份备份？',
      message: '会用它覆盖当前的全部账目；分类按名称合并，不会丢你自定义的分类。',
      confirmText: '覆盖恢复',
      danger: true,
    );
    if (ok != true) return;
    try {
      final text = await file.readAsString();
      await _importWithMode(text, replace: true);
    } catch (e) {
      _toast('恢复失败：$e');
    }
  }

  Future<void> _doImport(String text) async {
    final preview = await BackupService.instance.preview(text);
    final mode = await _showImportDialog(preview);
    if (mode == null) return;
    if (mode == 'replace') {
      final ok = await _confirm(
        title: '覆盖导入？',
        message: '当前的 ${_count} 笔账目会被清空，换成备份里的数据。建议先「导出备份」留一份。',
        confirmText: '覆盖导入',
        danger: true,
      );
      if (ok != true) return;
    }
    await _importWithMode(text, replace: mode == 'replace');
  }

  Future<void> _importWithMode(String text, {required bool replace}) async {
    setState(() => _busy = true);
    try {
      final result = await BackupService.instance.importJson(text, replace: replace);
      await appState.reloadData();
      await _load();
      final skipped = result.skipped > 0 ? '，跳过 ${result.skipped} 笔（重复或无金额）' : '';
      final created = result.categoriesCreated > 0 ? '，新建 ${result.categoriesCreated} 个分类' : '';
      _toast('已导入 ${result.imported} 笔$created$skipped');
    } catch (e) {
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- 弹窗 ----------

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final t = appState.theme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text(title, style: TextStyle(fontSize: 16, color: t.text)),
        content: Text(message, style: TextStyle(fontSize: 13, color: t.subText, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: t.subText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText,
                style: TextStyle(color: danger ? Colors.red.shade400 : t.primary)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showImportDialog(BackupPreview p) {
    final t = appState.theme;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('导入备份', style: TextStyle(fontSize: 16, color: t.text)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('账目：${p.recordCount} 笔', style: TextStyle(fontSize: 13, color: t.text)),
              const SizedBox(height: 4),
              Text('分类：${p.categoryCount} 个', style: TextStyle(fontSize: 13, color: t.text)),
              if (p.exportedAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('导出时间：${_readableTime(p.exportedAt)}',
                    style: TextStyle(fontSize: 12, color: t.subText)),
              ],
              for (final w in p.warnings) ...[
                const SizedBox(height: 6),
                Text('· $w', style: TextStyle(fontSize: 12, color: t.subText)),
              ],
              const SizedBox(height: 10),
              Text('合并：保留现有账目，重复的跳过（推荐）。\n覆盖：清空现有账目，完全使用备份。',
                  style: TextStyle(fontSize: 12, color: t.subText, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: t.subText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: Text('合并导入', style: TextStyle(color: t.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: Text('覆盖导入', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }

  String _readableTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _fileLabel(File file) {
    final name = file.uri.pathSegments.last;
    // ledger-backup-20261128-205300.json
    final match = RegExp(r'(\d{8})-(\d{6})').firstMatch(name);
    if (match == null) return name;
    final d = match.group(1)!;
    final t = match.group(2)!;
    return '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
        '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
  }

  // ---------- 界面 ----------

  @override
  Widget build(BuildContext context) {
    final t = appState.theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('数据迁移与备份',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _card(
            t,
            title: '本机数据',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_count 笔账目', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.text)),
                const SizedBox(height: 4),
                Text('升级安装（覆盖安装）不会清空数据；卸载重装才会。',
                    style: TextStyle(fontSize: 12, color: t.subText)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            t,
            title: '自动备份',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lastBackupAt == null
                      ? '还没有自动备份'
                      : '上次备份：${_readableTime(_lastBackupAt!)}',
                  style: TextStyle(fontSize: 12, color: t.subText),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _backupNow,
                    icon: Icon(Icons.save_alt, size: 16, color: t.primary),
                    label: Text('立即备份到本机', style: TextStyle(fontSize: 13, color: t.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_autoBackups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('最近的备份（点一下可恢复）',
                      style: TextStyle(fontSize: 11, color: t.subText)),
                  const SizedBox(height: 6),
                  ..._autoBackups.take(5).map((f) => InkWell(
                        onTap: _busy ? null : () => _restoreAuto(f),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 15, color: t.subText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_fileLabel(f),
                                    style: TextStyle(fontSize: 12, color: t.text)),
                              ),
                              Text('恢复', style: TextStyle(fontSize: 12, color: t.primary)),
                            ],
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            t,
            title: '导出备份',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生成一个 JSON 文件，可发到微信/网盘，换手机或重装后用它恢复。',
                    style: TextStyle(fontSize: 12, color: t.subText, height: 1.5)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _exportShare,
                    icon: const Icon(Icons.ios_share, size: 16, color: Colors.white),
                    label: const Text('导出并分享备份文件', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            t,
            title: '导入备份',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('从手机里选一个备份文件（.json），会先显示有多少笔再确认导入。',
                    style: TextStyle(fontSize: 12, color: t.subText, height: 1.5)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImport,
                    icon: Icon(Icons.file_open_outlined, size: 16, color: t.primary),
                    label: Text('选择备份文件导入', style: TextStyle(fontSize: 13, color: t.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(t.radius),
            ),
            child: Text(
              '说明\n'
              '· 同一个 App 覆盖安装（版本升级）时，系统会保留数据，一般不需要手动迁移。\n'
              '· 卸载重装、换手机、改签名安装时，数据会丢，请先用「导出备份」。\n'
              '· 备份文件只包含账目和分类，不含主题设置。',
              style: TextStyle(fontSize: 11, color: t.subText, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemePreset t, {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
