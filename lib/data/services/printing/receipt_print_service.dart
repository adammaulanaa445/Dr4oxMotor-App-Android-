import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/formatters.dart';
import '../../models/printer_profile.dart';
import '../../models/receipt.dart';
import 'printer_transport.dart';

/// Hasil percetakan struk.
class PrintResult {
  const PrintResult({
    required this.success,
    required this.message,
    this.bytesSent,
  });

  /// True bila struk benar-benar berhasil dikirim ke printer.
  final bool success;

  /// Pesan yang aman ditampilkan ke pengguna.
  final String message;

  /// Jumlah byte yang dikirim (null bila tidak ada yang dikirim).
  final int? bytesSent;
}

/// Kontrak pencetakan struk.
///
/// Dipisah dari UI dan dari pembuatan PDF supaya integrasi printer
/// (Bluetooth thermal, ESC/POS, atau protokol lain) dapat ditambahkan
/// tanpa mengubah bagian aplikasi lain.
abstract class ReceiptPrintService {
  /// Mengirim struk ke printer.
  Future<PrintResult> print(ReceiptData receipt);
}

/// Membangun data struk menjadi paket byte ESC/POS.
///
/// CATATAN PENTING:
/// - Paket byte ini disusun mengikuti spesifikasi ESC/POS yang umum
///   (init, alignment, bold, ukuran font, dan pemotongan kertas).
/// - **Belum diuji pada printer fisik** karena perangkat printer belum
///   tersedia. Kode ini hanya menyiapkan data, bukan bukti bahwa printer
///   tertentu sudah kompatibel.
class EscPosPayloadBuilder {
  const EscPosPayloadBuilder({this.columns = 32});

  /// Jumlah kolom per baris (32 untuk kertas 58mm, 42 untuk 80mm).
  final int columns;

  /// Membangun builder sesuai lebar kertas pada profil printer.
  factory EscPosPayloadBuilder.forProfile(PrinterProfile profile) {
    return EscPosPayloadBuilder(columns: profile.paperWidth.columns);
  }

  static const int _esc = 0x1B;
  static const int _gs = 0x1D;

  /// Membangun paket byte ESC/POS untuk struk.
  Uint8List build(ReceiptData receipt) {
    final buffer = <int>[];

    void writeText(String text) {
      buffer.addAll(utf8.encode(text));
    }

    void writeLine(String text) {
      writeText(text);
      buffer.add(0x0A);
    }

    void center(String text) {
      buffer.addAll([_esc, 0x61, 0x01]); // align center
      writeLine(text);
      buffer.addAll([_esc, 0x61, 0x00]); // align left
    }

    void bold(bool on) {
      buffer.addAll([_esc, 0x45, on ? 0x01 : 0x00]);
    }

    void doubleSize(bool on) {
      buffer.addAll([_gs, 0x21, on ? 0x11 : 0x00]);
    }

    void twoColumns(String leftText, String rightText) {
      final left = leftText.length > columns - rightText.length - 1
          ? leftText.substring(0, columns - rightText.length - 1)
          : leftText;
      final space = columns - left.length - rightText.length;
      final padding = space > 0 ? ' ' * space : ' ';
      writeLine('$left$padding$rightText');
    }

    // 1. Reset printer.
    buffer.addAll([_esc, 0x40]);

    // 2. Kop surat.
    center(receipt.workshopName.toUpperCase());
    if (receipt.workshopAddress.isNotEmpty) {
      center(receipt.workshopAddress);
    }
    if (receipt.workshopPhone.isNotEmpty) {
      center(receipt.workshopPhone);
    }
    writeLine('=' * columns);

    // 3. Info transaksi.
    twoColumns('No. Transaksi', receipt.transactionNumber);
    twoColumns('Tanggal', Formatters.tanggalWaktu(receipt.dateTime));
    twoColumns('Pelanggan', receipt.customerName);
    twoColumns('Kendaraan', receipt.vehicleDisplay);
    writeLine('-' * columns);

    // 4. Item.
    void printItems(String title, List<ReceiptLine> lines) {
      if (lines.isEmpty) return;
      bold(true);
      writeLine(title);
      bold(false);
      for (final line in lines) {
        writeLine(line.name);
        twoColumns(
          '  ${line.qty} x ${Formatters.rupiah(line.unitPrice)}',
          Formatters.rupiah(line.subtotal),
        );
      }
    }

    printItems('LAYANAN', receipt.serviceLines);
    printItems('SPAREPART', receipt.partLines);
    writeLine('-' * columns);

    // 5. Total.
    twoColumns('Total item', '${receipt.totalItems}');
    twoColumns('Biaya layanan', Formatters.rupiah(receipt.serviceTotal));
    twoColumns('Biaya sparepart', Formatters.rupiah(receipt.partsTotal));
    if (receipt.discount > 0) {
      twoColumns('Diskon', '-${Formatters.rupiah(receipt.discount)}');
    }
    writeLine('=' * columns);
    doubleSize(true);
    twoColumns('TOTAL', Formatters.rupiah(receipt.grandTotal));
    doubleSize(false);
    twoColumns('Dibayar', Formatters.rupiah(receipt.paidAmount));
    twoColumns('Sisa', Formatters.rupiah(receipt.remainingAmount));
    twoColumns('Status', receipt.paymentStatusLabel);
    if (receipt.paymentMethodLabel.isNotEmpty) {
      twoColumns('Metode', receipt.paymentMethodLabel);
    }
    writeLine('=' * columns);

    if (receipt.isCancelled) {
      bold(true);
      writeLine('TRANSAKSI BATAL');
      bold(false);
      if (receipt.cancelReason.isNotEmpty) writeLine(receipt.cancelReason);
    }

    if (receipt.footer.isNotEmpty) {
      writeLine('');
      center(receipt.footer);
    }

    // 6. Potong kertas (hanya untuk printer yang punya pemotong).
    buffer.addAll([_gs, 0x56, 0x00]);
    // 7. Feed kertas keluar.
    buffer.addAll([0x0A, 0x0A, 0x0A]);

    return Uint8List.fromList(buffer);
  }
}

