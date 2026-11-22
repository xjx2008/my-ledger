import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../data/presets.dart';
import '../theme/app_theme.dart';
import 'category_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _type = 'expense';

  List<Category> get _cats => _type == 'expense'
      ? appState.expenseCategories
      : appState.incomeCategories;

  Future<void> _addCategory() async {
    await showCategoryDialog(
      context: context,
      type: _type,
      onSave: (name, color, icon) =>
          appState.addCategory(name: name, type: _type, colorValue: color, icon: icon),
    );
  }

  Future<void> _editCategory(Category cat) async {
    final t = appState.theme;
    final nameController = TextEditingController(text: cat.name);
    final iconController = TextEditingController(text: cat.icon);
    int color = cat.colorValue;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('编辑分类', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: t.text)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: 8,
                style: TextStyle(fontSize: 15, color: t.text),
                decoration: InputDecoration(
                  labelText: '分类名称',
                  labelStyle: TextStyle(color: t.subText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: iconController,
                maxLength: 2,
                style: TextStyle(fontSize: 15, color: t.text),
                decoration: InputDecoration(
                  labelText: '图标文字',
                  labelStyle: TextStyle(color: t.subText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                children: customColors.map((c) {
                  return GestureDetector(
                    onTap: () => setSheet(() => color = c.value),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: color == c.value ? Border.all(color: t.text, width: 2) : null,
                      ),
                      child: color == c.value ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (cat.isPreset == 0)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await appState.deleteCategory(cat.id!);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('删除'),
                      ),
                    ),
                  if (cat.isPreset == 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: saving ? null : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        setSheet(() => saving = true);
                        await appState.updateCategory(cat.copyWith(
                          name: name,
                          icon: iconController.text.trim().isEmpty ? name.substring(0, 1) : iconController.text.trim(),
                          colorValue: color,
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        final cats = _cats;
        final presets = cats.where((c) => c.isPreset == 1).toList();
        final customs = cats.where((c) => c.isPreset == 0).toList();
        return Scaffold(
          backgroundColor: t.background,
          appBar: AppBar(
            backgroundColor: t.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('分类管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: t.text)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      _Tab(label: '支出分类', active: _type == 'expense', t: t, onTap: () => setState(() => _type = 'expense')),
                      _Tab(label: '收入分类', active: _type == 'income', t: t, onTap: () => setState(() => _type = 'income')),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('我的自定义分类', style: TextStyle(fontSize: 13, color: t.subText)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: customs.length + 1,
                  itemBuilder: (context, i) {
                    if (i == customs.length) {
                      return GestureDetector(
                        onTap: _addCategory,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.primary.withOpacity(0.5), width: 1),
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 22, color: t.primary),
                              const SizedBox(height: 6),
                              Text('添加自定义', style: TextStyle(fontSize: 10, color: t.primary)),
                            ],
                          ),
                        ),
                      );
                    }
                    return _CatTile(cat: customs[i], t: t, onTap: () => _editCategory(customs[i]));
                  },
                ),
                const SizedBox(height: 24),
                Text('预设分类（可改名）', style: TextStyle(fontSize: 13, color: t.subText)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (context, i) => _CatTile(cat: presets[i], t: t, onTap: () => _editCategory(presets[i])),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final ThemePreset t;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? t.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: active ? Colors.white : t.subText)),
        ),
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final Category cat;
  final ThemePreset t;
  final VoidCallback onTap;

  const _CatTile({required this.cat, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colorFromValue(cat.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: c.withOpacity(0.16), borderRadius: BorderRadius.circular(t.radius * 0.5)),
              child: Center(child: Text(cat.icon, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c))),
            ),
            const SizedBox(height: 6),
            Text(cat.name, style: TextStyle(fontSize: 11, color: t.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
