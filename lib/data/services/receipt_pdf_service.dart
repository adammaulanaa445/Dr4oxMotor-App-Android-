import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/formatters.dart';
import '../models/receipt.dart';

/// Membuat file PDF struk dari [ReceiptData].
///
/// PDF memakai ukuran kertas thermal 80mm (Lebar 226 pt) supaya struk mudah
/// dibaca baik di layar maupun setelah dicetak.
class ReceiptPdfService {
  const ReceiptPdfService();

  /// Lebar halaman PDF (poin) untuk kertas 80mm.
  static const double pageWidth = 226;

  /// Margin halaman (poin).
  static const double margin = 10;

  /// Membangun file PDF dan mengembalikan byte-nya.
  ///
  /// [logoBytes] berisi gambar logo (PNG) bila ingin ditampilkan di kop
  /// struk. Bila null, kop struk tanpa logo.
  Future<Uint8List> buildBytes(
    ReceiptData receipt, {
    Uint8List? logoBytes,
  }) async {
    final document = pw.Document(
      title: 'Struk ${receipt.transactionNumber}',
      author: receipt.workshopName,
    );

    document.addPage(
      pw.MultiPage(
        // Tinggi halaman panjang seperti roll kertas struk. Bila item
        // banyak, sisanya otomatis berlanjut ke halaman berikutnya.
        pageFormat: const PdfPageFormat(pageWidth, 1200, marginAll: margin),
        build: (context) => [_buildContent(receipt, logoBytes)],
      ),
    );

    return document.save();
  }

  /// Membuat file PDF dan menyimpannya di folder data aplikasi.
  ///
  /// Mengembalikan path file yang bisa langsung dibagikan.
  Future<File> saveToFile(
    ReceiptData receipt, {
    Uint8List? logoBytes,
  }) async {
    final bytes = await buildBytes(receipt, logoBytes: logoBytes);
    final directory = await getTemporaryDirectory();
    final fileName = safeFileName(receipt.transactionNumber);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Nama file yang aman untuk dipakai pada Android.
  static String safeFileName(String transactionNumber) {
    final safe = transactionNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'struk_$safe.pdf';
  }

  pw.Widget _buildContent(ReceiptData receipt, Uint8List? logoBytes) {
    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      );
    }

    pw.Widget itemBlock(String title, List<ReceiptLine> lines) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          for (final line in lines)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(line.name, style: const pw.TextStyle(fontSize: 8.5)),
                row(
                  '  ${line.qty} x ${Formatters.rupiah(line.unitPrice)}',
                  Formatters.rupiah(line.subtotal),
                ),
              ],
            ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoBytes != null)
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              height: 58,
            ),
          ),
        pw.Text(
          receipt.workshopName.toUpperCase(),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (receipt.workshopAddress.isNotEmpty)
          pw.Text(
            receipt.workshopAddress,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        if (receipt.workshopPhone.isNotEmpty)
          pw.Text(
            receipt.workshopPhone,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.6),
        row('No. Transaksi', receipt.transactionNumber),
        row('Tanggal', Formatters.tanggalWaktu(receipt.dateTime)),
        row('Pelanggan', receipt.customerName),
        row('Kendaraan', receipt.vehicleDisplay),
        pw.Divider(thickness: 0.6),
        if (receipt.serviceLines.isNotEmpty)
          itemBlock('LAYANAN', receipt.serviceLines),
        if (receipt.partLines.isNotEmpty)
          itemBlock('SPAREPART', receipt.partLines),
        pw.Divider(thickness: 0.6),
        row('Total item', '${receipt.totalItems}'),
        row('Biaya layanan', Formatters.rupiah(receipt.serviceTotal)),
        row('Biaya sparepart', Formatters.rupiah(receipt.partsTotal)),
        if (receipt.discount > 0)
          row('Diskon', '-${Formatters.rupiah(receipt.discount)}'),
        pw.Divider(thickness: 0.6),
        row('TOTAL', Formatters.rupiah(receipt.grandTotal), bold: true),
        row('Dibayar', Formatters.rupiah(receipt.paidAmount)),
        row('Sisa tagihan', Formatters.rupiah(receipt.remainingAmount)),
        row('Status', receipt.paymentStatusLabel),
        if (receipt.paymentMethodLabel.isNotEmpty)
          row('Metode', receipt.paymentMethodLabel),
        if (receipt.paidAt != null)
          row('Tgl. bayar', Formatters.tanggalWaktu(receipt.paidAt)),
        if (receipt.isCancelled)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
            ),
            child: pw.Text(
              'TRANSAKSI BATAL${receipt.cancelReason.isEmpty ? '' : '\n${receipt.cancelReason}'}',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        if (receipt.footer.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            receipt.footer,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ],
    );
  }
}
