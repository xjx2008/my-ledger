import 'models.dart';

/// 票据 OCR 识别结果
class ReceiptResult {
  final int? amountCents;
  final DateTime? date;
  final String? payment;
  final String matchedCategory;
  final String rawText;

  const ReceiptResult({
    this.amountCents,
    this.date,
    this.payment,
    this.matchedCategory = '',
    this.rawText = '',
  });

  bool get hasAny =>
      amountCents != null || date != null || payment != null;
}

/// 从 OCR 文字中解析金额、日期、支付方式。
/// 所有处理在本地完成，不联网、不上传。
ReceiptResult parseReceipt(String text) {
  final raw = text.replaceAll('\r', '');
  return ReceiptResult(
    amountCents: _extractAmount(raw),
    date: _extractDate(raw),
    payment: _extractPayment(raw),
    matchedCategory: _matchCategory(raw),
    rawText: raw,
  );
}

/// 金额：优先「合计/总计/实付/应付/金额/共/TOTAL」后的数字，
/// 其次带 ¥/￥ 的数字，最后取所有合理金额中的最大值。
int? _extractAmount(String text) {
  final amountPattern = r'(\d+(?:[.,]\d{1,2})?)';

  // 1) 关键字引导的金额（权重最高），只取关键字所在行或紧随其后
  final labelRe = RegExp(
    r'(?:合计|总计|实付|应付|金额|总计金额|消费金额|支付金额|收款|付款|共(?:计)?|TOTAL|Amount)[^\d\n]{0,8}' +
        amountPattern,
    caseSensitive: false,
  );
  final labelMatches = labelRe.allMatches(text).toList();
  if (labelMatches.isNotEmpty) {
    // 多个关键字时取最后一个（通常是最终合计）
    final m = labelMatches.last.group(1);
    final v = _toCents(m);
    if (v != null && v > 0) return v;
  }

  // 2) 带货币符号的数字
  final symbolRe = RegExp(r'[¥￥]\s*' + amountPattern);
  final symbolMatches = symbolRe.allMatches(text).toList();
  if (symbolMatches.isNotEmpty) {
    // 取带符号中最大的（合计通常最大）
    int? best;
    for (final m in symbolMatches) {
      final v = _toCents(m.group(1));
      if (v != null && v > 0 && (best == null || v > best)) best = v;
    }
    if (best != null) return best;
  }

  // 3) 兜底：所有数字中的最大值（过滤掉电话号码、日期等）
  final allRe = RegExp(amountPattern);
  int? max;
  for (final m in allRe.allMatches(text)) {
    final token = m.group(1) ?? '';
    // 跳过明显是日期/时间的片段
    if (token.contains('/') || token.contains('-')) continue;
    final v = _toCents(token);
    if (v != null && v >= 100 && v <= 100000000 && (max == null || v > max)) {
      max = v;
    }
  }
  return max;
}

int? _toCents(String? s) {
  if (s == null) return null;
  final cleaned = s.replaceAll(',', '').replaceAll('，', '.');
  final value = double.tryParse(cleaned);
  if (value == null) return null;
  return (value * 100).round();
}

/// 日期：支持 2026-11-22 / 2026/11/22 / 2026年11月22日 / 11-22 等
DateTime? _extractDate(String text) {
  final now = DateTime.now();

  // 完整年月日
  final fullRe = RegExp(
    r'(\d{4})\s*[-/年.]\s*(\d{1,2})\s*[-/月.]\s*(\d{1,2})',
  );
  final full = fullRe.firstMatch(text);
  if (full != null) {
    final y = int.tryParse(full.group(1) ?? '');
    final m = int.tryParse(full.group(2) ?? '');
    final d = int.tryParse(full.group(3) ?? '');
    if (_validDate(y, m, d)) return DateTime(y!, m!, d!);
  }

  // 月-日（补当前年份）：先去掉完整年月日，避免重复匹配
  final withoutFull = text.replaceAll(fullRe, '');
  final mdRe = RegExp(r'\b(\d{1,2})\s*[-/月.]\s*(\d{1,2})\b');
  for (final m in mdRe.allMatches(withoutFull)) {
    final mo = int.tryParse(m.group(1) ?? '');
    final d = int.tryParse(m.group(2) ?? '');
    if (_validDate(now.year, mo, d)) return DateTime(now.year, mo!, d!);
  }
  return null;
}

bool _validDate(int? y, int? m, int? d) {
  if (y == null || m == null || d == null) return false;
  if (y < 2000 || y > 2100) return false;
  if (m < 1 || m > 12) return false;
  if (d < 1 || d > 31) return false;
  return true;
}

/// 支付方式：优先匹配品牌关键词
String? _extractPayment(String text) {
  if (RegExp(r'支付宝|阿里|alipay', caseSensitive: false).hasMatch(text)) {
    return 'alipay';
  }
  if (RegExp(r'微信|wechat|weixin|财付通', caseSensitive: false).hasMatch(text)) {
    return 'wechat';
  }
  if (RegExp(r'银行卡|信用卡|借记卡|银联|储蓄卡|card', caseSensitive: false)
      .hasMatch(text)) {
    return 'card';
  }
  if (RegExp(r'现金|cash', caseSensitive: false).hasMatch(text)) {
    return 'cash';
  }
  return null;
}

/// 根据票据上的商品关键词，猜测分类名（用于回填分类，用户仍可改）
String _matchCategory(String text) {
  final rules = <String, List<String>>{
    '餐饮': ['餐饮', '餐厅', '饭店', '食', '餐', '外卖', '咖啡', '奶茶', '火锅', '超市', '便'],
    '交通': ['交通', '打车', '出租', '地铁', '公交', '加油', '停车', '滴滴', '高铁', '火车'],
    '购物': ['购物', '商场', '服饰', '服装', '鞋', '电商', '淘宝', '京东'],
    '日用': ['日用', '日用品', '百货', '家居', '洗护'],
    '娱乐': ['娱乐', '电影', '影院', '游戏', 'KTV', '健身'],
    '医疗': ['医院', '医药', '药店', '诊所', '挂号'],
  };
  for (final entry in rules.entries) {
    for (final kw in entry.value) {
      if (text.contains(kw)) return entry.key;
    }
  }
  return '';
}
