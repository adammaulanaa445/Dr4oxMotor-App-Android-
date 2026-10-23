import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/receipt.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../data/services/printing/printer_transport.dart';
import '../../data/services/printing/receipt_print_service.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../../data/services/share_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// Halaman struk transaksi (tampilan di layar).
///
/// Struk memakai gaya "kertas thermal" (latar putih, teks gelap) supaya
/// mudah dibaca dan resemble hasil cetak.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.transactionId});

  final int transactionId;

  static Route<void> createRoute(int transactionId) {
    return MaterialPageRoute(
      builder: (_) => ReceiptScreen(transactionId: transactionId),
    );
  }

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ReceiptPdfService _pdfService = const ReceiptPdfService();
  final ShareService _shareService = const ShareService();

  ReceiptData? _receipt;
  bool _loading = true;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  bool _initialized = false;

  /// Memuat berkas logo untuk ditampilkan di struk & PDF.
  ///
  /// Bila berkas tidak tersedia (mis. development), struk tetap dibuat
  /// tanpa logo.
  Future<Uint8List?> _loadLogo() async {
    try {
      final data = await rootBundle.load(AppLogo.assetPath);
      return data.buffer.asUint8List();
    } catch (error) {
      return null;
    }
  }

  Future<void> _load() async {
    final dependencies = context.dependencies;
    try {
      final receipt =
          await ReceiptRepository(dependencies.database).build(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final receipt = _receipt;
    if (receipt == null) return;
    if (_busy) return;

    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _busy = true);
    try {
      final logo = await _loadLogo();
      final file = await _pdfService.saveToFile(receipt, logoBytes: logo);
      final shared = await _shareService.sharePdf(
        file,
        text: 'Struk ${receipt.transactionNumber} - '
            '${receipt.workshopName}',
        sharePositionOrigin: origin,
      );
      if (!shared) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka menu berbagi. Coba lagi.'),
          ),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF struk: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    final receipt = _receipt;
    if (receipt == null) return;

    final dependencies = context.dependencies;
    final profile = await dependencies.settings.loadPrinterProfile();

    // Transport Bluetooth belum tersedia.点什么 integrasi sudah siap:
    // cukup ganti `UnavailablePrinterTransport` dengan implementasi
    // Bluetooth yang sesuai perangkatnya.
    final printService = EscPosPrinterService(
      transport: const UnavailablePrinterTransport(
        'Printer Bluetooth belum terhubung. '
        'Hubungkan printer lalu coba lagi.',
      ),
      profile: profile,
    );

    final result = await printService.print(receipt);
    if (!mounted) return;
    await showConfirmDialog(
      context,
      title: 'Cetak ke printer',
      message: result.message,
      confirmLabel: 'Mengerti',
      cancelLabel: 'Tutup',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk'),
        actions: [
          IconButton(
            tooltip: 'Bagikan PDF',
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _receipt == null
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Struk tidak ditemukan',
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: _ReceiptPaper(receipt: _receipt!),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _print,
                                icon: const Icon(Icons.print_outlined, size: 18),
                                label: const Text('Cetak'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : _share,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined,
                                        size: 18),
                                label: const Text('Bagikan PDF'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Kertas struk (latar putih, teks gelap).
class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({required this.receipt});

  final ReceiptData receipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12.5,
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const _DashedDivider(),
            _buildInfo(),
            const _DashedDivider(),
            if (receipt.serviceLines.isNotEmpty) ...[
              _buildItems('LAYANAN', receipt.serviceLines),
              const SizedBox(height: 6),
            ],
            if (receipt.partLines.isNotEmpty) ...[
              _buildItems('SPAREPART', receipt.partLines),
              const SizedBox(height: 6),
            ],
            const _DashedDivider(),
            _buildTotals(),
            if (receipt.isCancelled) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  'TRANSAKSI BATAL'
                  '${receipt.cancelReason.isEmpty ? '' : '\n${receipt.cancelReason}'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (receipt.footer.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                receipt.footer,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo bengkel (gambar sudah gelap, jadi tetap terbaca di kertas putih).
        const AppLogo(size: 84, showBorder: false),
        const SizedBox(height: 8),
        Text(
          receipt.workshopName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        if (receipt.workshopAddress.isNotEmpty)
          Text(
            receipt.workshopAddress,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        if (receipt.workshopPhone.isNotEmpty)
          Text(
            receipt.workshopPhone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
      ],
    );
  }

  Widget _buildInfo() {
    return Column(
      children: [
        _InfoLine(label: 'No. Transaksi', value: receipt.transactionNumber),
        _InfoLine(
          label: 'Tanggal',
          value: Formatters.tanggalWaktu(receipt.dateTime),
        ),
        _InfoLine(label: 'Pelanggan', value: receipt.customerName),
        if (receipt.customerPhone.isNotEmpty)
          _InfoLine(label: 'Telepon', value: receipt.customerPhone),
        _InfoLine(label: 'Kendaraan', value: receipt.vehicleDisplay),
      ],
    );
  }

  Widget _buildItems(String title, List<ReceiptLine> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        for (final line in lines) ...[
          Text(line.name, style: const TextStyle(fontSize: 12)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '  ${line.qty} x ${Formatters.rupiah(line.unitPrice)}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ),
              Text(
                Formatters.rupiah(line.subtotal),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        _InfoLine(label: 'Total item', value: '${receipt.totalItems}'),
        _InfoLine(
          label: 'Biaya layanan',
          value: Formatters.rupiah(receipt.serviceTotal),
        ),
        _InfoLine(
          label: 'Biaya sparepart',
          value: Formatters.rupiah(receipt.partsTotal),
        ),
        if (receipt.discount > 0)
          _InfoLine(
            label: 'Diskon',
            value: '-${Formatters.rupiah(receipt.discount)}',
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'TOTAL',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              Formatters.rupiah(receipt.grandTotal),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _InfoLine(
          label: 'Dibayar',
          value: Formatters.rupiah(receipt.paidAmount),
        ),
        _InfoLine(
          label: 'Sisa tagihan',
          value: Formatters.rupiah(receipt.remainingAmount),
        ),
        _InfoLine(label: 'Status', value: receipt.paymentStatusLabel),
        if (receipt.paymentMethodLabel.isNotEmpty)
          _InfoLine(label: 'Metode', value: receipt.paymentMethodLabel),
        if (receipt.paidAt != null)
          _InfoLine(
            label: 'Tgl. bayar',
            value: Formatters.tanggalWaktu(receipt.paidAt),
          ),
      ],
    );
  }
}

/// Baris label - nilai pada kertas struk.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis putus-putus sebagai pemisah bagian struk.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black26, width: 1),
        ),
      ),
    );
  }
}
