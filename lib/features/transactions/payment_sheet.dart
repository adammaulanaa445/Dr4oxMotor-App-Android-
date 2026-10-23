import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_transaction.dart';
import '../../widgets/sheet_header.dart';

/// Hasil pencatatan pembayaran dari sheet.
class PaymentInput {
  const PaymentInput({
    required this.amount,
    required this.method,
    this.note = '',
  });

  final int amount;
  final PaymentMethod method;
  final String note;
}

/// Bottom sheet untuk mencatat pembayaran (bisa sebagian).
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.transaction});

  final ServiceTransaction transaction;

  /// Membuka sheet dan mengembalikan data pembayaran (null bila batal).
  static Future<PaymentInput?> show(
    BuildContext context, {
    required ServiceTransaction transaction,
  }) {
    return showModalBottomSheet<PaymentInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => PaymentSheet(transaction: transaction),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  PaymentMethod _method = PaymentMethod.tunai;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: '${widget.transaction.remainingAmount}');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = Validators.parseRupiah(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() => _errorText = 'Nominal harus lebih besar dari 0');
      return;
    }
    if (amount > widget.transaction.remainingAmount) {
      setState(() => _errorText =
          'Nominal melebihi sisa tagihan (${Formatters.rupiah(widget.transaction.remainingAmount)})');
      return;
    }
    Navigator.of(context).pop(
      PaymentInput(
        amount: amount,
        method: _method,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.transaction.remainingAmount;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Catat Pembayaran'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sisa tagihan',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.rupiah(remaining),
                          style: const TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_errorText != null) setState(() => _errorText = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Nominal pembayaran *',
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      errorText: _errorText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Metode pembayaran',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final method in PaymentMethod.values)
                        ChoiceChip(
                          label: Text(method.label),
                          selected: _method == method,
                          onSelected: (_) => setState(() => _method = method),
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: _method == method
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: _method == method
                                ? AppColors.accent
                                : AppColors.divider,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      prefixIcon: Icon(Icons.notes_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Simpan Pembayaran'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pastikan pembayaran benar-benar diterima sebelum '
                    'menyimpan. Lunas hanya berlaku bila total pembayaran '
                    'menutup tagihan.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
