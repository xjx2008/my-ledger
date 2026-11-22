import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../data/presets.dart';
import '../theme/app_theme.dart';

Future<bool> showCategoryDialog({
  required BuildContext context,
  required String type,
  Category? existing,
  required Future<int> Function(String name, int color, String icon) onSave,
}) async {
  final t = appState.theme;
  final nameController = TextEditingController(text: existing?.name ?? '');
  final iconController = TextEditingController(text: existing?.icon ?? '');
  int color = existing?.colorValue ?? customColors.first.value;
  bool saving = false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
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
                Text(
                  existing == null ? '新增分类' : '编辑分类',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: t.text),
                ),
                Text(
                  type == 'expense' ? '支出分类' : '收入分类',
                  style: TextStyle(fontSize: 12, color: t.subText),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 8,
                  style: TextStyle(fontSize: 15, color: t.text),
                  decoration: InputDecoration(
                    labelText: '分类名称',
                    labelStyle: TextStyle(color: t.subText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  maxLength: 2,
                  style: TextStyle(fontSize: 15, color: t.text),
                  decoration: InputDecoration(
                    labelText: '图标文字（1个字，留空取名称首字）',
                    labelStyle: TextStyle(color: t.subText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('选个颜色', style: TextStyle(fontSize: 13, color: t.subText)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: customColors.map((c) {
                    final selected = color == c.value;
                    return GestureDetector(
                      onTap: () => setSheetState(() => color = c.value),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected ? Border.all(color: t.text, width: 2) : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(content: Text('请输入分类名称')),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            await onSave(name, color, iconController.text.trim());
                            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                          },
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('保存', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  nameController.dispose();
  iconController.dispose();
  return result ?? false;
}
