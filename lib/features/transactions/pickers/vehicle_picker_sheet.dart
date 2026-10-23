import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/plate_number.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/vehicle.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/sheet_header.dart';
import '../../customers/vehicle_form_screen.dart';

/// Hasil pencarian kendaraan: kendaraan + owning customer-nya.
class VehiclePickResult {
  const VehiclePickResult({required this.vehicle, required this.customer});

  final Vehicle vehicle;
  final Customer customer;
}

/// Bottom sheet untuk memilih kendaraan milik pelanggan.
class VehiclePickerSheet extends StatefulWidget {
  const VehiclePickerSheet({super.key, required this.customer});

  final Customer customer;

  /// Membuka sheet dan mengembalikan kendaraan yang dipilih.
  static Future<VehiclePickResult?> show(
    BuildContext context, {
    required Customer customer,
  }) {
    return showModalBottomSheet<VehiclePickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => VehiclePickerSheet(customer: customer),
    );
  }

  @override
  State<VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<VehiclePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Vehicle> _vehicles = const [];
  bool _loading = true;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      final vehicles = await dependencies.vehicles.listByCustomer(widget.customer.id!);
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles.where((v) => !v.isArchived).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addVehicle() async {
    final navigator = Navigator.of(context);
    final created = await navigator.push<Vehicle>(
      VehicleFormScreen.createRoute(
        customerId: widget.customer.id!,
        customerName: widget.customer.name,
      ),
    );
    if (created != null) {
      navigator.pop(VehiclePickResult(
        vehicle: created,
        customer: widget.customer,
      ));
    }
  }

  Future<void> _searchByPlate() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final results = await dependencies.vehicles.searchByPlate(keyword);
    if (!mounted) return;

    if (results.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nomor polisi "$keyword" tidak ditemukan')),
      );
      return;
    }

    // Kendaraan pertama yang cocok dipakai; bila ada di pelanggan lain,
    // pemilik kendaraan ikut dikembalikan agar pelanggan bisa diganti.
    final vehicle = results.first;
    final owner = await dependencies.customers.findById(vehicle.customerId);
    if (owner == null) return;
    navigator.pop(VehiclePickResult(vehicle: vehicle, customer: owner));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            SheetHeader(
              title: 'Pilih Kendaraan',
              subtitle: 'Pelanggan: ${widget.customer.name}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: _searchController,
                      hintText: 'Cari nomor polisi',
                      onSubmitted: (_) => _searchByPlate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cari',
                    onPressed: _searchByPlate,
                    icon: const Icon(Icons.search, color: AppColors.accentLight),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Kendaraan Baru'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vehicles.isEmpty) {
      return const EmptyState(
        icon: Icons.two_wheeler,
        title: 'Belum ada kendaraan',
        message:
            'Tambahkan kendaraan baru, atau cari nomor polisi yang sudah '
            'terdaftar.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: _vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return Material(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            onTap: () => Navigator.of(context).pop(
              VehiclePickResult(vehicle: vehicle, customer: widget.customer),
            ),
            leading: const Icon(
              Icons.two_wheeler,
              color: AppColors.accentLight,
              size: 22,
            ),
            title: Text(
              vehicle.plateNumber,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [vehicle.brand, vehicle.model]
                  .where((e) => e.isNotEmpty)
                  .join(' '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

/// Fungsi bantu untuk mencari kendaraan berdasarkan nomor polisi.
Future<List<Vehicle>> searchVehiclesByPlate(
  BuildContext context,
  String keyword,
) async {
  final normalized = PlateNumber.normalize(keyword);
  if (normalized.isEmpty) return const [];
  return context.dependencies.vehicles.searchByPlate(normalized);
}
