import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart' as theme_file;
import 'database.dart';
import 'models.dart';
import 'presets.dart';

class AppState extends ChangeNotifier {
  final AppDatabase db = AppDatabase();

  List<Category> _categories = [];
  List<Category> get categories => _categories;
  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();
  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();

  theme_file.ThemePreset _theme = theme_file.appThemes.first;
  theme_file.ThemePreset get theme => _theme;

  int _navIndex = 0;
  int get navIndex => _navIndex;
  set navIndex(int value) {
    _navIndex = value;
    notifyListeners();
  }

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> init() async {
    await db.seedCategoriesIfEmpty(allPresets());
    await _loadCategories();
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('theme_key');
    if (key != null) {
      _theme = theme_file.themeByKey(key);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    _categories = await db.getCategories();
    notifyListeners();
  }

  Future<void> setThemeKey(String key) async {
    _theme = theme_file.themeByKey(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_key', key);
    notifyListeners();
  }

  Category? categoryById(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------- 分类操作 ----------

  Future<int> addCategory({
    required String name,
    required String type,
    required int colorValue,
    required String icon,
  }) async {
    final maxSort = _categories
        .where((c) => c.type == type)
        .fold<int>(0, (prev, c) => c.sortOrder > prev ? c.sortOrder : prev);
    final id = await db.insertCategory(Category(
      name: name.trim(),
      type: type,
      colorValue: colorValue,
      icon: icon.trim().isEmpty ? name.trim().substring(0, 1) : icon.trim(),
      sortOrder: maxSort + 1,
      isPreset: 0,
    ));
    await _loadCategories();
    return id;
  }

  Future<void> updateCategory(Category category) async {
    await db.updateCategory(category);
    await _loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await db.deleteCategory(id);
    await _loadCategories();
  }

  // ---------- 账目操作 ----------

  Future<int> addRecord(RecordItem record) async {
    final id = await db.insertRecord(record);
    notifyListeners();
    return id;
  }

  /// 批量导入（账单截图）：只发一次通知
  Future<void> addRecords(List<RecordItem> records) async {
    if (records.isEmpty) return;
    await db.insertRecords(records);
    notifyListeners();
  }

  Future<void> updateRecord(RecordItem record) async {
    await db.updateRecord(record);
    notifyListeners();
  }

  Future<void> deleteRecord(int id) async {
    await db.deleteRecord(id);
    notifyListeners();
  }
}

// 全局单例，供所有页面共享
final AppState appState = AppState();
