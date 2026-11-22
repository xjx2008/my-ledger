import 'package:flutter/material.dart';

class ThemePreset {
  final String key;
  final String name;
  final Color background;
  final Color primary;
  final Color card;
  final Color text;
  final Color subText;
  final Color income;
  final double radius;

  const ThemePreset({
    required this.key,
    required this.name,
    required this.background,
    required this.primary,
    required this.card,
    required this.text,
    required this.subText,
    required this.income,
    required this.radius,
  });
}

const appThemes = <ThemePreset>[
  ThemePreset(
    key: 'candy',
    name: '卡通糖果',
    background: Color(0xFFFBEAF0),
    primary: Color(0xFFD4537E),
    card: Colors.white,
    text: Color(0xFF4B1528),
    subText: Color(0xFF993556),
    income: Color(0xFF1D9E75),
    radius: 18,
  ),
  ThemePreset(
    key: 'fresh',
    name: '清新简约',
    background: Color(0xFFF1EFE8),
    primary: Color(0xFF185FA5),
    card: Colors.white,
    text: Color(0xFF2C2C2A),
    subText: Color(0xFF5F5E5A),
    income: Color(0xFF1D9E75),
    radius: 8,
  ),
  ThemePreset(
    key: 'night',
    name: '暗夜商务',
    background: Color(0xFF26215C),
    primary: Color(0xFFEF9F27),
    card: Color(0xFF3C3489),
    text: Color(0xFFEEEDFE),
    subText: Color(0xFFCECBF6),
    income: Color(0xFF5DCAA5),
    radius: 10,
  ),
  ThemePreset(
    key: 'orange',
    name: '暖阳橘',
    background: Color(0xFFFAEEDA),
    primary: Color(0xFFD85A30),
    card: Colors.white,
    text: Color(0xFF712B13),
    subText: Color(0xFF854F0B),
    income: Color(0xFF1D9E75),
    radius: 14,
  ),
  ThemePreset(
    key: 'forest',
    name: '森林绿',
    background: Color(0xFFEAF3DE),
    primary: Color(0xFF3B6D11),
    card: Colors.white,
    text: Color(0xFF173404),
    subText: Color(0xFF3B6D11),
    income: Color(0xFF0F6E56),
    radius: 12,
  ),
  ThemePreset(
    key: 'sky',
    name: '天空蓝',
    background: Color(0xFFE6F1FB),
    primary: Color(0xFF378ADD),
    card: Colors.white,
    text: Color(0xFF042C53),
    subText: Color(0xFF185FA5),
    income: Color(0xFF1D9E75),
    radius: 16,
  ),
];

ThemePreset themeByKey(String key) {
  return appThemes.firstWhere(
    (t) => t.key == key,
    orElse: () => appThemes.first,
  );
}
