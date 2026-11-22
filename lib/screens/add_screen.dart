import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../data/presets.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import 'home_screen.dart' show selectedCategoryId;
import 'category_dialog.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  String _type = 'expense';
  String _input = '0';
  int? _selectedCatId;
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String _payment = 'wechat';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    selectedCategoryId.addListener(_onQuickCat);
    _applyQuickCat();
  }

  void _onQuickCat() {
    if (selectedCategoryId.value != null) _applyQuickCat();
  }

  void _applyQuickCat() {
    final id = selectedCategoryId.value;
    if (id == null) return;
    final cat = appState.categoryById(id);
    if (cat == null) return;
    if (mounted) {
      setState(() {
        _type = cat.type;
        _selectedCatId = cat.id;
        _input = '0';
        _noteController.clear();
        _date = DateTime.now();
      });
    }
    selectedCategoryId.value = null;
  }

  @override
  void dispose() {
    selectedCategoryId.removeListener(_onQuickCat);
    _noteController.dispose();
    super.dispose();
  }

  List<Category> get _cats => _type == 'expense'
      ? appState.expenseCategories
      : appState.incomeCategories;

  void _setType(String type) {
    setState(() {
      _type = type;
      _selectedCatId = null;
    });
  }

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'back') {
        if (_input.length <= 1) {
          _input = '0';
        } else {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (key == '.') {
        if (!_input.contains('.')) _input = '$_input.';
      } else {
        if (_input == '0') {
          _input = key;
        } else if (_input.contains('.') && _input.split('.')[1].length >= 2) {
          return;
        } else if (_input.replaceAll('.', '').length >= 9) {
          return;
        } else {
          _input += key;
        }
      }
    });
  }

  int get _amountCents {
    final value = double.tryParse(_input) ?? 0;
    return (value * 100).round();
  }

  bool get _canSave => _amountCents > 0 && _selectedCatId != null;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    await appState.addRecord(RecordItem(
      amountCents: _amountCents,
      type: _type,
      categoryId: _selectedCatId!,
      note: _noteController.text.trim(),
      payment: _payment,
      date: _date,
      createdAt: DateTime.now(),
    ));
    if (mounted) {
      setState(() {
        _input = '0';
        _noteController.clear();
        _selectedCatId = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _openCustomCategory() async {
    final created = await showCategoryDialog(
      context: context,
      type: _type,
      onSave: (name, color, icon) async {
        return appState.addCategory(
          name: name,
          type: _type,
          colorValue: color,
          icon: icon,
        );
      },
    );
    if (created == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        final cats = _cats;
        return Scaffold(
          backgroundColor: t.background,
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('记一笔', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.text)),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _TypeTab(label: '支出', active: _type == 'expense', t: t, onTap: () => _setType('expense')),
                            _TypeTab(label: '收入', active: _type == 'income', t: t, onTap: () => _setType('income')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Column(
                          children: [
                            Text('金额', style: TextStyle(fontSize: 12, color: t.subText)),
                            const SizedBox(height: 6),
                            Text(
                              '¥ $_input',
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: t.text),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('支付方式', style: TextStyle(fontSize: 13, color: t.subText)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: paymentPresets
                            .map((p) => _PaymentChip(
                                  method: p,
                                  selected: _payment == p.id,
                                  t: t,
                                  onTap: () => setState(() => _payment = p.id),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      Text('选择分类', style: TextStyle(fontSize: 13, color: t.subText)),
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
                        itemCount: cats.length + 1,
                        itemBuilder: (context, i) {
                          if (i == cats.length) {
                            return _CustomCatButton(t: t, onTap: _openCustomCategory);
                          }
                          final c = cats[i];
                          return _CatChip(
                            cat: c,
                            selected: _selectedCatId == c.id,
                            t: t,
                            onTap: () => setState(() => _selectedCatId = c.id),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: t.subText),
                              const SizedBox(width: 10),
                              Text('${dateLabel(_date)} · ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 13, color: t.text)),
                              const Spacer(),
                              Icon(Icons.chevron_right, size: 16, color: t.subText),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                        child: TextField(
                          controller: _noteController,
                          style: TextStyle(fontSize: 13, color: t.text),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '备注（可选）',
                            hintStyle: TextStyle(fontSize: 13, color: t.subText.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _Keypad(t: t, onKey: _onKey, onSave: _save, canSave: _canSave, saving: _saving),
            ],
          ),
        );
      },
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool active;
  final ThemePreset t;
  final VoidCallback onTap;

  const _TypeTab({required this.label, required this.active, required this.t, required this.onTap});

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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: active ? Colors.white : t.subText),
          ),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final Category cat;
  final bool selected;
  final ThemePreset t;
  final VoidCallback onTap;

  const _CatChip({required this.cat, required this.selected, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colorFromValue(cat.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.14) : t.card,
          border: selected ? Border.all(color: c, width: 1.5) : null,
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.withOpacity(0.18),
                borderRadius: BorderRadius.circular(t.radius * 0.5),
              ),
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

class _CustomCatButton extends StatelessWidget {
  final ThemePreset t;
  final VoidCallback onTap;

  const _CustomCatButton({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.primary.withOpacity(0.4), width: 1),
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 22, color: t.primary),
            const SizedBox(height: 6),
            Text('自定义', style: TextStyle(fontSize: 11, color: t.primary)),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ThemePreset t;
  final void Function(String) onKey;
  final VoidCallback onSave;
  final bool canSave;
  final bool saving;

  const _Keypad({required this.t, required this.onKey, required this.onSave, required this.canSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'back'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: canSave ? onSave : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: canSave ? t.primary : t.subText.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...keys.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: row.map((k) => Expanded(child: _KeyButton(keyLabel: k, t: t, onTap: () => onKey(k)))).toList(),
                ),
              )),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String keyLabel;
  final ThemePreset t;
  final VoidCallback onTap;

  const _KeyButton({required this.keyLabel, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Center(
          child: keyLabel == 'back'
              ? Icon(Icons.backspace_outlined, size: 20, color: t.text)
              : Text(keyLabel, style: TextStyle(fontSize: 20, color: t.text)),
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final ThemePreset t;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.method,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Color(method.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.13) : t.card,
          border: Border.all(
            color: selected ? c : t.subText.withOpacity(0.2),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: c.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(method.icon,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              method.name,
              style: TextStyle(
                fontSize: 12,
                color: selected ? c : t.text,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
