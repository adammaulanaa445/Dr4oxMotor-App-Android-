import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/tab_refresh_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/part.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import 'part_detail_screen.dart';
import 'part_form_screen.dart';

/// Halaman daftar sparepart (inventaris) dengan pencarian & filter stok.
class PartListScreen extends StatefulWidget {
  const PartListScreen({super.key});

  @override
  State<PartListScreen> createState() => _PartListScreenState();
}

class _PartListScreenState extends State<PartListScreen>
    with TabRefreshListener {
  @override
  int get tabIndex => 3;

  @override
  void onTabActivated() => _load();
  final TextEditingController _searchController = TextEditingController();
  List<Part> _parts = const [];
  bool _loading = true;
  bool _onlyLowStock = false;
  bool _onlyActive = false;
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
      final parts = await dependencies.parts.list(
        query: _searchController.text,
        lowStockOnly: _onlyLowStock,
      );
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

  Future<void> _openForm({Part? part}) async {
    final route = part == null
        ? PartFormScreen.createRoute()
        : PartFormScreen.editRoute(part);
    final result = await Navigator.of(context).push<Part>(route);
    if (result != null) _load();
  }

  Future<void> _openDetail(Part part) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PartDetailScreen(partId: part.id!)),
    );
    _load();
  }

  Future<void> _toggleActive(Part part) async {
    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);
    try {      await dependencies.parts.update(part.copyWith(isActive: !part.isActive));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            part.isActive
                ? 'Sparepart dinonaktifkan'
                : 'Sparepart diaktifkan kembali',
          ),
        ),
      );
      _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $error')),
      );
    }
  }

  Future<void> _delete(Part part) async {
    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus sparepart?',
      message:
          'Sparepart "${part.name}" akan dihapus. Bila sudah dipakai transaksi '
          'atau punya riwayat stok, sparepart hanya dinonaktifkan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;

    final deleted = await dependencies.parts.delete(part.id!);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Sparepart dihapus atau dinonaktifkan'
              : 'Sparepart tidak bisa dihapus, dinonaktifkan saja.',
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sparepart'),
        actions: [
          IconButton(
            tooltip: _onlyActive ? 'Tampilkan semua' : 'Tampilkan yang aktif',
            onPressed: () {
              setState(() => _onlyActive = !_onlyActive);
              _load();
            },
            icon: Icon(
              _onlyActive ? Icons.check_box : Icons.check_box_outline_blank,
              color: _onlyActive ? AppColors.accentLight : null,
            ),
          ),
          IconButton(
            tooltip: 'Tampilkan stok menipis',
            onPressed: () {
              setState(() => _onlyLowStock = !_onlyLowStock);
              _load();
            },
            icon: Icon(
              Icons.warning_amber_rounded,
              color: _onlyLowStock ? AppColors.warning : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Tag unik: beberapa menu memakai FAB sekaligus dalam satu halaman.
        heroTag: 'fab-sparepart',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Sparepart'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Cari nama, kode, atau kategori',
              onChanged: (_) => _load(),
            ),
          ),
          if (_onlyLowStock)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Menampilkan sparepart dengan stok menipis',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

    final visible = _onlyActive ? _parts.where((p) => p.isActive).toList() : _parts;

    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: _searchController.text.isEmpty
            ? 'Belum ada sparepart'
            : 'Sparepart tidak ditemukan',
        message: 'Tambahkan sparepart agar bisa dipakai pada transaksi.',
        action: ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah Sparepart'),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final part = visible[index];
          return _PartCard(
            part: part,
            onTap: () => _openDetail(part),
            onEdit: () => _openForm(part: part),
            onToggle: () => _toggleActive(part),
            onDelete: () => _delete(part),
          );
        },
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Part part;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: part.isLowStock ? AppColors.warning : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: part.isLowStock
                      ? AppColors.warning.withOpacity(0.16)
                      : AppColors.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: part.isLowStock
                      ? AppColors.warning
                      : AppColors.accentLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.name,
                      style: TextStyle(
                        color: part.isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration:
                            part.isActive ? null : TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Formatters.rupiah(part.sellPrice)} • '
                      'stok ${part.stock} ${part.unit}'
                      '${part.code.isEmpty ? '' : ' • ${part.code}'}',
                      style: TextStyle(
                        color: part.isLowStock
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            part.isLowStock ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onSelected: (value) {
                  if (value == 'ubah') onEdit();
                  if (value == 'aktif') onToggle();
                  if (value == 'hapus') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'ubah',
                    child: Text('Ubah'),
                  ),
                  PopupMenuItem<String>(
                    value: 'aktif',
                    child: Text(
                      part.isActive ? 'Nonaktifkan' : 'Aktifkan',
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'hapus',
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
