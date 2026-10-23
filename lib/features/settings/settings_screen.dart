import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/printer_profile.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/tts_service.dart';

/// Halaman pengaturan bengkel (nama, alamat, TTS, footer struk).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _printerNameController = TextEditingController();
  final TextEditingController _printerModelController = TextEditingController();
  final TextEditingController _printerNotesController = TextEditingController();
  PrinterPaperWidth _printerPaperWidth = PrinterPaperWidth.mm80;
  PrinterProtocol _printerProtocol = PrinterProtocol.escPos;
  bool _ttsEnabled = true;
  bool _loading = true;
  bool _saving = false;
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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _printerNameController.dispose();
    _printerModelController.dispose();
    _printerNotesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    final settings = await dependencies.settings.load();
    final printer = await dependencies.settings.loadPrinterProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = settings.workshopName;
      _addressController.text = settings.workshopAddress;
      _phoneController.text = settings.workshopPhone;
      _footerController.text = settings.receiptFooter;
      _ttsEnabled = settings.ttsEnabled;
      _printerNameController.text = printer.name;
      _printerModelController.text = printer.model;
      _printerNotesController.text = printer.notes;
      _printerPaperWidth = printer.paperWidth;
      _printerProtocol = printer.protocol;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;

    setState(() => _saving = true);
    final dependencies = context.dependencies;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await dependencies.settings.save(
        WorkshopSettings(
          workshopName: _nameController.text.trim().isEmpty
              ? 'Dr4ox Motor'
              : _nameController.text.trim(),
          workshopAddress: _addressController.text.trim(),
          workshopPhone: _phoneController.text.trim(),
          receiptFooter: _footerController.text.trim(),
          ttsEnabled: _ttsEnabled,
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Pengaturan disimpan')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pengaturan: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testTts() async {
    final messenger = ScaffoldMessenger.of(context);
    final spoken = await TtsService.instance.speak(
      'Servis kendaraan dengan nomor polisi B 1234 ABC telah selesai.',
    );
    if (!spoken) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'TTS tidak tersedia di perangkat ini. '
            'Pastikan mesin TTS Android sudah aktif.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Bengkel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _buildSectionTitle('Identitas bengkel'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama bengkel',
                      hintText: 'Dr4ox Motor',
                      prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Nama bengkel wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor telepon bengkel',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Alamat bengkel',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _footerController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Catatan kaki struk',
                      hintText: 'Contoh: Terima kasih telah membawa motor Anda',
                      prefixIcon: Icon(Icons.receipt_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Pengumuman suara (TTS)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _ttsEnabled,
                          onChanged: (value) =>
                              setState(() => _ttsEnabled = value),
                          title: const Text(
                            'Umum saat servis selesai',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Contoh: "Servis kendaraan dengan nomor polisi '
                            'B 1234 ABC telah selesai."',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          activeColor: AppColors.accent,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          onTap: _testTts,
                          leading: const Icon(
                            Icons.volume_up_outlined,
                            color: AppColors.accentLight,
                            size: 20,
                          ),
                          title: const Text(
                            'Tes suara',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Dengarkan contoh pengumuman',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Printer thermal (opsional)'),
                  const SizedBox(height: 6),
                  _buildPrinterCard(),
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
                        : const Text('Simpan Pengaturan'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Data bengkel dipakai pada struk & laporan. '
                    'Semua pengaturan disimpan di perangkat ini.',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.85),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Kartu printer: menyimpan data printer untuk dipakai nanti.
  ///
  /// Status pencetakan tetap "belum tersedia" karena belum ada printer
  /// fisik yang bisa diuji.
  Widget _buildPrinterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fitur cetak ke printer BELUM aktif. Belum ada perangkat '
                    'printer yang bisa diuji, jadi struk hanya bisa disimpan '
                    'dan dibagikan sebagai PDF.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _printerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama printer',
              hintText: 'Printer meja bengkel',
              prefixIcon: Icon(Icons.print_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _printerModelController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Merek & model',
              hintText: 'Contoh: RPP-02A / Zjiang-80',
              prefixIcon: Icon(Icons.device_hub_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PrinterPaperWidth>(
                  value: _printerPaperWidth,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lebar kertas',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: [
                    for (final width in PrinterPaperWidth.values)
                      DropdownMenuItem(
                        value: width,
                        child: Text(width.label, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _printerPaperWidth = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<PrinterProtocol>(
                  value: _printerProtocol,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Protokol',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: [
                    for (final protocol in PrinterProtocol.values)
                      DropdownMenuItem(
                        value: protocol,
                        child:
                            Text(protocol.label, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _printerProtocol = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _printerNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: alamat MAC / id perangkat',
              prefixIcon: Icon(Icons.notes_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _savePrinterProfile,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan Data Printer'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePrinterProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final dependencies = context.dependencies;
    try {
      await dependencies.settings.savePrinterProfile(
        PrinterProfile(
          name: _printerNameController.text.trim(),
          model: _printerModelController.text.trim(),
          paperWidth: _printerPaperWidth,
          protocol: _printerProtocol,
          notes: _printerNotesController.text.trim(),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Data printer disimpan')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data printer: $error')),
      );
    }
  }
}

/// Membuka halaman pengaturan.
Future<void> openSettings(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}
