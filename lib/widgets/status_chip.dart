import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

/// Label kecil untuk menampilkan status pengerjaan / pembayaran.
class StatusChip extends StatelessWidget {
  const StatusChip.work({
    super.key,
    required this.status,
    this.label,
  })  : isPayment = false,
        _paymentStatus = null;

  const StatusChip.payment({
    super.key,
    required PaymentStatus status,
    this.label,
  })  : isPayment = true,
        status = null,
        _paymentStatus = status;

  final bool isPayment;
  final WorkStatus? status;
  final PaymentStatus? _paymentStatus;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? _defaultLabel;
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String get _defaultLabel {
    if (isPayment) {
      return _paymentStatus?.label ?? '-';
    }
    return status?.label ?? '-';
  }

  Color get _color {
    if (isPayment) {
      return _paymentStatus == PaymentStatus.lunas
          ? AppColors.success
          : AppColors.warning;
    }
    switch (status) {
      case WorkStatus.menunggu:
        return AppColors.warning;
      case WorkStatus.dikerjakan:
        return AppColors.info;
      case WorkStatus.selesai:
        return AppColors.success;
      case null:
        return AppColors.textSecondary;
    }
  }
}
