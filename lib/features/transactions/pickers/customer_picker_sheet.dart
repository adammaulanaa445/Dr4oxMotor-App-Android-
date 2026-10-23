import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/sheet_header.dart';
import '../../customers/customer_form_screen.dart';

/// Bottom sheet untuk memilih pelanggan yang sudah tersimpan.
class CustomerPickerSheet extends StatefulWidget {
  const CustomerPickerSheet({super.key});

  /// Membuka sheet dan mengembalikan pelanggan yang dipilih (null bila batal).
  static Future<Customer?> show(BuildContext context) {
    return showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const CustomerPickerSheet(),
    );
  }

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = const [];
  bool _loading = true;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      final customers = await dependencies.customers.list(
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addCustomer() async {
    final navigator = Navigator.of(context);
    final created = await navigator.push<Customer>(
      CustomerFormScreen.createRoute(),
    );
    if (created != null) {
      navigator.pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SheetHeader(title: 'Pilih Pelanggan'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Cari nama atau nomor telepon',
                onChanged: (_) => _load(),
              ),
            ),
            Expanded(child: _buildBody()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: _addCustomer,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Tambah Pelanggan Baru'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_customers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Pelanggan tidak ditemukan',
        message: 'Coba kata kunci lain atau tambahkan pelanggan baru.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return Material(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            onTap: () => Navigator.of(context).pop(customer),
            leading: CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.accent.withOpacity(0.18),
              child: Text(
                customer.name.isEmpty
                    ? '?'
                    : customer.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            title: Text(
              customer.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              customer.phone.isEmpty ? '-' : customer.phone,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}
