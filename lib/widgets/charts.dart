import 'dart:math' as math;

import 'package:flutter/material.dart' hide Category;

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';

class PieChart extends StatelessWidget {
  final List<CategoryTotal> data;
  final ThemePreset t;
  final int totalCents;

  const PieChart({super.key, required this.data, required this.t, required this.totalCents});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || totalCents <= 0) {
      return SizedBox(
        height: 130,
        child: Center(child: Text('暂无数据', style: TextStyle(fontSize: 12, color: t.subText))),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _PiePainter(data: data, total: totalCents.toDouble(), holeColor: t.card),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.take(5).map((item) {
              final pct = (item.totalCents / totalCents * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: colorFromValue(item.category.colorValue), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.category.name, style: TextStyle(fontSize: 11, color: t.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('$pct%', style: TextStyle(fontSize: 11, color: t.subText)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<CategoryTotal> data;
  final double total;
  final Color holeColor;

  _PiePainter({required this.data, required this.total, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    double current = startAngle;

    for (final item in data) {
      final sweep = item.totalCents / total * math.pi * 2;
      final paint = Paint()
        ..color = colorFromValue(item.category.colorValue)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, current, sweep, true, paint);
      current += sweep;
    }

    // 中心用卡片色覆盖成环形
    final holeRadius = radius * 0.58;
    canvas.drawCircle(center, holeRadius, Paint()..color = holeColor);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.data != data || old.total != total || old.holeColor != holeColor;
}

class TrendChart extends StatelessWidget {
  final Map<DateTime, int> incomeData;
  final Map<DateTime, int> expenseData;
  final ThemePreset t;
  final DateTime from;
  final DateTime to;

  const TrendChart({
    super.key,
    required this.incomeData,
    required this.expenseData,
    required this.t,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    if (incomeData.isEmpty && expenseData.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(child: Text('暂无数据', style: TextStyle(fontSize: 12, color: t.subText))),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              income: incomeData,
              expense: expenseData,
              from: from,
              to: to,
              incomeColor: t.income,
              expenseColor: t.primary,
              gridColor: t.subText.withOpacity(0.15),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [Container(width: 10, height: 3, color: t.income), const SizedBox(width: 5), Text('收入', style: TextStyle(fontSize: 11, color: t.subText))]),
            const SizedBox(width: 18),
            Row(children: [Container(width: 10, height: 3, color: t.primary), const SizedBox(width: 5), Text('支出', style: TextStyle(fontSize: 11, color: t.subText))]),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final Map<DateTime, int> income;
  final Map<DateTime, int> expense;
  final DateTime from;
  final DateTime to;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;

  _TrendPainter({
    required this.income,
    required this.expense,
    required this.from,
    required this.to,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = 6.0;
    final right = size.width - 6;
    final top = 8.0;
    final bottom = size.height - 18;

    // 网格线
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = top + (bottom - top) / 3 * i;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    final allDays = {...income.keys, ...expense.keys}.toList()..sort();
    if (allDays.isEmpty) return;
    final start = startOfDay(from);
    final end = startOfDay(to);
    final span = end.difference(start).inDays;
    final allValues = [...income.values, ...expense.values];
    final maxValue = allValues.reduce(math.max).toDouble();
    if (maxValue <= 0) return;

    double xOf(DateTime d) {
      final dayDiff = startOfDay(d).difference(start).inDays;
      if (span <= 0) return (left + right) / 2;
      return left + (dayDiff / span) * (right - left);
    }

    double yOf(int value) => bottom - (value / maxValue) * (bottom - top);

    void drawLine(Map<DateTime, int> data, Color color) {
      final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      if (entries.length < 2) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (int i = 0; i < entries.length; i++) {
        final x = xOf(entries[i].key);
        final y = yOf(entries[i].value);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      // 末端圆点
      final last = entries.last;
      canvas.drawCircle(Offset(xOf(last.key), yOf(last.value)), 3, Paint()..color = color);
    }

    drawLine(income, incomeColor);
    drawLine(expense, expenseColor);

    // 时间轴标签
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double x, TextAnchor anchor) {
      textPainter.text = TextSpan(text: text, style: const TextStyle(fontSize: 9, color: Color(0xFF888780)));
      textPainter.layout();
      final dx = anchor == TextAnchor.start ? x : (anchor == TextAnchor.end ? x - textPainter.width : x - textPainter.width / 2);
      textPainter.paint(canvas, Offset(dx, bottom + 4));
    }
    drawLabel(shortDate(from), left, TextAnchor.start);
    drawLabel(shortDate(to), right, TextAnchor.end);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.income != income || old.expense != expense || old.from != from || old.to != to;
}

enum TextAnchor { start, center, end }
