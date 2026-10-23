import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/tab_refresh_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/reports.dart';
import '../../data/models/service_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/summary_card.dart';
import '../transactions/transaction_detail_screen.dart';

/// Halaman laporan operasional bengkel.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TabRefreshListener {
  @override
  int get tabIndex => 4;

  @override
  void onTabActivated() => _load();
  int _periodIndex = 1;
  DateTime? _customStart;
  DateTime? _customEnd;

  ReportSummary? _summary;
  List<ServiceTransaction> _transactions = const [];
  List<ServiceTransaction> _unpaid = const [];
  List<PartUsage> _partUsage = const [];
  bool _loading = true;

  static const List<String> _periodLabels = [
    'Hari Ini',
    '7 Hari',
    '30 Hari',
    'Bulan Ini',
    'Custom',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  bool _initialized = false;

  DateTime get _from {
    if (_periodIndex == 4 && _customStart != null) return _customStart!;
    final now = DateTime.now();
    switch (_periodIndex) {
      case 0:
        return DateTime(now.year, now.month, now.day);
      case 1:
        return DateTime(now.year, now.month, now.day - 6);
      case 2:
        return DateTime(now.year, now.month, now.day - 29);
      case 3:
      default:
        return DateTime(now.year, now.month);
    }
  }

  DateTime get _to {
    if (_periodIndex == 4 && _customEnd != null) return _customEnd!;
    return DateTime.now();
  }

  String get _periodLabel {
    if (_periodIndex == 4 && _customStart != null && _customEnd != null) {
      return '${Formatters.tanggalPendek(_customStart)} - '
          '${Formatters.tanggalPendek(_customEnd)}';
    }
    return _periodLabels[_periodIndex];
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final summary = await dependencies.transactions.reportSummary(
        from: _from,
        to: _to,
      );
      final transactions = await dependencies.transactions.list(
        TransactionFilter(from: _from, to: _to),
      );
      final unpaid = await dependencies.transactions.unpaidTransactions();
      final partUsage = await dependencies.transactions.partUsage(
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _transactions = transactions;
        _unpaid = unpaid;
        _partUsage = partUsage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: DateTime(now.year, now.month), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _customStart = picked.start;
      _customEnd = picked.end;
      _periodIndex = 4;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  _buildSummaryGrid(),
                  const SizedBox(height: 20),
                  _buildUnpaidSection(),
                  const SizedBox(height: 20),
                  _buildPartUsageSection(),
                  const SizedBox(height: 20),
                  _buildTransactionSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_periodLabels.length, (index) {
              final selected = index == _periodIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    if (index == 4) {
                      _pickCustomRange();
                      return;
                    }
                    setState(() => _periodIndex = index);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            selected ? AppColors.accent : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      _periodLabels[index],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Periode: $_periodLabel',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    final summary = _summary ?? const ReportSummary();
    final cards = <Widget>[
      SummaryCard(
        title: 'Total Transaksi',
        value: '${summary.transactionCount}',
        icon: Icons.receipt_long_outlined,
        color: AppColors.accentLight,
        caption: 'Termasuk yang dibatalkan',
      ),
      SummaryCard(
        title: 'Pendapatan',
        value: Formatters.rupiahShort(summary.revenue),
        icon: Icons.trending_up,
        color: AppColors.success,
        caption: 'Hanya transaksi lunas',
      ),
      SummaryCard(
        title: 'Sisa Tagihan',
        value: Formatters.rupiahShort(summary.unpaidAmount),
        icon: Icons.payments_outlined,
        color: AppColors.warning,
        caption: 'Transaksi belum lunas',
      ),
      SummaryCard(
        title: 'Transaksi Batal',
        value: '${summary.cancelledCount}',
        icon: Icons.block,
        color: AppColors.danger,
        caption: 'Tidak dihitung pendapatan',
      ),
      SummaryCard(
        title: 'Total Layanan',
        value: Formatters.rupiahShort(summary.serviceCount),
        icon: Icons.build_outlined,
        color: AppColors.info,
        caption: 'Biaya jasa servis',
      ),
      SummaryCard(
        title: 'Total Sparepart',
        value: Formatters.rupiahShort(summary.partsCount),
        icon: Icons.inventory_2_outlined,
        color: AppColors.accentLight,
        caption: 'Nilai sparepart terpakai',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: cards,
    );
  }

  Widget _buildUnpaidSection() {
    if (_unpaid.isEmpty) return const SizedBox.shrink();
    var total = 0;
    for (final transaction in _unpaid) {
      total += transaction.remainingAmount;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Transaksi Belum Lunas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_unpaid.length} transaksi • ${Formatters.rupiah(total)}',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (final transaction in _unpaid.take(10))
                _TransactionRow(transaction: transaction),
              if (_unpaid.length > 10)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Menampilkan 10 dari ${_unpaid.length} transaksi belum lunas.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartUsageSection() {
    if (_partUsage.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Penggunaan Sparepart',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (final usage in _partUsage.take(10))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.accentLight, size: 20),
                  title: Text(
                    usage.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Terpakai ${usage.qty} pcs',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: Text(
                    Formatters.rupiah(usage.total),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaksi Periode Ini',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (_transactions.isEmpty)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'Belum ada transaksi',
              message: 'Tidak ada transaksi pada periode yang dipilih.',
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (final transaction in _transactions.take(20))
                  _TransactionRow(transaction: transaction),
                if (_transactions.length > 20)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Menampilkan 20 dari ${_transactions.length} transaksi.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final ServiceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TransactionDetailScreen(transactionId: transaction.id!),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      title: Text(
        '${transaction.transactionNumber} • ${transaction.plateNumber}',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transaction.customerName} • '
        '${Formatters.tanggalWaktuPendek(transaction.createdAt)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.rupiah(transaction.grandTotal),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          transaction.isCancelled
              ? const Text(
                  'Batal',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : StatusChip.payment(status: transaction.paymentStatus),
        ],
      ),
    );
  }
}
