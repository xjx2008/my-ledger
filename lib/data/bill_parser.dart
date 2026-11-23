import 'receipt_parser.dart';

/// OCR 的一行文字 + 包围盒（来自 ML Kit TextLine.boundingBox）。
/// 用几何位置把"商户 / 金额 / 时间"重新拼回一行一笔。
class OcrLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get height => bottom - top;
}

/// 账单截图里识别出来的一笔（导入前的草稿，用户可修改/勾选）
class BillDraft {
  String merchant;
  int amountCents;
  String type; // 'expense' / 'income'
  DateTime? date;
  String payment;
  String categoryName;
  bool selected;

  BillDraft({
    required this.merchant,
    required this.amountCents,
    required this.type,
    required this.date,
    required this.payment,
    required this.categoryName,
    this.selected = true,
  });
}

// ---------- 正则（与 analysis/sim_rows.py 中的原型一致） ----------

final RegExp _fullAmount =
    RegExp(r'^([+\-−－＋])?\s*[¥￥]?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)$');
final RegExp _signedAmount =
    RegExp(r'^(.*?)\s*([+\-−－＋])\s*[¥￥]?\s*(\d{1,3}(?:,\d{3})*\.\d{1,2})$');
final RegExp _yuanAmount =
    RegExp(r'^(.*?)\s*[¥￥]\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)$');
final RegExp _inlineYuan =
    RegExp(r'^(.*?)\s*[¥￥]\s*([+\-−－＋])?\s*(\d{1,3}(?:,\d{3})*\.\d{1,2})');
// 要求金额前有空格，避免把「2026-11-20」里的 -20 当成金额
final RegExp _inlineSign =
    RegExp(r'^(.*?)\s([+\-−－＋])\s*[¥￥]?\s*(\d{1,3}(?:,\d{3})*\.\d{1,2})');

final RegExp _fullDate =
    RegExp(r'(\d{4})\s*[-/年.]\s*(\d{1,2})\s*[-/月.]\s*(\d{1,2})');
final RegExp _mdDate = RegExp(r'(\d{1,2})\s*[-/月]\s*(\d{1,2})\s*日?');
final RegExp _time = RegExp(r'(\d{1,2}):(\d{2})');

const List<String> _headerWords = [
  '账单服务',
  '常见问题',
  '筛选',
  '全部账单',
  '开具',
  '交易流水',
  '统计',
  '搜索',
  '本月',
  '查看月账单',
];

const Set<String> _headerExact = {
  '微信支付',
  '支付宝',
  '账单',
  '账单详情',
  '交易成功',
  '支付成功',
  '全部',
};

/// 把一次 OCR 的所有行，解析成"一笔一笔"的草稿。
///
/// 支持版式：
/// * 微信列表：左侧商户、右侧金额，下一行是时间
/// * 支付宝列表：一行里「商户 ¥金额 11月20日 19:02」
/// * 商户名和金额被 OCR 拆成两行
///
/// 表头、汇总行（支出/收入）、"共 N 笔"等会被跳过。
List<BillDraft> parseBillList({
  required List<OcrLine> lines,
  String headerText = '',
  String defaultPayment = 'wechat',
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final rows = _clusterRows(lines);
  final drafts = <BillDraft>[];
  var pendingMerchant = '';

  var i = 0;
  while (i < rows.length) {
    final row = rows[i];
    final text = row.text;
    final segs = row.segments.map((s) => s.text).toList();

    // 纯日期行（"11月20日 12:34"）：补给上一笔
    if (_isDateOnly(text)) {
      final d = _parseDate(text, clock);
      if (d != null && drafts.isNotEmpty && drafts.last.date == null) {
        drafts.last.date = d;
      }
      i++;
      continue;
    }

    if (_isHeader(text)) {
      i++;
      continue;
    }

    final amt = _findAmount(segs);
    if (amt == null) {
      final cleaned = _cleanMerchant(text);
      if (cleaned.length >= 2) pendingMerchant = cleaned;
      i++;
      continue;
    }

    var merchant = _cleanMerchant(amt.prefix);
    if (merchant.isEmpty) merchant = pendingMerchant;
    if (merchant.isEmpty) {
      // 商户和金额在同一行：取金额以外最长的一段
      final others = segs
          .where((s) =>
              s.trim().isNotEmpty &&
              !_isDateOnly(s) &&
              _findAmount([s]) == null)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      if (others.isNotEmpty) merchant = _cleanMerchant(others.first);
    }
    pendingMerchant = '';

    var date = _parseDate(text, clock);
    if (date == null && i + 1 < rows.length && _isDateOnly(rows[i + 1].text)) {
      date = _parseDate(rows[i + 1].text, clock);
      i++;
    }

    final payment =
        guessPayment(text) ?? guessPayment(headerText) ?? defaultPayment;
    drafts.add(BillDraft(
      merchant: merchant,
      amountCents: amt.cents,
      type: (amt.sign == '+' || amt.sign == '＋') ? 'income' : 'expense',
      date: date,
      payment: payment,
      categoryName: guessCategory(merchant.isEmpty ? text : merchant),
    ));

    i++;
  }
  return drafts;
}

// ---------- 行聚类 ----------

class _Seg {
  final String text;
  final double left;
  const _Seg(this.text, this.left);
}

class _Row {
  double top;
  double bottom;
  final List<_Seg> segments;

  _Row(OcrLine line)
      : top = line.top,
        bottom = line.bottom,
        segments = [_Seg(line.text, line.left)];

  double get height => bottom - top;

  String get text {
    final sorted = [...segments]..sort((a, b) => a.left.compareTo(b.left));
    return sorted.map((s) => s.text).join(' ');
  }
}

List<_Row> _clusterRows(List<OcrLine> lines) {
  final rows = <_Row>[];
  final sorted = [...lines]..sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      return byTop != 0 ? byTop : a.left.compareTo(b.left);
    });

  for (final line in sorted) {
    if (line.text.trim().isEmpty) continue;
    _Row? target;
    // 只和最近 3 行比较：同一行内的多段文字 top 会非常接近
    for (final row in rows.reversed.take(3)) {
      final overlap =
          (row.bottom < line.bottom ? row.bottom : line.bottom) -
              (row.top > line.top ? row.top : line.top);
      final minHeight = row.height < line.height ? row.height : line.height;
      if (minHeight > 0 && overlap > minHeight * 0.5) {
        target = row;
        break;
      }
    }
    if (target == null) {
      rows.add(_Row(line));
    } else {
      target.segments.add(_Seg(line.text, line.left));
      if (line.top < target.top) target.top = line.top;
      if (line.bottom > target.bottom) target.bottom = line.bottom;
    }
  }
  return rows;
}

