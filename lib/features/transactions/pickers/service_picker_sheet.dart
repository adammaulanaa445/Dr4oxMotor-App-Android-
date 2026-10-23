import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/service_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/qty_stepper.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/sheet_header.dart';

/// Bottom sheet untuk memilih satu atau lebih layanan servis.
class ServicePickerSheet extends StatefulWidget {
  const ServicePickerSheet({super.key, this.preselected = const {}});

  /// Id layanan yang sudah dipilih (qty per layanan).
  final Map<int, int> preselected;

  /// Membuka sheet dan mengembalikan map `id layanan -> jumlah`.
  static Future<Map<int, int>?> show(
    BuildContext context, {
    Map<int, int> preselected = const {},
  }) {
    return showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => ServicePickerSheet(preselected: preselected),
    );
  }

  @override
  State<ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<ServicePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, int> _selected = {};
  List<ServiceItem> _services = const [];
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
      final services = await dependencies.services.list(activeOnly: true);
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

  void _toggle(ServiceItem service) {
    setState(() {
      if (_selected.containsKey(service.id)) {
        _selected.remove(service.id);
      } else {
        _selected[service.id!] = 1;
      }
    });
  }

  void _changeQty(ServiceItem service, int delta) {
    setState(() {
      final id = service.id!;
      final current = _selected[id] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _selected.remove(id);
      } else {
        _selected[id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? _services
        : _services
            .where((s) => s.name.toLowerCase().contains(keyword))
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
              title: 'Pilih Layanan',
              subtitle: 'Ketuk layanan untuk menambah/menghapus',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Cari layanan',
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
                        ? 'Pilih minimal satu layanan'
                        : 'Simpan Pilihan (${_selected.length} layanan)',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ServiceItem> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.local_offer_outlined,
        title: 'Belum ada layanan aktif',
        message:
            'Tambahkan katalog layanan terlebih dahulu di menu Katalog '
            'Layanan.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final service = filtered[index];
        final qty = _selected[service.id] ?? 0;
        final isSelected = qty > 0;
        return Material(
          color: isSelected
              ? AppColors.accent.withOpacity(0.14)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggle(service),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppColors.accentLight
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.rupiah(service.price),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    QtyStepper(
                      value: qty,
                      onDecrease: () => _changeQty(service, -1),
                      onIncrease: () => _changeQty(service, 1),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
