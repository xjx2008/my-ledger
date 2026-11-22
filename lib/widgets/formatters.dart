import 'package:flutter/material.dart';

String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = abs % 100;
  final yuanStr = _groupDigits(yuan.toString());
  return '$sign¥$yuanStr.${fen.toString().padLeft(2, '0')}';
}

String formatAmount(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = abs % 100;
  return '${_groupDigits(yuan.toString())}.${fen.toString().padLeft(2, '0')}';
}

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

DateTime startOfWeek(DateTime d) {
  // 周一为一周开始
  final weekday = d.weekday;
  return startOfDay(d.subtract(Duration(days: weekday - 1)));
}

DateTime endOfWeek(DateTime d) {
  final start = startOfWeek(d);
  return DateTime(start.year, start.month, start.day + 7, 0, 0, 0, -1);
}

DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);

DateTime endOfYear(DateTime d) => DateTime(d.year, 12, 31, 23, 59, 59, 999);

String dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = startOfDay(now);
  final target = startOfDay(d);
  final diff = today.difference(target).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  return '${d.month}月${d.day}日';
}

String timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String monthLabel(DateTime d) => '${d.year}年${d.month}月';

String shortDate(DateTime d) => '${d.month}-${d.day.toString().padLeft(2, '0')}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color colorFromValue(int value) => Color(value);