// ---------- 单行内的判断 ----------

class _AmountHit {
  final int cents;
  final String sign;
  final String prefix;
  const _AmountHit(this.cents, this.sign, this.prefix);
}

_AmountHit? _findAmount(List<String> segments) {
  for (final seg in segments) {
    final t = seg.trim();
    var m = _fullAmount.firstMatch(t);
    if (m != null) {
      return _AmountHit(_cents(m.group(2)!), m.group(1) ?? '', '');
    }
    m = _signedAmount.firstMatch(t);
    if (m != null) {
      return _AmountHit(_cents(m.group(3)!), m.group(2)!, m.group(1)!);
    }
    m = _yuanAmount.firstMatch(t);
    if (m != null) {
      return _AmountHit(_cents(m.group(2)!), '', m.group(1)!);
    }
  }
  // 金额夹在文字中间（例如「盒马鲜生 ¥156.40 11月20日 19:02」）
  for (final seg in segments) {
    final t = seg.trim();
    final m = _inlineYuan.firstMatch(t);
    if (m != null) {
      return _AmountHit(_cents(m.group(3)!), m.group(2) ?? '', m.group(1)!);
    }
  }
  for (final seg in segments) {
    final t = seg.trim();
    final m = _inlineSign.firstMatch(t);
    if (m != null) {
      return _AmountHit(_cents(m.group(3)!), m.group(2)!, m.group(1)!);
    }
  }
  return null;
}

int _cents(String s) {
  final v = double.tryParse(s.replaceAll(',', '').trim());
  if (v == null) return 0;
  return (v * 100).round();
}

bool _isHeader(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  if (_headerExact.contains(t)) return true;
  if (t.contains('支出') && t.contains('收入')) return true;
  if (t.contains('共') && t.contains('笔')) return true;
  if (RegExp(r'^\d{4}\s*年\s*\d{1,2}\s*月$').hasMatch(t)) return true;
  if (RegExp(r'^\d{1,2}\s*月$').hasMatch(t)) return true;
  for (final w in _headerWords) {
    if (t.contains(w)) return true;
  }
  return false;
}

bool _isDateOnly(String text) {
  var t = text;
  t = t.replaceAll(_fullDate, '');
  t = t.replaceAll(_mdDate, '');
  t = t.replaceAll(_time, '');
  t = t.replaceAll('今天', '').replaceAll('昨天', '');
  t = t.replaceAll(RegExp(r'[\s:：,，.]'), '');
  return t.isEmpty;
}

DateTime? _parseDate(String text, DateTime now) {
  final full = _fullDate.firstMatch(text);
  if (full != null) {
    final y = int.tryParse(full.group(1)!);
    final mo = int.tryParse(full.group(2)!);
    final d = int.tryParse(full.group(3)!);
    if (y != null && mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      return _withTime(DateTime(y, mo, d), text);
    }
  }
  if (text.contains('昨天')) {
    return _withTime(now.subtract(const Duration(days: 1)), text);
  }
  if (text.contains('今天')) {
    return _withTime(now, text);
  }
  final md = _mdDate.firstMatch(text);
  if (md != null) {
    final mo = int.tryParse(md.group(1)!);
    final d = int.tryParse(md.group(2)!);
    if (mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      final year = mo > now.month ? now.year - 1 : now.year;
      return _withTime(DateTime(year, mo, d), text);
    }
  }
  return null;
}

DateTime _withTime(DateTime base, String text) {
  final t = _time.firstMatch(text);
  if (t == null) return base;
  final h = int.tryParse(t.group(1)!) ?? 0;
  final m = int.tryParse(t.group(2)!) ?? 0;
  if (h > 23 || m > 59) return base;
  return DateTime(base.year, base.month, base.day, h, m);
}

String _cleanMerchant(String s) {
  var t = s;
  t = t.replaceAll(_fullDate, '');
  t = t.replaceAll(_mdDate, '');
  t = t.replaceAll(_time, '');
  t = t.replaceAll(RegExp(r'[¥￥]\s*[\d,.]+'), '');
  t = t.replaceAll(RegExp(r'^[\s\-·|:：]+|[\s\-·|:：]+$'), '');
  return t.trim();
}
