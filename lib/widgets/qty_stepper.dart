import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Kontrol jumlah (+ / -) untuk memilih jumlah barang.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onIncrease,
    required this.onDecrease,
    this.max,
    this.min = 1,
  });

  /// Jumlah saat ini.
  final int value;

  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  /// Batas maksimum (misal stok tersedia). Null = tanpa batas.
  final int? max;

  /// Batas minimum. Bila dikurangi di bawah nilai ini, item dihapus.
  final int min;

  @override
  Widget build(BuildContext context) {
    final canIncrease = max == null || value < max!;
    final canDecrease = value > min;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canDecrease ? onDecrease : null,
            icon: const Icon(Icons.remove, size: 16),
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: canIncrease ? onIncrease : null,
            icon: const Icon(Icons.add, size: 16),
            visualDensity: VisualDensity.compact,
            color: canIncrease ? AppColors.accentLight : AppColors.divider,
          ),
        ],
      ),
    );
  }
}
