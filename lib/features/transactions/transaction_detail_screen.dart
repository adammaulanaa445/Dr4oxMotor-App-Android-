import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_transaction.dart';
import '../../data/services/service_announcer.dart';
import '../../widgets/confirm_dialog.dart';
import '../receipt/receipt_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/status_chip.dart';
import 'payment_sheet.dart';

/// Halaman detail transaksi: item, total, status pengerjaan & pembayaran.
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  ServiceTransaction? _transaction;
  List<TransactionServiceItem> _serviceItems = const [];
  List<TransactionPartItem> _partItems = const [];
  List<Payment> _payments = const [];
  bool _loading = true;
  bool _busy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Data diambil setelah widget terpasang agar AppScope sudah tersedia.
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final transaction =
          await dependencies.transactions.findById(widget.transactionId);
      if (transaction == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final serviceItems =
          await dependencies.transactions.serviceItems(transaction.id!);
      final partItems = await dependencies.transactions.partItems(transaction.id!);
      final payments =
          await dependencies.payments.listByTransaction(transaction.id!);
      if (!mounted) return;
      setState(() {
        _transaction = transaction;
        _serviceItems = serviceItems;
        _partItems = partItems;
        _payments = payments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _changeWorkStatus(WorkStatus status) async {
    final transaction = _transaction;
    if (transaction == null || _busy) return;
    if (transaction.workStatus == status) return;

    setState(() => _busy = true);
    final dependencies = context.dependencies;
    try {
      final previousStatus = transaction.workStatus;
      final updated = await dependencies.transactions
          .updateWorkStatus(transaction.id!, status);
      await _load();

      // Pengumuman TTS hanya saat status benar-benar berubah menjadi Selesai.
      if (mounted) {
        await ServiceAnnouncer(
          transactions: dependencies.transactions,
          settings: dependencies.settings,
        ).announceIfNeeded(
          previousStatus: previousStatus,
          updated: updated,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal mengubah status: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPayment() async {
    final transaction = _transaction;
    if (transaction == null) return;
    // Pengaman klik ganda: tanpa ini, menekan tombol dua kali cepat
    // bisa membuka dua sheet pembayaran (dan mencatat dua pembayaran).
    if (_busy) return;

    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);

    // Kunci tombol SEBELUM membuka sheet.
    setState(() => _busy = true);

    final input = await PaymentSheet.show(context, transaction: transaction);
    if (input == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      await dependencies.payments.addPayment(
        transactionId: transaction.id!,
        amount: input.amount,
        method: input.method,
        note: input.note,
      );
      await _load();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pembayaran ${Formatters.rupiah(input.amount)} dicatat '
            '(${input.method.label})',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pembayaran: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelTransaction() async {
    final transaction = _transaction;
    if (transaction == null) return;
    // Pengaman klik ganda (mencegah dua dialog pembatalan terbuka).
    if (_busy) return;

    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan transaksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaksi tidak akan dihapus, tetapi ditandai BATAL dan tidak '
              'dihitung sebagai pendapatan. Stok sparepart yang sempat '
              'dipakai akan dikembalikan.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alasan pembatalan *',
                hintText: 'Contoh: salah input pelanggan',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Batalkan Transaksi',
              style: TextStyle(color: AppColors.accentLight),
            ),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) {
      if (confirmed == true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Alasan pembatalan wajib diisi')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await dependencies.transactions
          .cancelTransaction(transaction.id!, reason);
      await _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membatalkan: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
    return Scaffold(
      appBar: AppBar(
        title: Text(transaction?.transactionNumber ?? 'Detail Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Lihat struk',
            onPressed: transaction == null
                ? null
                : () => Navigator.of(context).push(
                      ReceiptScreen.createRoute(transaction.id!),
                    ),
            icon: const Icon(Icons.receipt_outlined),
          ),
          if (transaction != null && !transaction.isCancelled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'batal') _cancelTransaction();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'batal',
                  child: Text('Batalkan Transaksi'),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : transaction == null
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaksi tidak ditemukan',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _buildHeader(transaction),
                      const SizedBox(height: 14),
                      _buildStatusCard(transaction),
                      const SizedBox(height: 14),
                      _buildItemsCard(),
                      const SizedBox(height: 14),
                      _buildTotalCard(transaction),
                      const SizedBox(height: 14),
                      _buildPaymentHistory(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(ServiceTransaction transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: transaction.isCancelled ? AppColors.danger : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  transaction.transactionNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (transaction.isCancelled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BATAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: 'Tanggal',
            value: Formatters.tanggalWaktu(transaction.createdAt),
            icon: Icons.event_outlined,
          ),
          InfoRow(
            label: 'Pelanggan',
            value: transaction.customerName,
            icon: Icons.person_outline,
          ),
          InfoRow(
            label: 'Kendaraan',
            value: [
              transaction.plateNumber,
              if (transaction.vehicleBrand.isNotEmpty)
                '${transaction.vehicleBrand} ${transaction.vehicleModel}'
            ].join(' • '),
            icon: Icons.two_wheeler,
          ),
          if (transaction.complaint.isNotEmpty)
            InfoRow(
              label: 'Keluhan',
              value: transaction.complaint,
              icon: Icons.chat_bubble_outline,
            ),
          if (transaction.mechanicNotes.isNotEmpty)
            InfoRow(
              label: 'Catatan',
              value: transaction.mechanicNotes,
              icon: Icons.notes_outlined,
            ),
          if (transaction.isCancelled && transaction.cancelReason.isNotEmpty)
            InfoRow(
              label: 'Alasan batal',
              value: transaction.cancelReason,
              icon: Icons.block,
              valueColor: AppColors.accentLight,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ServiceTransaction transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Pengerjaan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final status in WorkStatus.values) ...[
                Expanded(
                  child: _StatusOption(
                    label: status.label,
                    selected: transaction.workStatus == status,
                    enabled: !transaction.isCancelled && !_busy,
                    onTap: () => _changeWorkStatus(status),
                  ),
                ),
                if (status != WorkStatus.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const Divider(height: 26, color: AppColors.divider),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Status Pembayaran',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip.payment(status: transaction.paymentStatus),
            ],
          ),
          const SizedBox(height: 10),
          if (transaction.remainingAmount > 0) ...[
            Text(
              'Sisa tagihan: ${Formatters.rupiah(transaction.remainingAmount)}',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: (_busy ||
                    transaction.isCancelled ||
                    transaction.remainingAmount <= 0)
                ? null
                : _addPayment,
            icon: const Icon(Icons.payments_outlined, size: 20),
            label: Text(
              transaction.remainingAmount <= 0
                  ? 'Sudah Lunas'
                  : 'Catat Pembayaran',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (_payments.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Pembayaran',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final payment in _payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.method.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${Formatters.tanggalWaktu(payment.paidAt)}'
                          '${payment.note.isEmpty ? '' : ' • ${payment.note}'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.rupiah(payment.amount),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Item Transaksi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_serviceItems.isNotEmpty) ...[
            const Text(
              'Layanan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in _serviceItems)
              _ItemRow(
                title: item.name,
                subtitle:
                    '${Formatters.rupiah(item.price)} x ${item.qty}',
                total: Formatters.rupiah(item.subtotal),
              ),
            const SizedBox(height: 10),
          ],
          if (_partItems.isNotEmpty) ...[
            const Text(
              'Sparepart',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in _partItems)
              _ItemRow(
                title: item.name,
                subtitle: '${Formatters.rupiah(item.price)} x ${item.qty}',
                total: Formatters.rupiah(item.subtotal),
              ),
          ],
          if (_serviceItems.isEmpty && _partItems.isEmpty)
            const Text(
              'Tidak ada item.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ServiceTransaction transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          InfoRow(
            label: 'Biaya layanan',
            value: Formatters.rupiah(transaction.serviceTotal),
          ),
          InfoRow(
            label: 'Biaya sparepart',
            value: Formatters.rupiah(transaction.partsTotal),
          ),
          InfoRow(
            label: 'Diskon',
            value: '- ${Formatters.rupiah(transaction.discount)}',
          ),
          const Divider(height: 20, color: AppColors.divider),
          InfoRow(
            label: 'Total tagihan',
            value: Formatters.rupiah(transaction.grandTotal),
            valueBold: true,
          ),
          InfoRow(
            label: 'Sudah dibayar',
            value: Formatters.rupiah(transaction.paidAmount),
            valueColor: AppColors.success,
          ),
          InfoRow(
            label: 'Sisa tagihan',
            value: Formatters.rupiah(transaction.remainingAmount),
            valueColor: transaction.remainingAmount > 0
                ? AppColors.warning
                : AppColors.success,
            valueBold: true,
          ),
        ],
      ),
    );
  }
}

/// Pilihan status pengerjaan.
class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (enabled ? AppColors.textSecondary : AppColors.divider),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Baris item (layanan / sparepart) pada detail transaksi.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            total,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
