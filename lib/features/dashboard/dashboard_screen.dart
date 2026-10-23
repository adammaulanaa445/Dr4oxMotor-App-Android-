import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/tab_refresh_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/reports.dart';
import '../../data/models/service_transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/summary_card.dart';
import '../devtools/dev_data_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../transactions/transaction_form_screen.dart';

/// Halaman ringkasan operasional bengkel.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TabRefreshListener {
  @override
  int get tabIndex => 0;

  @override
  void onTabActivated() => _load();
  DashboardSummary? _summary;
  List<ServiceTransaction> _recent = const [];
  bool _loading = true;
  String? _errorMessage;
  int _periodIndex = 1;
  bool _initialized = false;

  static const List<String> _periodLabels = [
    'Hari Ini',
    '7 Hari',
    '30 Hari',
    'Bulan Ini',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Data diambil setelah widget terpasang agar AppScope sudah tersedia.
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  DateTime get _periodStart {
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

  DateTime get _periodEnd => DateTime.now();

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final summary = await dependencies.transactions.dashboardSummary(
        periodStart: _periodStart,
        periodEnd: _periodEnd,
      );
      final recent = await dependencies.transactions.list(
        const TransactionFilter(limit: 5),
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _recent = recent;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 38),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dr4ox Motor'),
                  Text(
                    'Ringkasan operasional bengkel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Pengaturan bengkel',
            onPressed: () async {
              await openSettings(context);
              _load();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Alat bantu uji',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DevDataScreen()),
              );
              _load();
            },
            icon: const Icon(Icons.build_outlined),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        // Tag unik: beberapa menu memakai FAB sekaligus dalam satu halaman.
        heroTag: 'fab-dashboard',
        onPressed: () async {
          await Navigator.of(context).push<ServiceTransaction>(
            TransactionFormScreen.createRoute(),
          );
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Gagal memuat data: $_errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final summary = _summary ?? const DashboardSummary();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildSummaryGrid(summary),
          const SizedBox(height: 20),
          _buildLowStock(summary),
          const SizedBox(height: 20),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Periode pendapatan',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_periodLabels.length, (index) {
              final selected = index == _periodIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_periodLabels[index]),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _periodIndex = index);
                    _load();
                  },
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.accent : AppColors.divider,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(DashboardSummary summary) {
    final cards = <Widget>[
      SummaryCard(
        title: 'Transaksi Hari Ini',
        value: '${summary.todayTransactionCount}',
        icon: Icons.receipt_outlined,
        color: AppColors.accentLight,
        caption: 'Transaksi dibuat hari ini',
      ),
      SummaryCard(
        title: 'Sedang Dikerjakan',
        value: '${summary.inProgressCount}',
        icon: Icons.build_outlined,
        color: AppColors.info,
        caption: 'Kendaraan di bengkel',
      ),
      SummaryCard(
        title: 'Menunggu Pengerjaan',
        value: '${summary.waitingCount}',
        icon: Icons.hourglass_empty_rounded,
        color: AppColors.warning,
        caption: 'Antrean servis',
      ),
      SummaryCard(
        title: 'Belum Lunas',
        value: '${summary.unpaidCount}',
        icon: Icons.payments_outlined,
        color: AppColors.warning,
        caption: 'Transaksi belum dibayar',
      ),
      SummaryCard(
        title: 'Pendapatan Hari Ini',
        value: Formatters.rupiahShort(summary.todayRevenue),
        icon: Icons.trending_up,
        color: AppColors.success,
        caption: 'Dari transaksi lunas',
      ),
      SummaryCard(
        title: 'Pendapatan Periode',
        value: Formatters.rupiahShort(summary.periodRevenue),
        icon: Icons.calendar_month_outlined,
        color: AppColors.success,
        caption:
            '${summary.periodTransactionCount} transaksi • ${_periodLabels[_periodIndex]}',
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

  Widget _buildLowStock(DashboardSummary summary) {
    if (summary.lowStockParts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Text(
              'Stok Menipis',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
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
              for (final part in summary.lowStockParts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.warning, size: 20),
                  title: Text(
                    part.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'Sisa ${part.stock} ${part.unit} • minimum ${part.minStock}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaksi Terbaru',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (_recent.isEmpty)
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi',
              message:
                  'Transaksi yang dibuat akan muncul di sini. Data diambil '
                  'langsung dari database lokal.',
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
                for (final transaction in _recent)
                  _TransactionTile(
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
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});

  final ServiceTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.accent.withOpacity(0.18),
        child: Text(
          transaction.plateNumber.isEmpty
              ? '?'
              : transaction.plateNumber.substring(0, 1),
          style: const TextStyle(
            color: AppColors.accentLight,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        '${transaction.transactionNumber} • ${transaction.plateNumber}',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transaction.customerName} • '
        '${Formatters.tanggalWaktuPendek(transaction.createdAt)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          // Chip status boleh membungkus supaya tidak meluap di layar sempit.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              StatusChip.work(status: transaction.workStatus),
              StatusChip.payment(status: transaction.paymentStatus),
            ],
          ),
        ],
      ),
    );
  }
}
