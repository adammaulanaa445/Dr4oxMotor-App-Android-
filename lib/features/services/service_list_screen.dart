import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/service_item.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import 'service_form_screen.dart';

/// Halaman katalog layanan servis.
class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ServiceItem> _services = const [];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final services = await dependencies.services.list();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openForm({ServiceItem? service}) async {
    final route = service == null
        ? ServiceFormScreen.createRoute()
        : ServiceFormScreen.editRoute(service);
    final result = await Navigator.of(context).push<ServiceItem>(route);
    if (result != null) _load();
  }

  Future<void> _toggleActive(ServiceItem service) async {
    final dependencies = context.dependencies;
    try {
      await dependencies.services.setActive(service.id!, !service.isActive);
      _load();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal mengubah status: $error', isError: true);
    }
  }

  Future<void> _delete(ServiceItem service) async {
    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus layanan?',
      message:
          'Layanan "${service.name}" akan dihapus. Bila layanan ini sudah '
          'dipakai transaksi, penghapusan ditolak.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;

    final deleted = await dependencies.services.delete(service.id!);
    if (!mounted) return;
    if (deleted) {
      messenger.showSnackBar(const SnackBar(content: Text('Layanan dihapus.')));
      _load();
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Layanan sudah dipakai transaksi, tidak bisa dihapus. '
            'Nonaktifkan saja bila tidak dipakai lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Layanan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Layanan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Cari nama layanan',
              onChanged: (_) => setState(() {}),
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

    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? _services
        : _services
            .where((s) =>
                s.name.toLowerCase().contains(keyword) ||
                s.description.toLowerCase().contains(keyword))
            .toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.local_offer_outlined,
        title: keyword.isEmpty ? 'Belum ada layanan' : 'Layanan tidak ditemukan',
        message: 'Tambahkan daftar layanan yang biasa dikerjakan bengkel.',
        action: ElevatedButton(
          onPressed: () => _openForm(),
          child: const Text('Tambah Layanan'),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final service = filtered[index];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              onTap: () => _openForm(service: service),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: service.isActive
                      ? AppColors.accent.withOpacity(0.16)
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.build_outlined,
                  size: 18,
                  color: service.isActive
                      ? AppColors.accentLight
                      : AppColors.textSecondary,
                ),
              ),
              title: Text(
                service.name,
                style: TextStyle(
                  color: service.isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  decoration:
                      service.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                service.description.isEmpty
                    ? 'Tanpa deskripsi'
                    : service.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.rupiah(service.price),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.isActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                          color: service.isActive
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    onSelected: (value) {
                      if (value == 'aktif') _toggleActive(service);
                      if (value == 'hapus') _delete(service);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'aktif',
                        child: Text(
                          service.isActive ? 'Nonaktifkan' : 'Aktifkan',
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
          );
        },
      ),
    );
  }
}
