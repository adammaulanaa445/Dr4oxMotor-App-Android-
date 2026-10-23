import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/dev_seed_service.dart';
import '../../widgets/empty_state.dart';

/// Halaman alat bantu pengujian.
///
/// Isi data contoh hanya berjalan bila pengguna menekan tombolnya, sehingga
/// data laporan tetap sesuai transaksi yang benar-benar dicatat.
class DevDataScreen extends StatefulWidget {
  const DevDataScreen({super.key});

  @override
  State<DevDataScreen> createState() => _DevDataScreenState();
}

class _DevDataScreenState extends State<DevDataScreen> {
  bool _busy = false;

  Future<void> _seed() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final dependencies = context.dependencies;
    try {
      final service = DevSeedService(dependencies);
      final message = await service.seedSampleData();
      messenger.showSnackBar(
        SnackBar(content: Text('Data contoh ditambahkan. $message')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menambah data contoh: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    // Disiapkan sebelum jeda async agar context aman dipakai kembali.
    final messenger = ScaffoldMessenger.of(context);
    final dependencies = context.dependencies;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text(
          'Seluruh pelanggan, kendaraan, sparepart, transaksi, pembayaran, '
          'dan riwayat stok akan dihapus permanen. Katalog layanan tidak '
          'terhapus. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Hapus Semua',
              style: TextStyle(color: AppColors.accentLight),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final service = DevSeedService(dependencies);
      await service.clearAllData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Semua data operasional dihapus.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus data: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alat Bantu Uji')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const EmptyState(
                  icon: Icons.science_outlined,
                  title: 'Pengujian Data',
                  message:
                      'Gunakan halaman ini untuk memastikan database bekerja '
                      'sebelum transaksi sungguhan dibuat.',
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  icon: Icons.playlist_add_rounded,
                  title: 'Isi Data Contoh',
                  description:
                      'Menambahkan 3 pelanggan, 3 kendaraan, 4 sparepart, dan '
                      '2 transaksi (satu lunas, satu belum dibayar).',
                  buttonLabel: 'Isi Data Contoh',
                  onPressed: _seed,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Hapus Semua Data',
                  description:
                      'Mengosongkan seluruh data operasional dan mengulang '
                      'penomoran transaksi dari awal.',
                  buttonLabel: 'Hapus Semua Data',
                  destructive: true,
                  onPressed: _clear,
                ),
              ],
            ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.accentLight : AppColors.info;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? AppColors.accent : AppColors.info,
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
