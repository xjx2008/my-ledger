import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/bill_parser.dart';
import '../data/models.dart';
import '../data/presets.dart';

/// 编辑识别出来的某一笔（导入前的草稿）
Future<void> showBillDraftEditSheet({
  required BuildContext context,
  required BillDraft draft,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DraftEditSheet(draft: draft),
  );
}

class _DraftEditSheet extends StatefulWidget {
  final BillDraft draft;

  const _DraftEditSheet({required this.draft});

  @override
  State<_DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends State<_DraftEditSheet> {
  late String _type;
  late String _payment;
  late String _categoryName;
  late DateTime? _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.draft.type;
    _payment = widget.draft.payment;
    _categoryName = widget.draft.categoryName;
    _date = widget.draft.date;
    _amountCtrl = TextEditingController(
      text: (widget.draft.amountCents / 100).toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController(text: widget.draft.merchant);
    _ensureCategory();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<Category> get _cats =>
      _type == 'income' ? appState.incomeCategories : appState.expenseCategories;

  void _ensureCategory() {
    final has = _cats.any((c) => c.name == _categoryName);
    if (!has) {
      _categoryName = _cats.isNotEmpty ? _cats.first.name : '';
    }
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _ensureCategory();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        final base = _date;
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          base?.hour ?? 0,
          base?.minute ?? 0,
        );
      });
    }
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额要大于 0'), duration: Duration(seconds: 2)),
      );
      return;
    }
    widget.draft
      ..merchant = _noteCtrl.text.trim()
      ..amountCents = (amount * 100).round()
      ..type = _type
      ..categoryName = _categoryName
      ..payment = _payment
      ..date = _date;
    Navigator.pop(context);
  }

  String get _dateLabel {
    final d = _date;
    if (d == null) return '未识别到，点此选择';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = appState.theme;
    final cats = _cats;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.subText.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('修改这一笔',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
                const SizedBox(height: 4),
                Text('改好点保存，再回到列表勾选导入',
                    style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    _TypeChip(
                      label: '支出',
                      selected: _type == 'expense',
                      color: t.primary,
                      onTap: () => _setType('expense'),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: '收入',
                      selected: _type == 'income',
                      color: t.income,
                      onTap: () => _setType('income'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text('金额', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.text),
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    prefixStyle: TextStyle(fontSize: 18, color: t.text),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                Text('商户 / 备注', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  style: TextStyle(fontSize: 14, color: t.text),
                  decoration: InputDecoration(
                    hintText: '例如：美团外卖',
                    hintStyle: TextStyle(fontSize: 13, color: t.subText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                Text('分类', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: cats.map((c) {
                    final selected = c.name == _categoryName;
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: selected,
                      selectedColor: Color(c.colorValue).withOpacity(0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: selected ? Color(c.colorValue) : t.subText,
                      ),
                      onSelected: (_) => setState(() => _categoryName = c.name),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text('支付方式', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: paymentPresets.map((p) {
                    final selected = p.id == _payment;
                    return ChoiceChip(
                      label: Text(p.name),
                      selected: selected,
                      selectedColor: Color(p.colorValue).withOpacity(0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: selected ? Color(p.colorValue) : t.subText,
                      ),
                      onSelected: (_) => setState(() => _payment = p.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text('日期', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.subText.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: t.subText),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: _date == null ? t.subText : t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('取消', style: TextStyle(color: t.subText)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('保存修改'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withOpacity(0.18),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? color : appState.theme.subText,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
