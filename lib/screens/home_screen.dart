import 'package:flutter/material.dart' hide Category;

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/payment_badge.dart';
import 'record_edit_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final now = DateTime.now();
  Summary _summary = const Summary(expenseCents: 0, incomeCents: 0);
  List<RecordItem> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
    appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => _load();

  Future<void> _load() async {
    final from = startOfMonth(now);
    final to = endOfMonth(now);
    final summary = await appState.db.getSummary(from: from, to: to);
    final recent = await appState.db.getRecords(limit: 5);
    if (mounted) {
      setState(() {
        _summary = summary;
        _recent = recent;
      });
    }
  }

  Future<void> _editRecord(RecordItem record) async {
    final updated = await showRecordEditSheet(context: context, record: record);
    if (updated != null) {
      await appState.updateRecord(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        final quickCats = appState.expenseCategories.take(4).toList();
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
                    Text(
                      '我的账本',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: t.text,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => appState.navIndex = 4,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                        child: Icon(Icons.palette_rounded, color: t.primary, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SummaryCard(summary: _summary, t: t, monthLabel: monthLabel(now)),
                const SizedBox(height: 24),
                Text(
                  '快速记账',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.text),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: quickCats.length,
                  itemBuilder: (context, i) {
                    final c = quickCats[i];
                    return _QuickCategory(cat: c, t: t);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '最近账单',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.text),
                    ),
                    GestureDetector(
                      onTap: () => appState.navIndex = 2,
                      child: Text(
                        '查看全部',
                        style: TextStyle(fontSize: 12, color: t.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recent.isEmpty)
                  _emptyCard(t)
                else
                  ..._recent.map((r) => GestureDetector(
                    onTap: () => _editRecord(r),
                    child: _RecordRow(record: r, t: t),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyCard(ThemePreset t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 40, color: t.subText.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('还没有账目，去记第一笔吧', style: TextStyle(fontSize: 13, color: t.subText)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Summary summary;
  final ThemePreset t;
  final String monthLabel;

  const _SummaryCard({required this.summary, required this.t, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$monthLabel 支出', style: TextStyle(fontSize: 13, color: t.subText)),
          const SizedBox(height: 6),
          Text(
            formatMoney(summary.expenseCents),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: t.text),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: t.subText.withOpacity(0.15)),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('收入', formatMoney(summary.incomeCents), t.text),
              const SizedBox(width: 32),
              _miniStat('结余', formatMoney(summary.balanceCents), t.income),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: t.subText)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: valueColor)),
      ],
    );
  }
}

class _QuickCategory extends StatelessWidget {
  final Category cat;
  final ThemePreset t;

  const _QuickCategory({required this.cat, required this.t});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        appState.navIndex = 1;
        // 通过全局选中分类通知记账页
        selectedCategoryId.value = cat.id;
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorFromValue(cat.colorValue).withOpacity(0.16),
                borderRadius: BorderRadius.circular(t.radius * 0.5),
              ),
              child: Center(
                child: Text(
                  cat.icon,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorFromValue(cat.colorValue)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(cat.name, style: TextStyle(fontSize: 12, color: t.text)),
          ],
        ),
      ),
    );
  }
}

// 跨页面传递"快捷记账选中的分类"
final ValueNotifier<int?> selectedCategoryId = ValueNotifier<int?>(null);

class _RecordRow extends StatelessWidget {
  final RecordItem record;
  final ThemePreset t;

  const _RecordRow({required this.record, required this.t});

  @override
  Widget build(BuildContext context) {
    final cat = appState.categoryById(record.categoryId);
    final isIncome = record.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isIncome
                  ? t.income.withOpacity(0.16)
                  : colorFromValue(cat?.colorValue ?? 0xFF888780).withOpacity(0.16),
              borderRadius: BorderRadius.circular(t.radius * 0.5),
            ),
            child: Center(
              child: Text(
                cat?.icon ?? '他',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isIncome ? t.income : colorFromValue(cat?.colorValue ?? 0xFF888780),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.note.isEmpty ? (cat?.name ?? '未分类') : record.note,
                  style: TextStyle(fontSize: 13, color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    PaymentBadge(paymentId: record.payment),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${dateLabel(record.date)} ${timeLabel(record.date)}',
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
          Text(
            '${isIncome ? '+' : '-'}${formatAmount(record.amountCents)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isIncome ? t.income : t.text,
            ),
          ),
        ],
      ),
    );
  }
}
