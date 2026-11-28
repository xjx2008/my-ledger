import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ledger.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 从任意旧版本升级：缺表补表、缺列补列，历史数据原样保留
        await _ensureSchema(db);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        // 装回旧包导致降级时也不清库，只把结构补齐
        await _ensureSchema(db);
      },
    );
  }

  /// 幂等的结构检查：任何版本（包括很早的 v1 / 结构不完整的库）都能安全升级。
  /// 只做"补"，从不删数据。
  Future<void> _ensureSchema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((r) => (r['name'] ?? '').toString()).toSet();

    if (!names.contains('categories')) {
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          color INTEGER NOT NULL,
          icon TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_preset INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (!names.contains('records')) {
      await db.execute('''
        CREATE TABLE records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount_cents INTEGER NOT NULL,
          type TEXT NOT NULL,
          category_id INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          payment TEXT NOT NULL DEFAULT 'wechat',
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    // v1 -> v2 的 payment；以及各种历史缺列，统一按需补齐
    await _ensureColumn(db, 'records', 'payment', "TEXT NOT NULL DEFAULT 'wechat'");
    await _ensureColumn(db, 'records', 'note', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'records', 'type', "TEXT NOT NULL DEFAULT 'expense'");
    await _ensureColumn(db, 'records', 'amount_cents', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'records', 'category_id', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'records', 'date', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'records', 'created_at', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'categories', 'sort_order', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'categories', 'is_preset', 'INTEGER NOT NULL DEFAULT 0');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_date ON records(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_type ON records(type)');
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String ddl,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final has = info.any((row) => (row['name'] ?? '').toString() == column);
    if (!has) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $ddl');
    }
  }

  // ---------- 分类 ----------

  Future<List<Category>> getCategories({String? type}) async {
    final db = await database;
    final rows = type == null
        ? await db.query('categories', orderBy: 'sort_order ASC, id ASC')
        : await db.query(
            'categories',
            where: 'type = ?',
            whereArgs: [type],
            orderBy: 'sort_order ASC, id ASC',
          );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    map.remove('id');
    return db.insert('categories', map);
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    // 该分类下的账目改归到"其他"分类，避免孤儿数据
    final others = await db.query(
      'categories',
      where: 'type = (SELECT type FROM categories WHERE id = ?) AND name = ?',
      whereArgs: [id, '其他'],
      limit: 1,
    );
    int fallbackId;
    if (others.isNotEmpty && others.first['id'] != id) {
      fallbackId = others.first['id'] as int;
    } else {
      final any = await db.query(
        'categories',
        where: 'id != ?',
        whereArgs: [id],
        limit: 1,
      );
      if (any.isEmpty) return 0; // 不允许删掉最后一个分类
      fallbackId = any.first['id'] as int;
    }
    await db.update(
      'records',
      {'category_id': fallbackId},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> seedCategoriesIfEmpty(List<Category> presets) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;
    if (count > 0) return;
    final batch = db.batch();
    for (final c in presets) {
      final map = c.toMap();
      map.remove('id');
      batch.insert('categories', map);
    }
    await batch.commit(noResult: true);
  }

  // ---------- 账目 ----------

  Future<int> insertRecord(RecordItem record) async {
    final db = await database;
    final map = record.toMap();
    map.remove('id');
    return db.insert('records', map);
  }

  /// 批量插入（账单截图导入用）：一个事务写完，避免逐条提交
  Future<void> insertRecords(List<RecordItem> records) async {
    if (records.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      final map = record.toMap();
      map.remove('id');
      batch.insert('records', map);
    }
    await batch.commit(noResult: true);
  }

  /// 用一批账目替换全部账目（恢复备份的"覆盖"模式）：
  /// 删除和插入在同一个事务里，中途失败不会留下半截数据。
  Future<void> replaceRecords(List<RecordItem> records) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('records');
      final batch = txn.batch();
      for (final record in records) {
        final map = record.toMap();
        map.remove('id');
        batch.insert('records', map);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> countRecords() async {
    final db = await database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM records'),
    );
    return value ?? 0;
  }

  Future<int> updateRecord(RecordItem record) async {
    final db = await database;
    return db.update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecordItem>> getRecords({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await database;
    final buffer = StringBuffer();
    final args = <Object?>[];
    if (from != null || to != null) {
      buffer.write(' WHERE ');
      final clauses = <String>[];
      if (from != null) {
        clauses.add('date >= ?');
        args.add(from.toIso8601String());
      }
      if (to != null) {
        clauses.add('date <= ?');
        args.add(to.toIso8601String());
      }
      buffer.write(clauses.join(' AND '));
    }
    final sql = StringBuffer('SELECT * FROM records')
      ..write(buffer.toString())
      ..write(' ORDER BY date DESC, id DESC');
    if (limit != null) {
      sql.write(' LIMIT ?');
      args.add(limit);
    }
    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map(RecordItem.fromMap).toList();
  }

  Future<Summary> getSummary({DateTime? from, DateTime? to}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final where = clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}';
    final rows = await db.rawQuery(
      'SELECT type, SUM(amount_cents) AS total FROM records$where GROUP BY type',
      args,
    );
    int expense = 0;
    int income = 0;
    for (final row in rows) {
      final total = (row['total'] as int?) ?? 0;
      if (row['type'] == 'expense') {
        expense = total;
      } else if (row['type'] == 'income') {
        income = total;
      }
    }
    return Summary(expenseCents: expense, incomeCents: income);
  }

  Future<List<CategoryTotal>> getCategoryTotals({
    required String type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final clauses = <String>["r.type = ?"];
    final args = <Object?>[type];
    if (from != null) {
      clauses.add('r.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('r.date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.rawQuery(
      '''
      SELECT c.*, SUM(r.amount_cents) AS total
      FROM records r
      JOIN categories c ON c.id = r.category_id
      WHERE ${clauses.join(' AND ')}
      GROUP BY c.id
      HAVING total > 0
      ORDER BY total DESC
      ''',
      args,
    );
    return rows.map((row) {
      final catMap = <String, Object?>{
        'id': row['id'],
        'name': row['name'],
        'type': row['type'],
        'color': row['color'],
        'icon': row['icon'],
        'sort_order': row['sort_order'],
        'is_preset': row['is_preset'],
      };
      return CategoryTotal(
        category: Category.fromMap(catMap),
        totalCents: (row['total'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<Map<DateTime, int>> getDailyTotals({
    required String type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final clauses = <String>["type = ?"];
    final args = <Object?>[type];
    if (from != null) {
      clauses.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.rawQuery(
      '''
      SELECT substr(date, 1, 10) AS day, SUM(amount_cents) AS total
      FROM records
      WHERE ${clauses.join(' AND ')}
      GROUP BY day
      ORDER BY day ASC
      ''',
      args,
    );
    final result = <DateTime, int>{};
    for (final row in rows) {
      final day = DateTime.parse(row['day'] as String);
      result[day] = (row['total'] as int?) ?? 0;
    }
    return result;
  }
}
