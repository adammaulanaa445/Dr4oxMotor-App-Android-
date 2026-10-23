import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/customer.dart';
import '../../widgets/confirm_dialog.dart';

/// Form tambah / ubah data pelanggan.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  /// Bila diisi berarti mode ubah, bukan tambah.
  final Customer? customer;

  /// Membuka form dalam mode tambah.
  static Route<Customer> createRoute() {
    return MaterialPageRoute(builder: (_) => const CustomerFormScreen());
  }

  /// Membuka form dalam mode ubah.
  static Route<Customer> editRoute(Customer customer) {
    return MaterialPageRoute(
      builder: (_) => CustomerFormScreen(customer: customer),
    );
  }

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _saving = false;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return; // cegah klik ganda

    setState(() => _saving = true);
    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);

    try {
      if (_isEdit) {
        final updated = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
        );
        await dependencies.customers.update(updated);
        navigator.pop(updated);
      } else {
        final created = await dependencies.customers.create(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
        );
        navigator.pop(created);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Gagal menyimpan: $error', isError: true);
    }
  }

  Future<bool> _askClose() async {
    final dirty = _nameController.text != (widget.customer?.name ?? '') ||
        _phoneController.text != (widget.customer?.phone ?? '') ||
        _addressController.text != (widget.customer?.address ?? '');
    if (!dirty) {
      return true;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Batalkan perubahan?',
      message: 'Data yang sudah diketik tidak akan disimpan.',
      confirmLabel: 'Batal Perubahan',
      destructive: true,
    );
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _askClose,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Ubah Pelanggan' : 'Tambah Pelanggan'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final canClose = await _askClose();
              if (canClose && mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Data pelanggan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama pelanggan *',
                  hintText: 'Contoh: Andi Pratama',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (value) =>
                    Validators.requiredText(value, field: 'Nama'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor telepon',
                  hintText: 'Contoh: 081234567890',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                  hintText: 'Contoh: Jl. Merdeka No. 12, Bandung',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
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
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Pelanggan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
