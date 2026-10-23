import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/tab_refresh_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import '../../widgets/status_chip.dart';
import '../services/service_list_screen.dart';
import 'transaction_detail_screen.dart';
import 'transaction_form_screen.dart';

/// Halaman daftar seluruh transaksi servis.
class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen>
    with TabRefreshListener {
  @override
  int get tabIndex => 2;

  @override
  void onTabActivated() => _load();
  final TextEditingController _searchController = TextEditingController();
  List<ServiceTransaction> _transactions = const [];
  bool _loading = true;
  bool _initialized = false;

  // Filter aktif: null = semua.
  WorkStatus? _workStatus;
  PaymentStatus? _paymentStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Data diambil setelah widget terpasang agar AppScope sudah tersedia.
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final transactions = await dependencies.transactions.list(
        TransactionFilter(
          keyword: _searchController.text,
          workStatus: _workStatus,
          paymentStatus: _paymentStatus,
        ),
      );
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createTransaction() async {
    final created = await Navigator.of(context).push<ServiceTransaction>(
      TransactionFormScreen.createRoute(),
    );
    if (created != null) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaksi ${created.transactionNumber} berhasil disimpan',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Katalog Layanan',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServiceListScreen()),
              );
              _load();
            },
            icon: const Icon(Icons.local_offer_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Tag unik: beberapa menu memakai FAB sekaligus dalam satu halaman.
        heroTag: 'fab-transaksi',
        onPressed: _createTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Cari nomor transaksi, pelanggan, atau polisi',
              onChanged: (_) => _load(),
            ),
          ),
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = <Widget>[
      _FilterChip(
        label: 'Semua',
        selected: _workStatus == null && _paymentStatus == null,
        onTap: () {
          setState(() {
            _workStatus = null;
            _paymentStatus = null;
          });
          _load();
        },
      ),
      _FilterChip(
        label: 'Menunggu',
        selected: _workStatus == WorkStatus.menunggu,
        onTap: () {
          setState(() {
            _workStatus = WorkStatus.menunggu;
            _paymentStatus = null;
          });
          _load();
        },
      ),
      _FilterChip(
        label: 'Dikerjakan',
        selected: _workStatus == WorkStatus.dikerjakan,
        onTap: () {
          setState(() {
            _workStatus = WorkStatus.dikerjakan;
            _paymentStatus = null;
          });
          _load();
        },
      ),
      _FilterChip(
        label: 'Selesai',
        selected: _workStatus == WorkStatus.selesai,
        onTap: () {
          setState(() {
            _workStatus = WorkStatus.selesai;
            _paymentStatus = null;
          });
          _load();
        },
      ),
      _FilterChip(
        label: 'Belum Lunas',
        selected: _paymentStatus == PaymentStatus.belumDibayar,
        onTap: () {
          setState(() {
            _paymentStatus = PaymentStatus.belumDibayar;
            _workStatus = null;
          });
          _load();
        },
      ),
      _FilterChip(
        label: 'Lunas',
        selected: _paymentStatus == PaymentStatus.lunas,
        onTap: () {
          setState(() {
            _paymentStatus = PaymentStatus.lunas;
            _workStatus = null;
          });
          _load();
        },
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => filters[index],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada transaksi',
        message:
            'Transaksi yang dibuat akan tampil di sini lengkap dengan status '
            'pengerjaan dan pembayarannya.',
        action: ElevatedButton.icon(
          onPressed: _createTransaction,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat Transaksi'),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _TransactionCard(
            transaction: transaction,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(
                    transactionId: transaction.id!,
                  ),
                ),
              );
              _load();
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, required this.onTap});

  final ServiceTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: transaction.isCancelled
                  ? AppColors.danger
                  : AppColors.divider,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.rupiah(transaction.grandTotal),
                    style: const TextStyle(
                      color: AppColors.accentLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${transaction.plateNumber} • ${transaction.customerName}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Chip status boleh membungkus supaya tidak meluap di
                  // layar sempit.
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip.work(status: transaction.workStatus),
                        StatusChip.payment(status: transaction.paymentStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      Formatters.tanggalWaktuPendek(transaction.createdAt),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (transaction.isCancelled) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DIBATALKAN • ${transaction.cancelReason}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
