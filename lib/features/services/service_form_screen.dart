import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/service_item.dart';
import '../../widgets/confirm_dialog.dart';

/// Form tambah / ubah katalog layanan servis.
class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.service});

  /// Bila diisi berarti mode ubah.
  final ServiceItem? service;

  static Route<ServiceItem> createRoute() {
    return MaterialPageRoute(builder: (_) => const ServiceFormScreen());
  }

  static Route<ServiceItem> editRoute(ServiceItem service) {
    return MaterialPageRoute(
      builder: (_) => ServiceFormScreen(service: service),
    );
  }

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.service?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.service?.description ?? '');
    _priceController = TextEditingController(
      text: widget.service == null ? '' : '${widget.service!.price}',
    );
    _isActive = widget.service?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return; // cegah klik ganda

    setState(() => _saving = true);
    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);
    final price = Validators.parseRupiah(_priceController.text) ?? 0;

    try {
      if (_isEdit) {
        final updated = widget.service!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          isActive: _isActive,
        );
        await dependencies.services.update(updated);
        navigator.pop(updated);
      } else {
        final created = await dependencies.services.create(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          isActive: _isActive,
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
        title: Text(_isEdit ? 'Ubah Layanan' : 'Tambah Layanan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama layanan *',
                hintText: 'Contoh: Ganti Oli',
                prefixIcon: Icon(Icons.build_outlined, size: 20),
              ),
              validator: (value) =>
                  Validators.requiredText(value, field: 'Nama layanan'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                hintText: 'Contoh: penggantian oli mesin + penyaringan oli',
                prefixIcon: Icon(Icons.notes_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga *',
                hintText: 'Contoh: 60000',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.payments_outlined, size: 20),
              ),
              validator: (value) =>
                  Validators.price(value, field: 'Harga layanan'),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text(
                'Layanan aktif',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Layanan nonaktif tidak muncul saat membuat transaksi.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              activeColor: AppColors.accent,
            ),
            const SizedBox(height: 24),
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
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Layanan'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              Text(
                'Mengubah harga layanan tidak mengubah transaksi lama. '
                'Transaksi menyimpan harga saat dibuat.',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
