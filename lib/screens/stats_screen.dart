import 'package:flutter/material.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_state.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/formatters.dart';
import 'category_detail_screen.dart';
import 'record_edit_sheet.dart';

enum RangeMode { week, month, year, custom }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const String _thresholdKey = 'high_value_threshold_cents';

  RangeMode _mode = RangeMode.month;
  DateTime _customFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customTo = DateTime.now();
  int _thresholdCents = 50000; // 默认 500 元
  bool _showIncomeCategories = false;
  bool _highByCategory = false;

  @override
  void initState() {
    super.initState();
    _loadThreshold();
  }

  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_thresholdKey);
    if (value != null && value > 0 && mounted) {
      setState(() => _thresholdCents = value);
    }
  }

  Future<void> _editThreshold() async {
    final t = appState.theme;
    final controller = TextEditingController(
      text: (_thresholdCents / 100).toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('高额支出门槛', style: TextStyle(fontSize: 16, color: t.text)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '¥ ',
            hintText: '例如 500',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: t.subText)),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: Text('保存', style: TextStyle(color: t.primary)),
          ),
        ],
      ),
    );
    if (result == null || result <= 0) {
      controller.dispose();
      return;
    }
    controller.dispose();
    setState(() => _thresholdCents = (result * 100).round());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdKey, _thresholdCents);
  }

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

  Widget _miniToggle(ThemePreset t, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? t.primary : t.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: active ? Colors.white : t.subText),
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
                        const SizedBox(height: 12),
                        _categoryCard(t, data),
                        const SizedBox(height: 12),
                        _highValueCard(t, data),
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

  /// 分类账单：只列出这个时间段里真正用过的分类
  Widget _categoryCard(ThemePreset t, _StatsData data) {
    final isIncome = _showIncomeCategories;
    final totals = isIncome ? data.incomeTotals : data.expenseTotals;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('分类账单', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
              const Spacer(),
              _miniToggle(t, '支出', !isIncome, () => setState(() => _showIncomeCategories = false)),
              const SizedBox(width: 6),
              _miniToggle(t, '收入', isIncome, () => setState(() => _showIncomeCategories = true)),
            ],
          ),
          const SizedBox(height: 4),
          Text('点分类看这一类在这个时间段的账单',
              style: TextStyle(fontSize: 11, color: t.subText)),
          const SizedBox(height: 12),
          if (totals.isEmpty)
            Text('这个时间段没有${isIncome ? '收入' : '支出'}记录',
                style: TextStyle(fontSize: 12, color: t.subText))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: totals.map((ct) {
                final color = isIncome ? t.income : Color(ct.category.colorValue);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryDetailScreen(
                        category: ct.category,
                        type: isIncome ? 'income' : 'expense',
                        initialFrom: _from,
                        initialTo: _to,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 152,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.background.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(ct.category.icon,
                                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ct.category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: t.text),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatMoney(ct.totalCents),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                        ),
                        const SizedBox(height: 2),
                        Text('查看账单 ›', style: TextStyle(fontSize: 10, color: t.subText)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// 高额支出：单笔 / 按分类，两种视角
  Widget _highValueCard(ThemePreset t, _StatsData data) {
    final threshold = formatMoney(_thresholdCents);
    final categories = data.expenseTotals
        .where((c) => c.totalCents >= _thresholdCents)
        .toList()
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
    final records = data.highValueRecords;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('高额支出', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
              const SizedBox(width: 6),
              Text('≥ $threshold', style: TextStyle(fontSize: 11, color: t.subText)),
              const Spacer(),
              TextButton(
                onPressed: _editThreshold,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('改门槛', style: TextStyle(fontSize: 11, color: t.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniToggle(t, '单笔', !_highByCategory, () => setState(() => _highByCategory = false)),
              const SizedBox(width: 6),
              _miniToggle(t, '按分类', _highByCategory, () => setState(() => _highByCategory = true)),
            ],
          ),
          const SizedBox(height: 10),
          if (_highByCategory)
            categories.isEmpty
                ? Text('这个时间段没有超过 $threshold 的分类',
                    style: TextStyle(fontSize: 12, color: t.subText))
                : Column(
                    children: categories.map((c) => _highCategoryRow(t, c)).toList(),
                  )
          else
            records.isEmpty
                ? Text('这个时间段没有超过 $threshold 的单笔支出',
                    style: TextStyle(fontSize: 12, color: t.subText))
                : Column(
                    children: records.map((r) => _highRecordRow(t, r)).toList(),
                  ),
        ],
      ),
    );
  }

  Widget _highCategoryRow(ThemePreset t, CategoryTotal c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: Color(c.category.colorValue), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(c.category.name, style: TextStyle(fontSize: 12, color: t.text))),
          Text(formatMoney(c.totalCents),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.text)),
        ],
      ),
    );
  }

  Widget _highRecordRow(ThemePreset t, RecordItem r) {
    final cat = appState.categoryById(r.categoryId);
    return InkWell(
      onTap: () async {
        final updated = await showRecordEditSheet(context: context, record: r);
        if (updated != null) {
          await appState.updateRecord(updated);
          if (mounted) setState(() {});
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(dateLabel(r.date), style: TextStyle(fontSize: 11, color: t.subText)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${cat?.name ?? ''}${r.note.isEmpty ? '' : ' · ${r.note}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.text),
              ),
            ),
            Text(formatMoney(r.amountCents),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.text)),
          ],
        ),
      ),
    );
  }

  Future<_StatsData> _loadStats() async {
    final db = AppDatabase();
    final summary = await db.getSummary(from: _from, to: _to);
    final expenseTotals = await db.getCategoryTotals(type: 'expense', from: _from, to: _to);
    final incomeTotals = await db.getCategoryTotals(type: 'income', from: _from, to: _to);
    final expenseDaily = await db.getDailyTotals(type: 'expense', from: _from, to: _to);
    final incomeDaily = await db.getDailyTotals(type: 'income', from: _from, to: _to);
    final highValueRecords = await db.getRecords(
      from: _from,
      to: _to,
      type: 'expense',
      minCents: _thresholdCents,
      limit: 50,
    );
    return _StatsData(
      summary: summary,
      expenseTotals: expenseTotals,
      incomeTotals: incomeTotals,
      expenseDaily: expenseDaily,
      incomeDaily: incomeDaily,
      highValueRecords: highValueRecords,
    );
  }
}

class _StatsData {
  final Summary summary;
  final List<CategoryTotal> expenseTotals;
  final List<CategoryTotal> incomeTotals;
  final Map<DateTime, int> expenseDaily;
  final Map<DateTime, int> incomeDaily;
  final List<RecordItem> highValueRecords;

  _StatsData({
    required this.summary,
    required this.expenseTotals,
    required this.incomeTotals,
    required this.expenseDaily,
    required this.incomeDaily,
    required this.highValueRecords,
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
