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

/// 金额：优先「合计/实付/支付金额/转账金额/TOTAL」后的数字，
/// 其次带 ¥/￥ 的数字，最后取带小数点的最大数（已排除日期/时间/年份）。
int? _extractAmount(String text) {
  // 金额形态：支持千分位（1,234.56）、普通（1234.56）、整数（58）
  const amountPattern =
      r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)';

  // 1) 关键字引导的金额（权重最高），覆盖小票与微信/支付宝账单常用词
  final labelRe = RegExp(
    r'(?:合计|总计|实付|应付|消费金额|支付金额|付款金额|转账金额|交易金额|订单金额|金额|收款|付款|转账|支出|转出|共(?:计)?|TOTAL|Amount)[^\d\n]{0,8}' +
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
  int? symbolBest;
  for (final m in symbolRe.allMatches(text)) {
    final v = _toCents(m.group(1));
    if (v != null && v > 0 && (symbolBest == null || v > symbolBest)) {
      symbolBest = v;
    }
  }
  if (symbolBest != null) return symbolBest;

  // 3) 兜底：先把日期/时间/年份抹掉，否则 2026、11、20 会被当成金额
  final masked = text
      .replaceAll(
        RegExp(r'\d{4}\s*[-/年.]\s*\d{1,2}\s*[-/月.]\s*\d{1,2}\s*日?'),
        ' ',
      )
      .replaceAll(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'), ' ')
      .replaceAll(RegExp(r'\d{4}\s*年'), ' ');

  // 只认带小数点的数：账单/小票金额几乎都有两位小数，
  // 这个约束顺手排除年份、件数、电话、订单号。
  int? max;
  for (final m in RegExp(amountPattern).allMatches(masked)) {
    final token = m.group(1) ?? '';
    if (!token.contains('.')) continue;
    final v = _toCents(token);
    if (v != null && v > 0 && v <= 100000000 && (max == null || v > max)) {
      max = v;
    }
  }
  return max;
}

int? _toCents(String? s) {
  if (s == null) return null;
  // 千分位逗号是分隔符，不是小数点：1,234.56 -> 1234.56
  final cleaned = s.replaceAll(',', '').replaceAll('，', '').trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(cleaned)) return null;
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
  // 分隔符不含「.」：账单里金额如 5.20 会被误读成 5月20日，故只认 - / 月
  final withoutFull = text.replaceAll(fullRe, '');
  final mdRe = RegExp(r'\b(\d{1,2})\s*[-/月]\s*(\d{1,2})\b');
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

/// 支付方式：结合「具体扣款渠道」与「平台品牌」识别，覆盖微信/支付宝账单截图。
/// 优先级：平台专属渠道（花呗/零钱）> 银行卡 > 现金 > 平台品牌兜底。
/// 原因：微信/支付宝账单顶部必有品牌字样，但真正体现「用什么付」的是扣款渠道。
String? _extractPayment(String text) {
  // 1) 平台专属扣款渠道（比品牌词更能反映实际付款方式）
  if (RegExp(r'花呗|借呗|余额宝|网商银行|蚂蚁信用', caseSensitive: false)
      .hasMatch(text)) {
    return 'alipay';
  }
  if (RegExp(r'零钱通|微信零钱|零钱支付|零钱', caseSensitive: false)
      .hasMatch(text)) {
    return 'wechat';
  }
  // 「余额」（去掉余额宝后）归支付宝——微信没有「余额」概念
  if (text.replaceAll('余额宝', '').contains('余额')) return 'alipay';

  // 2) 银行卡强特征：卡种 / 尾号 / 银行名+数字 / 掩码卡号
  if (RegExp(
          r'银行卡|信用卡|储蓄卡|借记卡|银联|尾号\s*\d{3,4}|银行\s*\(?\d{3,4}\)?|\*{3,4}\s*\d{3,4}|\bcard\b',
          caseSensitive: false,
        ).hasMatch(text)) {
    return 'card';
  }

  // 3) 现金
  if (RegExp(r'现金|现钞|\bcash\b', caseSensitive: false).hasMatch(text)) {
    return 'cash';
  }

  // 4) 兜底：账单顶部的平台品牌字样
  if (RegExp(r'支付宝|阿里|蚂蚁|\balipay\b', caseSensitive: false)
      .hasMatch(text)) {
    return 'alipay';
  }
  if (RegExp(r'微信|财付通|\bwechat\b|\bweixin\b', caseSensitive: false)
      .hasMatch(text)) {
    return 'wechat';
  }
  return null;
}

/// 根据票据上的商品关键词，猜测分类名（用于回填分类，用户仍可改）
String _matchCategory(String text) {
  final rules = <String, List<String>>{
    '餐饮': ['餐饮', '餐厅', '饭店', '食', '餐', '外卖', '咖啡', '奶茶', '火锅', '美团', '饿了么', '肯德基', '麦当劳', '星巴克', '瑞幸'],
    '交通': ['交通', '打车', '出租', '地铁', '公交', '加油', '停车', '滴滴', '高铁', '火车', '航空', '机票', '共享单车'],
    '购物': ['购物', '商场', '服饰', '服装', '鞋', '电商', '淘宝', '京东', '拼多多', '天猫', '唯品会', '日用', '日用品', '百货', '家居', '洗护', '便利店', '超市'],
    '居住': ['房租', '物业', '水费', '电费', '燃气', '宽带', '装修', '居住'],
    '娱乐': ['娱乐', '电影', '影院', '游戏', 'KTV', '健身', '视频会员', '音乐', '会员'],
    '医疗': ['医院', '医药', '药店', '诊所', '挂号', '体检', '医疗'],
    '通讯': ['话费', '流量', '中国移动', '中国联通', '中国电信', '通讯'],
    '旅行': ['酒店', '民宿', '景点', '旅行', '携程', '飞猪'],
    '教育': ['学费', '书店', '课程', '培训', '教育', '文具'],
    '人情': ['红包', '礼金', '随礼', '人情'],
    '宠物': ['宠物', '猫粮', '狗粮', '兽医'],
  };
  for (final entry in rules.entries) {
    for (final kw in entry.value) {
      if (text.contains(kw)) return entry.key;
    }
  }
  return '';
}

/// 供账单批量识别复用：按商户名猜分类
String guessCategory(String text) => _matchCategory(text);

/// 供账单批量识别复用：按文字猜支付方式
String? guessPayment(String text) => _extractPayment(text);
