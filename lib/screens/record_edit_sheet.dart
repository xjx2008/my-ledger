import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../data/presets.dart';

/// 编辑已有账目：返回更新后的 RecordItem；取消返回 null
Future<RecordItem?> showRecordEditSheet({
  required BuildContext context,
  required RecordItem record,
}) {
  return showModalBottomSheet<RecordItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordEditSheet(record: record),
  );
}

class _RecordEditSheet extends StatefulWidget {
  final RecordItem record;

  const _RecordEditSheet({required this.record});

  @override
  State<_RecordEditSheet> createState() => _RecordEditSheetState();
}

class _RecordEditSheetState extends State<_RecordEditSheet> {
  late String _type;
  late String _payment;
  late DateTime _date;
  late int? _categoryId;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.record.type;
    _payment = widget.record.payment;
    _date = widget.record.date;
    _categoryId = widget.record.categoryId;
    _amountCtrl = TextEditingController(
      text: (widget.record.amountCents / 100).toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController(text: widget.record.note);
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
    if (_categoryId == null || !_cats.any((c) => c.id == _categoryId)) {
      _categoryId = _cats.isNotEmpty ? _cats.first.id : null;
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
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    final catId = _categoryId;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额要大于 0'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (catId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类'), duration: Duration(seconds: 2)),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.record.copyWith(
        amountCents: (amount * 100).round(),
        type: _type,
        categoryId: catId,
        note: _noteCtrl.text.trim(),
        payment: _payment,
        date: _date,
      ),
    );
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
                Text('编辑账目',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
                const SizedBox(height: 14),

                // 收支类型
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

                // 金额
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

                // 分类
                Text('分类', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: cats.map((c) {
                    final selected = c.id == _categoryId;
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: selected,
                      selectedColor: Color(c.colorValue).withOpacity(0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: selected ? Color(c.colorValue) : t.subText,
                      ),
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 支付方式
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

                // 日期
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
                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 14, color: t.text),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 备注
                Text('备注', style: TextStyle(fontSize: 12, color: t.subText)),
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
