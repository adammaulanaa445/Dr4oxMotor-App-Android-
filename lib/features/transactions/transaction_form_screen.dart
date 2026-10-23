import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/customer.dart';
import '../../data/models/part.dart';
import '../../data/models/service_item.dart';
import '../../data/models/service_transaction.dart';
import '../../data/models/transaction_draft.dart';
import '../../data/models/vehicle.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/info_row.dart';
import '../../widgets/qty_stepper.dart';
import '../services/service_form_screen.dart';
import 'pickers/customer_picker_sheet.dart';
import 'pickers/part_picker_sheet.dart';
import 'pickers/service_picker_sheet.dart';
import 'pickers/vehicle_picker_sheet.dart';

/// Form membuat transaksi servis baru.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.initialCustomer});

  /// Pelanggan yang sudah dipilih sebelumnya (misal dari halaman pelanggan).
  final Customer? initialCustomer;

  static Route<ServiceTransaction> createRoute({Customer? initialCustomer}) {
    return MaterialPageRoute(
      builder: (_) => TransactionFormScreen(initialCustomer: initialCustomer),
    );
  }

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  Customer? _customer;
  Vehicle? _vehicle;
  List<ServiceItem> _allServices = const [];
  List<Part> _allParts = const [];
  final Map<int, int> _selectedServices = {};
  final Map<int, int> _selectedParts = {};
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Data diambil setelah widget terpasang agar AppScope sudah tersedia.
    if (_initialized) return;
    _initialized = true;
    _customer = widget.initialCustomer;
    _loadCatalogs();
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    final dependencies = context.dependencies;
    try {
      final services = await dependencies.services.list(activeOnly: true);
      final parts = await dependencies.parts.list(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _allServices = services;
        _allParts = parts;
      });
    } catch (error) {
      // Daftar tetap kosong bila gagal; transaksi tetap bisa dibuat tanpa item.
    }
  }

  // ------------------------------ Hitungan ------------------------------

  int get _serviceTotal {
    var total = 0;
    for (final entry in _selectedServices.entries) {
      for (final service in _allServices) {
        if (service.id == entry.key) {
          total += service.price * entry.value;
        }
      }
    }
    return total;
  }

  int get _partsTotal {
    var total = 0;
    for (final entry in _selectedParts.entries) {
      for (final part in _allParts) {
        if (part.id == entry.key) {
          total += part.sellPrice * entry.value;
        }
      }
    }
    return total;
  }

  int get _discount {
    return Validators.parseRupiah(_discountController.text) ?? 0;
  }

  int get _grandTotal {
    final total = _serviceTotal + _partsTotal - _discount;
    return total < 0 ? 0 : total;
  }

  // ------------------------------ Aksi form ------------------------------

  Future<void> _pickCustomer() async {
    final customer = await CustomerPickerSheet.show(context);
    if (customer == null) return;
    setState(() {
      _customer = customer;
      // Kendaraan lama tidak lagi valid karena bisa milik pelanggan lain.
      if (_vehicle != null && _vehicle!.customerId != customer.id) {
        _vehicle = null;
      }
    });
  }

  Future<void> _pickVehicle() async {
    final customer = _customer;
    if (customer == null) {
      showAppSnackBar(
        context,
        'Pilih pelanggan terlebih dahulu',
        isError: true,
      );
      return;
    }

    final result = await VehiclePickerSheet.show(context, customer: customer);
    if (result == null) return;
    setState(() {
      // Bila kendaraan ditemukan milik pelanggan lain, pelanggan ikut diganti.
      _customer = result.customer;
      _vehicle = result.vehicle;
    });
  }

  Future<void> _pickServices() async {
    final result = await ServicePickerSheet.show(
      context,
      preselected: _selectedServices,
    );
    if (result == null) return;
    setState(() {
      _selectedServices
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _pickParts() async {
    final result = await PartPickerSheet.show(
      context,
      preselected: _selectedParts,
    );
    if (result == null) return;
    setState(() {
      _selectedParts
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _addNewService() async {
    final created = await Navigator.of(context).push<ServiceItem>(
      ServiceFormScreen.createRoute(),
    );
    if (created == null) return;
    await _loadCatalogs();
    if (!mounted) return;
    setState(() {
      _selectedServices[created.id!] = 1;
    });
  }

  void _removeService(int serviceId) {
    setState(() => _selectedServices.remove(serviceId));
  }

  void _removePart(int partId) {
    setState(() => _selectedParts.remove(partId));
  }

  void _changeServiceQty(ServiceItem service, int delta) {
    setState(() {
      final id = service.id!;
      final current = _selectedServices[id] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _selectedServices.remove(id);
      } else {
        _selectedServices[id] = next;
      }
    });
  }

  void _changePartQty(Part part, int delta) {
    setState(() {
      final id = part.id!;
      final current = _selectedParts[id] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _selectedParts.remove(id);
      } else if (next > part.stock) {
        // Tidak boleh melebihi stok yang tersedia.
        showAppSnackBar(
          context,
          'Stok ${part.name} hanya ${part.stock} ${part.unit}',
          isError: true,
        );
      } else {
        _selectedParts[id] = next;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return; // cegah transaksi ganda akibat tombol ditekan berulang
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final customer = _customer;
    final vehicle = _vehicle;
    if (customer == null) {
      showAppSnackBar(context, 'Pilih pelanggan terlebih dahulu', isError: true);
      return;
    }
    if (vehicle == null) {
      showAppSnackBar(context, 'Pilih kendaraan terlebih dahulu', isError: true);
      return;
    }
    if (_selectedServices.isEmpty && _selectedParts.isEmpty) {
      showAppSnackBar(
        context,
        'Pilih minimal satu layanan atau sparepart',
        isError: true,
      );
      return;
    }
    if (_discount > _serviceTotal + _partsTotal) {
      showAppSnackBar(
        context,
        'Diskon tidak boleh lebih besar dari total tagihan',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);

    try {
      final transaction = await dependencies.transactions.createTransaction(
        _buildDraft(),
      );
      navigator.pop(transaction);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Gagal menyimpan transaksi: $error', isError: true);
    }
  }

  /// Menyusun draft transaksi yang dikirim ke repository.
  ///
  /// Perhitungan total tetap dilakukan di repository agar angka yang
  /// tersimpan sama dengan yang tampil.
  TransactionDraft _buildDraft() {
    return TransactionDraft(
      customerId: _customer!.id!,
      vehicleId: _vehicle!.id!,
      complaint: _complaintController.text.trim(),
      mechanicNotes: _notesController.text.trim(),
      discount: _discount,
      services: _selectedServices.entries
          .map((entry) =>
              ServiceSelection(serviceId: entry.key, qty: entry.value))
          .toList(),
      parts: _selectedParts.entries
          .map((entry) => PartSelection(partId: entry.key, qty: entry.value))
          .toList(),
    );
  }

  // ------------------------------ Tampilan ------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _buildCustomerCard(),
            const SizedBox(height: 14),
            _buildComplaintCard(),
            const SizedBox(height: 14),
            _buildServicesCard(),
            const SizedBox(height: 14),
            _buildPartsCard(),
            const SizedBox(height: 14),
            _buildSummaryCard(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(
                _saving ? 'Menyimpan...' : 'Simpan Transaksi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pelanggan & Kendaraan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _SelectorRow(
            icon: Icons.person_outline,
            label: 'Pelanggan',
            value: _customer?.name ?? 'Pilih pelanggan',
            isEmpty: _customer == null,
            onTap: _pickCustomer,
          ),
          const Divider(height: 18, color: AppColors.divider),
          _SelectorRow(
            icon: Icons.two_wheeler,
            label: 'Kendaraan',
            value: _vehicle == null
                ? 'Pilih kendaraan'
                : '${_vehicle!.plateNumber}'
                    '${_vehicle!.brand.isEmpty ? '' : ' • ${_vehicle!.brand} ${_vehicle!.model}'}',
            isEmpty: _vehicle == null,
            onTap: _pickVehicle,
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keluhan & Catatan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _complaintController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Keluhan pelanggan',
              hintText: 'Contoh: oli encok, rem blong',
              prefixIcon: Icon(Icons.chat_bubble_outline, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Catatan mekanik (opsional)',
              hintText: 'Contoh: ganti oli, cek filter udara',
              prefixIcon: Icon(Icons.notes_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard() {
    final selected = _allServices
        .where((s) => _selectedServices.containsKey(s.id))
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Expanded(
                child: Text(
                  'Layanan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Formatters.rupiah(_serviceTotal),
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selected.isEmpty)
            const Text(
              'Belum ada layanan dipilih.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            )
          else
            for (final service in selected)
              _SelectedItemRow(
                title: service.name,
                subtitle: '${Formatters.rupiah(service.price)} x '
                    '${_selectedServices[service.id]}',
                total: Formatters.rupiah(
                  service.price * (_selectedServices[service.id] ?? 0),
                ),
                onRemove: () => _removeService(service.id!),
                stepper: QtyStepper(
                  value: _selectedServices[service.id] ?? 1,
                  onIncrease: () => _changeServiceQty(service, 1),
                  onDecrease: () => _changeServiceQty(service, -1),
                ),
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickServices,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Pilih Layanan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addNewService,
                  icon: const Icon(Icons.library_add_outlined, size: 18),
                  label: const Text('Layanan Baru'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartsCard() {
    final selected =
        _allParts.where((p) => _selectedParts.containsKey(p.id)).toList();
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Expanded(
                child: Text(
                  'Sparepart',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Formatters.rupiah(_partsTotal),
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selected.isEmpty)
            const Text(
              'Belum ada sparepart dipilih.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            )
          else
            for (final part in selected)
              _SelectedItemRow(
                title: part.name,
                subtitle: '${Formatters.rupiah(part.sellPrice)} x '
                    '${_selectedParts[part.id]} • stok ${part.stock} ${part.unit}',
                total: Formatters.rupiah(
                  part.sellPrice * (_selectedParts[part.id] ?? 0),
                ),
                onRemove: () => _removePart(part.id!),
                stepper: QtyStepper(
                  value: _selectedParts[part.id] ?? 1,
                  max: part.stock,
                  onIncrease: () => _changePartQty(part, 1),
                  onDecrease: () => _changePartQty(part, -1),
                ),
              ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickParts,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Pilih Sparepart'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final discount = _discount;
    final discountValid = discount <= _serviceTotal + _partsTotal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Biaya',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Biaya layanan',
            value: Formatters.rupiah(_serviceTotal),
          ),
          InfoRow(
            label: 'Biaya sparepart',
            value: Formatters.rupiah(_partsTotal),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Diskon (opsional)',
              hintText: '0',
              prefixText: 'Rp ',
              prefixIcon: const Icon(Icons.discount_outlined, size: 20),
              errorText: discountValid
                  ? null
                  : 'Diskon melebihi total tagihan',
            ),
          ),
          const Divider(height: 20, color: AppColors.divider),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                Formatters.rupiah(_grandTotal),
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris pilihan (pelanggan / kendaraan) yang bisa diketuk.
class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isEmpty,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isEmpty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: isEmpty
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris item yang sudah dipilih (dengan jumlah & hapus).
class _SelectedItemRow extends StatelessWidget {
  const _SelectedItemRow({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.onRemove,
    required this.stepper,
  });

  final String title;
  final String subtitle;
  final String total;
  final VoidCallback onRemove;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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
                const SizedBox(height: 4),
                Text(
                  total,
                  style: const TextStyle(
                    color: AppColors.accentLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          stepper,
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 17),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
