import 'package:flutter/material.dart' hide Category;

import '../data/app_state.dart';
import '../data/bill_parser.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/payment_badge.dart';
import 'bill_draft_edit_sheet.dart';

/// 账单截图导入页：把识别出的多笔做成草稿，勾选后一次写入
class BillImportScreen extends StatefulWidget {
  final List<BillDraft> drafts;
  final String rawText;

  const BillImportScreen({
    super.key,
    required this.drafts,
    required this.rawText,
  });

  @override
  State<BillImportScreen> createState() => _BillImportScreenState();
}

class _BillImportScreenState extends State<BillImportScreen> {
  late final List<BillDraft> _drafts;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.drafts;
  }

  int get _selectedCount => _drafts.where((d) => d.selected).length;

  int get _selectedTotal =>
      _drafts.where((d) => d.selected).fold(0, (sum, d) => sum + d.amountCents);

  bool get _allSelected => _drafts.isNotEmpty && _drafts.every((d) => d.selected);

  void _toggleAll() {
    final next = !_allSelected;
    setState(() {
      for (final d in _drafts) {
        d.selected = next;
      }
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    final selected = _drafts.where((d) => d.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _importing = true);

    final now = DateTime.now();
    final records = <RecordItem>[];
    for (final d in selected) {
      final cats = d.type == 'income'
          ? appState.incomeCategories
          : appState.expenseCategories;
      Category? cat;
      for (final c in cats) {
        if (c.name == d.categoryName) {
          cat = c;
          break;
        }
      }
      if (cat == null) {
        for (final c in cats) {
          if (c.name == '其他') {
            cat = c;
            break;
          }
        }
      }
      if (cat == null && cats.isNotEmpty) cat = cats.first;
      if (cat?.id == null) continue;
      records.add(RecordItem(
        amountCents: d.amountCents,
        type: d.type,
        categoryId: cat!.id!,
        note: d.merchant,
        payment: d.payment,
        date: d.date ?? now,
        createdAt: now,
      ));
    }

    try {
      await appState.addRecords(records);
    } catch (e) {
      debugPrint('批量导入失败: $e');
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败，请重试')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, records.length);
  }

  void _showRawText() {
    final t = appState.theme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('识别原文', style: TextStyle(fontSize: 16, color: t.text)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              widget.rawText.trim().isEmpty ? '（没有识别到任何文字）' : widget.rawText,
              style: TextStyle(fontSize: 12, height: 1.6, color: t.subText),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('关闭', style: TextStyle(color: t.primary)),
          ),
        ],
      ),
    );
  }

  String _dateLabel(BillDraft d) {
    final date = d.date;
    if (date == null) return '日期未识别';
    if (date.hour == 0 && date.minute == 0) {
      return '${date.month}月${date.day}日';
    }
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.month}月${date.day}日 $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final t = appState.theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text(
          '识别到 ${_drafts.length} 笔',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.text),
        ),
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(
              _allSelected ? '取消全选' : '全选',
              style: TextStyle(fontSize: 12, color: t.subText),
            ),
          ),
          TextButton(
            onPressed: _showRawText,
            child: Text('原文', style: TextStyle(fontSize: 12, color: t.subText)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              '点某一笔可以改金额/分类/日期；左边勾选要导入的，分类是按商户自动猜的。',
              style: TextStyle(fontSize: 12, color: t.subText),
            ),
          ),
          Expanded(
            child: _drafts.isEmpty
                ? Center(
                    child: Text('没有识别到账目，点右上角「原文」看看读到了什么',
                        style: TextStyle(fontSize: 13, color: t.subText)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: _drafts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _DraftTile(
                      draft: _drafts[i],
                      dateLabel: _dateLabel(_drafts[i]),
                      onChanged: (v) => setState(() => _drafts[i].selected = v),
                      onEdit: () async {
                        await showBillDraftEditSheet(
                          context: context,
                          draft: _drafts[i],
                        );
                        if (mounted) setState(() {});
                      },
                      theme: t,
                    ),
                  ),
          ),
          _buildBottomBar(t),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemePreset t) {
    final disabled = _selectedCount == 0 || _importing;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('已选 $_selectedCount / ${_drafts.length} 笔',
                      style: TextStyle(fontSize: 13, color: t.text)),
                  const SizedBox(height: 2),
                  Text('合计 ${formatMoney(_selectedTotal)}',
                      style: TextStyle(fontSize: 12, color: t.subText)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: disabled ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_importing ? '导入中…' : '导入 $_selectedCount 笔'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final BillDraft draft;
  final String dateLabel;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final ThemePreset theme;

  const _DraftTile({
    required this.draft,
    required this.dateLabel,
    required this.onChanged,
    required this.onEdit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isIncome = draft.type == 'income';
    final amountColor = isIncome ? t.income : t.text;
    final sign = isIncome ? '+' : '-';
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(t.radius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Row(
          children: [
            Checkbox(
              value: draft.selected,
              activeColor: t.primary,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.merchant.isEmpty ? '未识别商户' : draft.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: draft.merchant.isEmpty ? t.subText : t.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(dateLabel, style: TextStyle(fontSize: 11, color: t.subText)),
                      const SizedBox(width: 6),
                      PaymentBadge(paymentId: draft.payment),
                      if (draft.categoryName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(draft.categoryName,
                            style: TextStyle(fontSize: 11, color: t.subText)),
                      ],
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined, size: 12, color: t.subText),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign${formatMoney(draft.amountCents)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
