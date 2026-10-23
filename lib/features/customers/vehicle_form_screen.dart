import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/plate_number.dart';
import '../../data/models/vehicle.dart';
import '../../widgets/confirm_dialog.dart';

/// Form tambah / ubah data kendaraan.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({
    super.key,
    required this.customerId,
    this.customerName = '',
    this.vehicle,
  });

  /// Id pelanggan pemilik kendaraan.
  final int customerId;

  /// Nama pelanggan (untuk judul & pesan).
  final String customerName;

  /// Bila diisi berarti mode ubah.
  final Vehicle? vehicle;

  static Route<Vehicle> createRoute({
    required int customerId,
    String customerName = '',
  }) {
    return MaterialPageRoute(
      builder: (_) => VehicleFormScreen(
        customerId: customerId,
        customerName: customerName,
      ),
    );
  }

  static Route<Vehicle> editRoute({
    required Vehicle vehicle,
    String customerName = '',
  }) {
    return MaterialPageRoute(
      builder: (_) => VehicleFormScreen(
        customerId: vehicle.customerId,
        customerName: customerName,
        vehicle: vehicle,
      ),
    );
  }

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _plateError;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    _plateController =
        TextEditingController(text: widget.vehicle?.plateNumber ?? '');
    _brandController = TextEditingController(text: widget.vehicle?.brand ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _notesController = TextEditingController(text: widget.vehicle?.notes ?? '');
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return; // cegah klik ganda

    setState(() {
      _saving = true;
      _plateError = null;
    });

    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);

    try {
      final plate = PlateNumber.normalize(_plateController.text);
      final duplicated = await dependencies.vehicles.plateExists(
        plate,
        ignoreVehicleId: widget.vehicle?.id,
      );
      if (duplicated) {
        setState(() {
          _saving = false;
          _plateError = 'Nomor polisi ini sudah dipakai kendaraan lain';
        });
        return;
      }

      if (_isEdit) {
        final updated = widget.vehicle!.copyWith(
          plateNumber: plate,
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          notes: _notesController.text.trim(),
        );
        await dependencies.vehicles.update(updated);
        navigator.pop(updated);
      } else {
        final created = await dependencies.vehicles.create(
          customerId: widget.customerId,
          plateNumber: plate,
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          notes: _notesController.text.trim(),
        );
        navigator.pop(created);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Gagal menyimpan: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Kendaraan' : 'Tambah Kendaraan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.customerName.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pelanggan: ${widget.customerName}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_plateError != null) {
                  setState(() => _plateError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Nomor polisi *',
                hintText: 'Contoh: B 1234 ABC',
                prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                errorText: _plateError,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nomor polisi wajib diisi';
                }
                if (!PlateNumber.isValidFormat(value)) {
                  return 'Format tidak sesuai (contoh: B 1234 ABC)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _brandController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merek (opsional)',
                hintText: 'Contoh: Honda',
                prefixIcon: Icon(Icons.factory_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _modelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Model / tipe (opsional)',
                hintText: 'Contoh: Beat',
                prefixIcon: Icon(Icons.two_wheeler, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (opsional)',
                hintText: 'Contoh: warna, tahun, kondisi awal',
                prefixIcon: Icon(Icons.notes_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Kendaraan'),
            ),
          ],
        ),
      ),
    );
  }
}
