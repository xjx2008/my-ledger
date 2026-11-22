import 'package:flutter/material.dart' hide Category;

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/payment_badge.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<RecordItem> _records = [];
  Summary _summary = const Summary(expenseCents: 0, incomeCents: 0);

  @override
  void initState() {
    super.initState();
    _load();
    appState.addListener(_onChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => _load();

  Future<void> _load() async {
    final from = startOfMonth(_month);
    final to = endOfMonth(_month);
    final records = await appState.db.getRecords(from: from, to: to);
    final summary = await appState.db.getSummary(from: from, to: to);
    if (mounted) setState(() { _records = records; _summary = summary; });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  Map<DateTime, List<RecordItem>> _grouped() {
    final map = <DateTime, List<RecordItem>>{};
    for (final r in _records) {
      final day = startOfDay(r.date);
      map.putIfAbsent(day, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        final grouped = _grouped();
        final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
        return Scaffold(
          backgroundColor: t.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('明细', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.text)),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _shiftMonth(-1),
                          child: Icon(Icons.chevron_left, color: t.subText, size: 22),
                        ),
                        Text(monthLabel(_month), style: TextStyle(fontSize: 13, color: t.text)),
                        GestureDetector(
                          onTap: () => _shiftMonth(1),
                          child: Icon(Icons.chevron_right, color: t.subText, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                  child: Row(
                    children: [
                      Expanded(child: _Stat(label: '支出', value: formatMoney(_summary.expenseCents), color: t.text, sub: t.subText)),
                      Container(width: 1, height: 34, color: t.subText.withOpacity(0.15)),
                      Expanded(child: _Stat(label: '收入', value: formatMoney(_summary.incomeCents), color: t.income, sub: t.subText)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (days.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                    child: Center(child: Text('这个月还没有账目', style: TextStyle(fontSize: 13, color: t.subText))),
                  )
                else
                  ...days.map((day) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2, bottom: 8, top: 6),
                            child: Text(dateLabel(day), style: TextStyle(fontSize: 12, color: t.subText)),
                          ),
                          ...grouped[day]!.map((r) => _RecordTile(record: r, t: t, onChanged: _load)),
                          const SizedBox(height: 10),
                        ],
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color sub;

  const _Stat({required this.label, required this.value, required this.color, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: sub)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final RecordItem record;
  final ThemePreset t;
  final VoidCallback onChanged;

  const _RecordTile({required this.record, required this.t, required this.onChanged});

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text('删除这笔账', style: TextStyle(color: Colors.red.shade400)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await appState.deleteRecord(record.id!);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = appState.categoryById(record.categoryId);
    final isIncome = record.type == 'income';
    final c = isIncome ? t.income : colorFromValue(cat?.colorValue ?? 0xFF888780);
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(t.radius * 0.5),
              ),
              child: Center(child: Text(cat?.icon ?? '他', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.note.isEmpty ? (cat?.name ?? '未分类') : record.note,
                      style: TextStyle(fontSize: 13, color: t.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      PaymentBadge(paymentId: record.payment),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${cat?.name ?? ''} · ${timeLabel(record.date)}',
                          style: TextStyle(fontSize: 11, color: t.subText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text('${isIncome ? '+' : '-'}${formatAmount(record.amountCents)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isIncome ? t.income : t.text)),
          ],
        ),
      ),
    );
  }
}
