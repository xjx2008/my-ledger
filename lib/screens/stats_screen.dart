import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/formatters.dart';

enum RangeMode { week, month, year, custom }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  RangeMode _mode = RangeMode.month;
  DateTime _customFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customTo = DateTime.now();

  DateTime get _from {
    final now = DateTime.now();
    switch (_mode) {
      case RangeMode.week:
        return startOfWeek(now);
      case RangeMode.month:
        return startOfMonth(now);
      case RangeMode.year:
        return startOfYear(now);
      case RangeMode.custom:
        return startOfDay(_customFrom);
    }
  }

  DateTime get _to {
    final now = DateTime.now();
    switch (_mode) {
      case RangeMode.week:
        return endOfWeek(now);
      case RangeMode.month:
        return endOfMonth(now);
      case RangeMode.year:
        return endOfYear(now);
      case RangeMode.custom:
        return endOfDay(_customTo);
    }
  }

  Future<void> _pickRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _customFrom,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择起始日期',
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _customTo.isBefore(from) ? from : _customTo,
      firstDate: from,
      lastDate: DateTime.now(),
      helpText: '选择结束日期',
    );
    if (to == null) return;
    setState(() {
      _customFrom = from;
      _customTo = to;
    });
  }

  Widget _modeTab(String label, RangeMode mode, ThemePreset t) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? t.primary : t.card,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: active ? Colors.white : t.subText),
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
        return Scaffold(
          backgroundColor: t.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('统计', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.text)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _modeTab('周', RangeMode.week, t),
                    const SizedBox(width: 6),
                    _modeTab('月', RangeMode.month, t),
                    const SizedBox(width: 6),
                    _modeTab('年', RangeMode.year, t),
                    const SizedBox(width: 6),
                    _modeTab('自定义', RangeMode.custom, t),
                  ],
                ),
                const SizedBox(height: 12),
                if (_mode == RangeMode.custom)
                  GestureDetector(
                    onTap: _pickRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.primary.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(shortDate(_customFrom), style: TextStyle(fontSize: 12, color: t.text)),
                          Icon(Icons.arrow_forward, size: 14, color: t.subText),
                          Text(shortDate(_customTo), style: TextStyle(fontSize: 12, color: t.text)),
                          Icon(Icons.calendar_month_rounded, size: 16, color: t.primary),
                        ],
                      ),
                    ),
                  ),
                if (_mode == RangeMode.custom) const SizedBox(height: 12),
                FutureBuilder<_StatsData>(
                  future: _loadStats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: t.primary)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: Text('加载失败', style: TextStyle(color: t.subText, fontSize: 13))),
                      );
                    }
                    final data = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatCard(label: '支出', value: formatAmount(data.summary.expenseCents), color: t.text, t: t),
                            const SizedBox(width: 8),
                            _StatCard(label: '收入', value: formatAmount(data.summary.incomeCents), color: t.income, t: t),
                            const SizedBox(width: 8),
                            _StatCard(label: '结余', value: formatAmount(data.summary.balanceCents), color: t.primary, t: t),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('支出分类占比', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
                              const SizedBox(height: 14),
                              PieChart(data: data.expenseTotals, t: t, totalCents: data.summary.expenseCents),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('收支趋势', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
                              const SizedBox(height: 12),
                              TrendChart(
                                incomeData: data.incomeDaily,
                                expenseData: data.expenseDaily,
                                t: t,
                                from: _from,
                                to: _to,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_StatsData> _loadStats() async {
    final db = AppDatabase();
    final summary = await db.getSummary(from: _from, to: _to);
    final expenseTotals = await db.getCategoryTotals(type: 'expense', from: _from, to: _to);
    final expenseDaily = await db.getDailyTotals(type: 'expense', from: _from, to: _to);
    final incomeDaily = await db.getDailyTotals(type: 'income', from: _from, to: _to);
    return _StatsData(
      summary: summary,
      expenseTotals: expenseTotals,
      expenseDaily: expenseDaily,
      incomeDaily: incomeDaily,
    );
  }
}

class _StatsData {
  final Summary summary;
  final List<CategoryTotal> expenseTotals;
  final Map<DateTime, int> expenseDaily;
  final Map<DateTime, int> incomeDaily;

  _StatsData({
    required this.summary,
    required this.expenseTotals,
    required this.expenseDaily,
    required this.incomeDaily,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemePreset t;

  const _StatCard({required this.label, required this.value, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: t.subText)),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
