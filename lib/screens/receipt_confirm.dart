import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/presets.dart';
import '../data/receipt_parser.dart';

/// 识图结果确认弹窗：展示识别出的金额/日期/支付方式，用户核对后回填
void showReceiptConfirmSheet({
  required BuildContext context,
  required ReceiptResult result,
  required void Function(int? amountCents, DateTime? date, String? payment, String catName) onConfirm,
}) {
  final t = appState.theme;
  int? amount = result.amountCents;
  DateTime? date = result.date;
  String? payment = result.payment;
  final amountController = TextEditingController(
    text: amount != null ? (amount / 100).toStringAsFixed(2) : '',
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.document_scanner, color: t.primary, size: 22),
                const SizedBox(width: 8),
                Text('识别结果', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
                const Spacer(),
                Text('请核对', style: TextStyle(fontSize: 12, color: t.subText)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '以下信息已从图片自动识别，可修改后回填',
              style: TextStyle(fontSize: 12, color: t.subText),
            ),
            const SizedBox(height: 18),

            // 金额
            Text('金额', style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 16, color: t.text),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(fontSize: 16, color: t.text),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v.trim());
                amount = parsed == null ? null : (parsed * 100).round();
              },
            ),
            const SizedBox(height: 14),

            // 日期
            Text('日期', style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setSheetState(() => date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: t.subText.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: t.subText),
                    const SizedBox(width: 8),
                    Text(
                      date == null
                          ? '未识别到，点击选择'
                          : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 14, color: date == null ? t.subText : t.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 支付方式
            Text('支付方式', style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: paymentPresets.map((p) {
                final selected = payment == p.id;
                return ChoiceChip(
                  label: Text(p.name),
                  selected: selected,
                  selectedColor: Color(p.colorValue).withOpacity(0.2),
                  labelStyle: TextStyle(fontSize: 12, color: selected ? Color(p.colorValue) : t.subText),
                  onSelected: (_) => setSheetState(() => payment = p.id),
                );
              }).toList(),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showRawTextDialog(context, result.rawText),
                icon: Icon(Icons.subject, size: 14, color: t.subText),
                label: Text('查看识别原文',
                    style: TextStyle(fontSize: 12, color: t.subText)),
              ),
            ),

            if (!result.hasAny) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '未能自动识别，请手动填写上方信息。可尝试拍摄更清晰、光线充足的小票。',
                  style: TextStyle(fontSize: 12, color: t.subText),
                ),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // 以文本框当前值为准重新解析一次金额
                  final parsed = double.tryParse(amountController.text.trim());
                  final finalAmount = parsed == null ? amount : (parsed * 100).round();
                  Navigator.pop(context);
                  onConfirm(finalAmount, date, payment, result.matchedCategory);
                },
                child: const Text('回填到记账单', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 显示 OCR 识别到的原始文字，便于判断是"没读出来"还是"读出来了但解析错"
void _showRawTextDialog(BuildContext context, String rawText) {
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
            rawText.trim().isEmpty ? '（没有识别到任何文字）' : rawText,
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
