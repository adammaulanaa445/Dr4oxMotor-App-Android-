import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/customer.dart';
import '../../data/models/service_transaction.dart';
import '../../data/models/vehicle.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/status_chip.dart';
import '../transactions/transaction_detail_screen.dart';
import '../transactions/transaction_form_screen.dart';
import 'customer_form_screen.dart';
import 'vehicle_form_screen.dart';

/// Halaman detail pelanggan: data diri, kendaraan, dan riwayat transaksi.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<Vehicle> _vehicles = const [];
  List<ServiceTransaction> _transactions = const [];
  bool _loading = true;
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
      final customer = await dependencies.customers.findById(widget.customerId);
      final vehicles = await dependencies.vehicles
          .listByCustomer(widget.customerId)
          .then((list) => list.where((v) => !v.isArchived).toList());
      final transactions = await dependencies.transactions
          .historyForCustomer(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _vehicles = vehicles;
        _transactions = transactions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _editCustomer() async {
    final customer = _customer;
    if (customer == null) return;
    final result = await Navigator.of(context).push<Customer>(
      CustomerFormScreen.editRoute(customer),
    );
    if (result != null) _load();
  }

  Future<void> _addVehicle() async {
    final customer = _customer;
    if (customer == null) return;
    final result = await Navigator.of(context).push<Vehicle>(
      VehicleFormScreen.createRoute(
        customerId: customer.id!,
        customerName: customer.name,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _editVehicle(Vehicle vehicle) async {
    final customer = _customer;
    final result = await Navigator.of(context).push<Vehicle>(
      VehicleFormScreen.editRoute(
        vehicle: vehicle,
        customerName: customer?.name ?? '',
      ),
    );
    if (result != null) _load();
  }

  Future<void> _archiveVehicle(Vehicle vehicle) async {
    // Semua objek yang dipakai setelah await diambil lebih dulu.
    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Arsipkan kendaraan?',
      message:
          'Kendaraan ${vehicle.plateNumber} akan disembunyikan dari daftar. '
          'Riwayat transaksi tetap tersimpan.',
      confirmLabel: 'Arsipkan',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await dependencies.vehicles.archive(vehicle.id!);
      _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengarsipkan: $error')),
      );
    }
  }

  Future<void> _archiveCustomer() async {
    final customer = _customer;
    if (customer == null) return;

    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);

    final hasTransactions =
        await dependencies.customers.hasTransactions(customer.id!);
    if (!mounted) return;

    if (hasTransactions) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Arsipkan pelanggan?',
        message:
            'Pelanggan ini memiliki riwayat transaksi sehingga tidak bisa '
            'dihapus. Data akan diarsipkan (disembunyikan) dan riwayat tetap '
            'tersimpan.',
        confirmLabel: 'Arsipkan',
        destructive: true,
      );
      if (!confirmed) return;
      await dependencies.customers.archive(customer.id!);
      _load();
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus pelanggan?',
      message:
          'Pelanggan "${customer.name}" belum punya transaksi sehingga bisa '
          'dihapus permanen. Kendaraan yang dimiliki juga harus dihapus '
          'dahulu.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;

    final deleted = await dependencies.customers.delete(customer.id!);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pelanggan masih memiliki kendaraan. '
            'Hapus kendaraan terlebih dahulu.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pelanggan'),
        actions: [
          IconButton(
            tooltip: 'Buat transaksi',
            onPressed: customer == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionFormScreen(
                          initialCustomer: customer,
                        ),
                      ),
                    );
                    _load();
                  },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Ubah data',
            onPressed: customer == null ? null : _editCustomer,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'arsip') _archiveCustomer();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'arsip',
                child: Text('Arsipkan / Hapus'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : customer == null
              ? const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Pelanggan tidak ditemukan',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _buildHeader(customer),
                      const SizedBox(height: 20),
                      _buildVehicles(),
                      const SizedBox(height: 20),
                      _buildHistory(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Customer customer) {
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
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent.withOpacity(0.18),
                child: Text(
                  customer.name.isEmpty
                      ? '?'
                      : customer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accentLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terdaftar ${Formatters.tanggal(customer.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (customer.isArchived)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ARSIP',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          InfoRow(
            label: 'Telepon',
            value: customer.phone.isEmpty ? '-' : customer.phone,
            icon: Icons.phone_outlined,
          ),
          InfoRow(
            label: 'Alamat',
            value: customer.address.isEmpty ? '-' : customer.address,
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kendaraan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _addVehicle,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              'Belum ada kendaraan terdaftar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          )
        else
          Column(
            children: [
              for (final vehicle in _vehicles)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.two_wheeler,
                          color: AppColors.accentLight, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.plateNumber,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [vehicle.brand, vehicle.model]
                                  .where((e) => e.isNotEmpty)
                                  .join(' '),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ubah',
                        onPressed: () => _editVehicle(vehicle),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.textSecondary, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Arsipkan',
                        onPressed: () => _archiveVehicle(vehicle),
                        icon: const Icon(Icons.archive_outlined,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              'Belum ada transaksi untuk pelanggan ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (final transaction in _transactions)
                  ListTile(
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
                    title: Text(
                      transaction.transactionNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${transaction.plateNumber} • '
                      '${Formatters.tanggalWaktuPendek(transaction.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
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
                        const SizedBox(height: 3),
                        StatusChip.payment(
                          status: transaction.paymentStatus,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
