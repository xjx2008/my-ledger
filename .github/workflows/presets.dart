import 'package:flutter/material.dart' hide Category;

import 'models.dart';

// 预设支出分类（12 类）
const expensePresets = <Category>[
  Category(name: '餐饮', type: 'expense', colorValue: 0xFFD85A30, icon: '餐', sortOrder: 1, isPreset: 1),
  Category(name: '交通', type: 'expense', colorValue: 0xFF378ADD, icon: '行', sortOrder: 2, isPreset: 1),
  Category(name: '购物', type: 'expense', colorValue: 0xFFD4537E, icon: '购', sortOrder: 3, isPreset: 1),
  Category(name: '居住', type: 'expense', colorValue: 0xFFBA7517, icon: '住', sortOrder: 4, isPreset: 1),
  Category(name: '娱乐', type: 'expense', colorValue: 0xFF7F77DD, icon: '娱', sortOrder: 5, isPreset: 1),
  Category(name: '医疗', type: 'expense', colorValue: 0xFFE24B4A, icon: '医', sortOrder: 6, isPreset: 1),
  Category(name: '教育', type: 'expense', colorValue: 0xFF1D9E75, icon: '教', sortOrder: 7, isPreset: 1),
  Category(name: '人情', type: 'expense', colorValue: 0xFFD4537E, icon: '情', sortOrder: 8, isPreset: 1),
  Category(name: '旅行', type: 'expense', colorValue: 0xFF639922, icon: '游', sortOrder: 9, isPreset: 1),
  Category(name: '通讯', type: 'expense', colorValue: 0xFF378ADD, icon: '讯', sortOrder: 10, isPreset: 1),
  Category(name: '宠物', type: 'expense', colorValue: 0xFFBA7517, icon: '宠', sortOrder: 11, isPreset: 1),
  Category(name: '其他', type: 'expense', colorValue: 0xFF888780, icon: '他', sortOrder: 12, isPreset: 1),
];

// 预设收入分类（7 类）
const incomePresets = <Category>[
  Category(name: '工资', type: 'income', colorValue: 0xFF639922, icon: '薪', sortOrder: 1, isPreset: 1),
  Category(name: '奖金', type: 'income', colorValue: 0xFFBA7517, icon: '奖', sortOrder: 2, isPreset: 1),
  Category(name: '兼职', type: 'income', colorValue: 0xFF1D9E75, icon: '兼', sortOrder: 3, isPreset: 1),
  Category(name: '理财', type: 'income', colorValue: 0xFF7F77DD, icon: '财', sortOrder: 4, isPreset: 1),
  Category(name: '红包', type: 'income', colorValue: 0xFFE24B4A, icon: '红', sortOrder: 5, isPreset: 1),
  Category(name: '报销', type: 'income', colorValue: 0xFF378ADD, icon: '报', sortOrder: 6, isPreset: 1),
  Category(name: '其他', type: 'income', colorValue: 0xFF888780, icon: '他', sortOrder: 7, isPreset: 1),
];

List<Category> allPresets() => [...expensePresets, ...incomePresets];

// 自定义分类可选颜色
const customColors = <Color>[
  Color(0xFFD85A30),
  Color(0xFF378ADD),
  Color(0xFFD4537E),
  Color(0xFFBA7517),
  Color(0xFF7F77DD),
  Color(0xFF1D9E75),
  Color(0xFF639922),
  Color(0xFF888780),
];

// ---------- 支付方式 ----------
class PaymentMethod {
  final String id;
  final String name;
  final String icon;
  final int colorValue;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
  });
}

const paymentPresets = <PaymentMethod>[
  PaymentMethod(id: 'wechat', name: '微信', icon: '微', colorValue: 0xFF09BB07),
  PaymentMethod(id: 'alipay', name: '支付宝', icon: '支', colorValue: 0xFF1677FF),
  PaymentMethod(id: 'card', name: '银行卡', icon: '卡', colorValue: 0xFF34495E),
  PaymentMethod(id: 'cash', name: '现金', icon: '现', colorValue: 0xFFBA7517),
  PaymentMethod(id: 'other', name: '其他', icon: '其', colorValue: 0xFF888780),
];

PaymentMethod paymentById(String id) {
  for (final p in paymentPresets) {
    if (p.id == id) return p;
  }
  return paymentPresets.last;
}
