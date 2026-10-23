import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/part.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/qty_stepper.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/sheet_header.dart';

/// Bottom sheet untuk memilih sparepart yang dipakai pada transaksi.
class PartPickerSheet extends StatefulWidget {
  const PartPickerSheet({super.key, this.preselected = const {}});

  /// Id sparepart yang sudah dipilih (jumlah per sparepart).
  final Map<int, int> preselected;

  /// Membuka sheet dan mengembalikan map `id sparepart -> jumlah`.
  static Future<Map<int, int>?> show(
    BuildContext context, {
    Map<int, int> preselected = const {},
  }) {
    return showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => PartPickerSheet(preselected: preselected),
    );
  }

  @override
  State<PartPickerSheet> createState() => _PartPickerSheetState();
}

class _PartPickerSheetState extends State<PartPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, int> _selected = {};
  List<Part> _parts = const [];
  bool _loading = true;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _selected.addAll(widget.preselected);
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
      final parts = await dependencies.parts.list(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _parts = parts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _increase(Part part) {
    setState(() {
      final id = part.id!;
      final current = _selected[id] ?? 0;
      if (current + 1 > part.stock) return; // jangan melebihi stok
      _selected[id] = current + 1;
    });
  }

  void _decrease(Part part) {
    setState(() {
      final id = part.id!;
      final current = _selected[id] ?? 0;
      if (current <= 1) {
        _selected.remove(id);
      } else {
        _selected[id] = current - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? _parts
        : _parts
            .where((p) =>
                p.name.toLowerCase().contains(keyword) ||
                p.code.toLowerCase().contains(keyword))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SheetHeader(
              title: 'Pilih Sparepart',
              subtitle: 'Jumlah tidak boleh melebihi stok tersedia',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Cari nama atau kode barang',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(child: _buildBody(filtered)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: Text(
                    _selected.isEmpty
                        ? 'Pilih minimal satu sparepart'
                        : 'Simpan Pilihan (${_selected.length} sparepart)',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Part> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada sparepart',
        message:
            'Tambahkan sparepart terlebih dahulu di menu Sparepart agar bisa '
            'digunakan pada transaksi.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final part = filtered[index];
        final qty = _selected[part.id] ?? 0;
        final outOfStock = part.stock <= 0;
        return Material(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.name,
                        style: TextStyle(
                          color: outOfStock
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.rupiah(part.sellPrice)} • '
                        'stok ${part.stock} ${part.unit}',
                        style: TextStyle(
                          color: outOfStock
                              ? AppColors.accentLight
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (qty > 0)
                  QtyStepper(
                    value: qty,
                    max: part.stock,
                    onDecrease: () => _decrease(part),
                    onIncrease: () => _increase(part),
                  )
                else
                  IconButton(
                    tooltip: outOfStock ? 'Stok habis' : 'Tambahkan',
                    onPressed: outOfStock ? null : () => _increase(part),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.accentLight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
