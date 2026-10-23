import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/part.dart';
import '../../widgets/confirm_dialog.dart';

/// Form tambah / ubah sparepart.
class PartFormScreen extends StatefulWidget {
  const PartFormScreen({super.key, this.part});

  /// Bila diisi berarti mode ubah.
  final Part? part;

  static Route<Part> createRoute() {
    return MaterialPageRoute(builder: (_) => const PartFormScreen());
  }

  static Route<Part> editRoute(Part part) {
    return MaterialPageRoute(builder: (_) => PartFormScreen(part: part));
  }

  @override
  State<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<PartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _unitController;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.part != null;

  @override
  void initState() {
    super.initState();
    final part = widget.part;
    _nameController = TextEditingController(text: part?.name ?? '');
    _codeController = TextEditingController(text: part?.code ?? '');
    _categoryController = TextEditingController(text: part?.category ?? '');
    _purchasePriceController = TextEditingController(
      text: part == null ? '' : '${part.purchasePrice}',
    );
    _sellPriceController = TextEditingController(
      text: part == null ? '' : '${part.sellPrice}',
    );
    _stockController =
        TextEditingController(text: part == null ? '0' : '${part.stock}');
    _minStockController =
        TextEditingController(text: part == null ? '0' : '${part.minStock}');
    _unitController = TextEditingController(text: part?.unit ?? 'pcs');
    _isActive = part?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;

    setState(() => _saving = true);
    final dependencies = context.dependencies;
    final navigator = Navigator.of(context);

    final purchasePrice =
        Validators.parseRupiah(_purchasePriceController.text) ?? 0;
    final sellPrice = Validators.parseRupiah(_sellPriceController.text) ?? 0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? 0;

    try {
      if (_isEdit) {
        final updated = widget.part!.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          category: _categoryController.text.trim(),
          purchasePrice: purchasePrice,
          sellPrice: sellPrice,
          minStock: minStock,
          unit: _unitController.text.trim(),
          isActive: _isActive,
        );
        await dependencies.parts.update(updated);
        navigator.pop(updated);
      } else {
        final created = await dependencies.parts.create(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          category: _categoryController.text.trim(),
          purchasePrice: purchasePrice,
          sellPrice: sellPrice,
          stock: stock,
          minStock: minStock,
          unit: _unitController.text.trim(),
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
        title: Text(_isEdit ? 'Ubah Sparepart' : 'Tambah Sparepart'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama sparepart *',
                hintText: 'Contoh: Oli Mesin 1 Liter',
                prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
              ),
              validator: (value) =>
                  Validators.requiredText(value, field: 'Nama sparepart'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Kode barang',
                      hintText: 'OLI-001',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      hintText: 'Oli & Pelumas',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga modal',
                      hintText: 'Boleh dikosongkan',
                      prefixText: 'Rp ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga jual *',
                      prefixText: 'Rp ',
                    ),
                    validator: (value) => Validators.price(
                      value,
                      field: 'Harga jual',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    enabled: !_isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Stok awal',
                      helperText: 'Tidak bisa diubah setelah simpan',
                    ),
                    validator: (value) => Validators.nonNegativeInt(
                      value,
                      field: 'Stok',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok minimum',
                      helperText: 'Peringatan stok menipis',
                    ),
                    validator: (value) => Validators.nonNegativeInt(
                      value,
                      field: 'Stok minimum',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _unitController,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Satuan',
                hintText: 'pcs, botol, set, pasang',
                prefixIcon: Icon(Icons.straighten_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text(
                'Sparepart aktif',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Sparepart nonaktif tidak muncul saat membuat transaksi.',
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
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Sparepart'),
            ),
          ],
        ),
      ),
    );
  }
}
