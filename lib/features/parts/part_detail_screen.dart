import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/part.dart';
import '../../data/models/service_transaction.dart';
import '../../widgets/empty_state.dart';
import 'part_form_screen.dart';

/// Halaman detail sparepart: informasi, stok, dan riwayat pergerakan stok.
class PartDetailScreen extends StatefulWidget {
  const PartDetailScreen({super.key, required this.partId});

  final int partId;

  @override
  State<PartDetailScreen> createState() => _PartDetailScreenState();
}

class _PartDetailScreenState extends State<PartDetailScreen> {
  Part? _part;
  List<StockMovement> _movements = const [];
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
      final part = await dependencies.parts.findById(widget.partId);
      final movements =
          await dependencies.parts.history(widget.partId, limit: 100);
      if (!mounted) return;
      setState(() {
        _part = part;
        _movements = movements;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final part = _part;
    if (part == null) return;
    final result = await Navigator.of(context).push<Part>(
      PartFormScreen.editRoute(part),
    );
    if (result != null) _load();
  }

  Future<void> _addStock() async {
    final part = _part;
    if (part == null) return;

    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stok saat ini: ${part.stock} ${part.unit}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jumlah tambahan *',
                hintText: 'Contoh: 10',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: restok dari supplier',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();

    if (confirmed != true) return;
    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Jumlah tambahan harus lebih dari 0')),
      );
      return;
    }

    try {
      await dependencies.parts.addStock(part.id!, amount, note: note);
      messenger.showSnackBar(
        SnackBar(content: Text('Stok ditambah $amount ${part.unit}')),
      );
      _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menambah stok: $error')),
      );
    }
  }

  Future<void> _adjustStock() async {
    final part = _part;
    if (part == null) return;

    final dependencies = context.dependencies;
    final stockController =
        TextEditingController(text: '${part.stock}');
    final noteController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Penyesuaian Stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gunakan untuk opname atau barang rusak. Selisihnya tercatat '
              'di riwayat pergerakan stok.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Stok akhir sebenarnya *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                hintText: 'Contoh: barang rusak',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    final newStock = int.tryParse(stockController.text.trim());
    final note = noteController.text.trim();
    stockController.dispose();
    noteController.dispose();

    if (confirmed != true) return;
    if (newStock == null || newStock < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Stok akhir tidak valid')),
      );
      return;
    }

    try {
      await dependencies.parts.adjustStock(part.id!, newStock, note: note);
      messenger.showSnackBar(const SnackBar(content: Text('Stok disesuaikan')));
      _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyesuaikan stok: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final part = _part;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sparepart'),
        actions: [
          IconButton(
            tooltip: 'Ubah data',
            onPressed: part == null ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : part == null
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Sparepart tidak ditemukan',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _buildHeader(part),
                      const SizedBox(height: 16),
                      _buildStockActions(part),
                      const SizedBox(height: 20),
                      _buildHistory(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Part part) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: part.isLowStock ? AppColors.warning : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  part.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!part.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NONAKTIF',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (part.code.isNotEmpty || part.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [part.code, part.category]
                  .where((e) => e.isNotEmpty)
                  .join(' • '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const Divider(height: 22, color: AppColors.divider),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stok tersedia',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${part.stock} ${part.unit}',
                      style: TextStyle(
                        color: part.isLowStock
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'minimum ${part.minStock} ${part.unit}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(part.sellPrice),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'harga jual',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'modal ${Formatters.rupiah(part.purchasePrice)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (part.isLowStock) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stok menipis, segera lakukan restok.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockActions(Part part) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _addStock,
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Tambah Stok'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _adjustStock,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Sesuaikan'),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Pergerakan Stok',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (_movements.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              'Belum ada pergerakan stok.',
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
                for (final movement in _movements)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      movement.qtyChange >= 0
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: movement.qtyChange >= 0
                          ? AppColors.success
                          : AppColors.accentLight,
                      size: 20,
                    ),
                    title: Text(
                      movement.type.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${Formatters.tanggalWaktuPendek(movement.createdAt)}'
                      '${movement.note.isEmpty ? '' : ' • ${movement.note}'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${movement.qtyChange > 0 ? '+' : ''}'
                          '${movement.qtyChange}',
                          style: TextStyle(
                            color: movement.qtyChange >= 0
                                ? AppColors.success
                                : AppColors.accentLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'sisa ${movement.stockAfter}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                          ),
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