/// Layanan cetak yang menjelaskan bahwa printer belum tersedia.
///
/// Dipakai sampai perangkat printer thermal Bluetooth tersedia dan
/// kompatibilitasnya sudah diuji. Fungsi-fungsi lain (transaksi, struk,
/// PDF, berbagi) tetap berjalan penuh tanpa printer.
class PrinterNotAvailableService implements ReceiptPrintService {
  const PrinterNotAvailableService();

  @override
  Future<PrintResult> print(ReceiptData receipt) async {
    return const PrintResult(
      success: false,
      message:
          'Fitur cetak ke printer belum aktif. Struk tetap bisa disimpan '
          'dan dibagikan sebagai PDF.',
    );
  }
}

/// Layanan cetak ESC/POS yang memakai [PrinterTransport].
///
/// Ini adalah titik integrasi yang sesungguhnya: ketika [transport] diganti
/// dengan implementasi Bluetooth, seluruh alur cetak (payload, format,
/// pemotongan kertas) sudah siap dan tidak perlu diubah lagi.
class EscPosPrinterService implements ReceiptPrintService {
  const EscPosPrinterService({
    required this.transport,
    required this.profile,
    EscPosPayloadBuilder? payloadBuilder,
  }) : _payloadBuilder = payloadBuilder;

  final PrinterTransport transport;
  final PrinterProfile profile;
  final EscPosPayloadBuilder? _payloadBuilder;

  @override
  Future<PrintResult> print(ReceiptData receipt) async {
    // Tanpa printer yang terhubung, pencetakan gagal dengan pesan
    // yang jujur (bukan mengklaim berhasil).
    if (!await transport.isReady()) {
      return PrintResult(
        success: false,
        message: profile.isConfigured
            ? 'Printer "${profile.model}" belum terhubung. '
                'Struk bisa dibagikan sebagai PDF.'
            : 'Belum ada printer yang dikonfigurasi. Isi data printer di '
                'menu Pengaturan setelah perangkatnya dibeli. '
                'Struk tetap bisa dibagikan sebagai PDF.',
      );
    }

    try {
      await transport.connect();
      final builder = _payloadBuilder ??
          EscPosPayloadBuilder.forProfile(profile);
      final bytes = builder.build(receipt);
      await transport.write(bytes);
      await transport.disconnect();
      return PrintResult(
        success: true,
        message: 'Struk dikirim ke printer.',
        bytesSent: bytes.length,
      );
    } catch (error) {
      return PrintResult(
        success: false,
        message: 'Gagal mencetak: $error',
      );
    }
  }
}
