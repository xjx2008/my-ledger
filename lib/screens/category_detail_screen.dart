import 'package:flutter/material.dart' hide Category;

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/payment_badge.dart';
import 'record_edit_sheet.dart';

/// 单个分类的账单明细：可以自己选日期范围
class CategoryDetailScreen extends StatefulWidget {
  final Category category;
  final String type; // expense / income
  final DateTime initialFrom;
  final DateTime initialTo;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.type,
    required this.initialFrom,
    required this.initialTo,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late DateTime _from;
  late DateTime _to;
  List<RecordItem> _records = [];
  int _totalCents = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _from = startOfDay(widget.initialFrom);
    _to = endOfDay(widget.initialTo);
    _load();
  }

  Future<void> _load() async {
    final id = widget.category.id;
    final records = id == null
        ? <RecordItem>[]
        : await appState.db.getRecords(from: _from, to: _to, categoryId: id);
    var total = 0;
    for (final r in records) {
      total += r.amountCents;
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _totalCents = total;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: '选择统计区间',
      saveText: '确定',
    );
    if (range == null) return;
    setState(() {
      _from = startOfDay(range.start);
      _to = endOfDay(range.end);
      _loading = true;
    });
    await _load();
  }

  Future<void> _editRecord(RecordItem record) async {
    final updated = await showRecordEditSheet(context: context, record: record);
    if (updated == null) return;
    await appState.updateRecord(updated);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = appState.theme;
    final isIncome = widget.type == 'income';
    final catColor = isIncome ? t.income : Color(widget.category.colorValue);
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  widget.category.icon,
                  style: TextStyle(fontSize: 12, color: catColor, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.category.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.text),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(t.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncome ? '收入合计' : '支出合计',
                    style: TextStyle(fontSize: 11, color: t.subText),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(_totalCents),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: isIncome ? t.income : t.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '共 ${_records.length} 笔',
                          style: TextStyle(fontSize: 12, color: t.subText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.primary.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, size: 15, color: t.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${shortDate(_from)} 至 ${shortDate(_to)}',
                            style: TextStyle(fontSize: 12, color: t.text),
                          ),
                          const Spacer(),
                          Text('点此改日期', style: TextStyle(fontSize: 11, color: t.subText)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: t.primary))
                : _records.isEmpty
                    ? Center(
                        child: Text(
                          '这个时间段没有「${widget.category.name}」的${isIncome ? '收入' : '支出'}',
                          style: TextStyle(fontSize: 13, color: t.subText),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = _records[i];
                          return InkWell(
                            onTap: () => _editRecord(r),
                            borderRadius: BorderRadius.circular(t.radius),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: t.card,
                                borderRadius: BorderRadius.circular(t.radius),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.note.isEmpty ? widget.category.name : r.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, color: t.text),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${dateLabel(r.date)} ${timeLabel(r.date)}',
                                              style: TextStyle(fontSize: 11, color: t.subText),
                                            ),
                                            const SizedBox(width: 6),
                                            PaymentBadge(paymentId: r.payment),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${isIncome ? '+' : '-'}${formatAmount(r.amountCents)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isIncome ? t.income : t.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
