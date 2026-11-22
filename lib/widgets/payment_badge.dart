import 'package:flutter/material.dart';

import '../data/presets.dart';

/// 账目列表里的支付方式标签：彩色小胶囊，一眼就能看出用什么付的
class PaymentBadge extends StatelessWidget {
  final String paymentId;

  const PaymentBadge({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    final method = paymentById(paymentId);
    final c = Color(method.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        method.name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}
