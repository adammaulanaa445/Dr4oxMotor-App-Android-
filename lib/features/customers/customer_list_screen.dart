import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/tab_refresh_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Halaman daftar pelanggan dengan pencarian.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen>
    with TabRefreshListener {
  @override
  int get tabIndex => 1;

  @override
  void onTabActivated() => _load();
  final TextEditingController _searchController = TextEditingController();
  List<CustomerSearchResult> _customers = const [];
  bool _loading = true;
  bool _showArchived = false;
  bool _initialized = false;

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
      final result = await dependencies.customers.listWithVehicleCount(
        query: _searchController.text,
        includeArchived: _showArchived,
      );
      if (!mounted) return;
      setState(() {
        _customers = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Customer? customer}) async {
    final route = customer == null
        ? CustomerFormScreen.createRoute()
        : CustomerFormScreen.editRoute(customer);
    final result = await Navigator.of(context).push<Customer>(route);
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Sembunyikan arsip' : 'Tampilkan arsip',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _load();
            },
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
              color: _showArchived ? AppColors.accentLight : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Tag unik: beberapa menu memakai FAB sekaligus dalam satu halaman.
        heroTag: 'fab-pelanggan',
        onPressed: _openForm,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Pelanggan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Cari nama atau nomor telepon',
              onChanged: (_) => _load(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_customers.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: _searchController.text.isEmpty
            ? 'Belum ada pelanggan'
            : 'Pelanggan tidak ditemukan',
        message: _searchController.text.isEmpty
            ? 'Tambahkan pelanggan terlebih dahulu agar transaksi bisa dibuat.'
            : 'Coba kata kunci lain.',
        action: ElevatedButton(
          onPressed: () => _openForm(),
          child: const Text('Tambah Pelanggan'),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: _customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _customers[index];
          return _CustomerCard(
            result: item,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerDetailScreen(customerId: item.customer.id!),
                ),
              );
              _load();
            },
            onEdit: () => _openForm(customer: item.customer),
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.result,
    required this.onTap,
    required this.onEdit,
  });

  final CustomerSearchResult result;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final customer = result.customer;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: customer.isArchived
                    ? AppColors.divider
                    : AppColors.accent.withOpacity(0.18),
                child: Text(
                  customer.name.isEmpty
                      ? '?'
                      : customer.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: customer.isArchived
                        ? AppColors.textSecondary
                        : AppColors.accentLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (customer.isArchived) ...[
                          const SizedBox(width: 6),
                          const _ArchivedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.phone.isEmpty
                          ? 'Tanpa nomor telepon • ${result.vehicleCount} kendaraan'
                          : '${customer.phone} • ${result.vehicleCount} kendaraan',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah data',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textSecondary,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'ARSIP',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
