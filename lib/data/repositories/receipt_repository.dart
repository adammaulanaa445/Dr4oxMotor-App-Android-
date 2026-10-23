import '../../core/utils/formatters.dart';
import '../local/app_database.dart';
import '../models/receipt.dart';
import 'base_repository.dart';
import 'payment_repository.dart';
import 'settings_repository.dart';
import 'transaction_repository.dart';

/// Menyusun data struk dari sebuah transaksi.
///
/// Semua angka diambil dari data tersimpan di database (harga historis),
/// bukan dari nilai yang sedang tampil di layar.
class ReceiptRepository extends BaseRepository {
  ReceiptRepository(AppDatabase appDatabase)
      : transactions = TransactionRepository(appDatabase),
        payments = PaymentRepository(appDatabase),
        settingsRepository = SettingsRepository(appDatabase),
        super(appDatabase);

  final TransactionRepository transactions;
  final PaymentRepository payments;
  final SettingsRepository settingsRepository;

  /// Membangun data struk untuk sebuah transaksi.
  ///
  /// Mengembalikan `null` bila transaksi tidak ditemukan.
  Future<ReceiptData?> build(int transactionId) async {
    final transaction =
        await transactions.findById(transactionId);
    if (transaction == null) return null;

    final serviceItems = await transactions.serviceItems(transactionId);
    final partItems = await transactions.partItems(transactionId);
    final paymentList = await payments.listByTransaction(transactionId);
    final settings = await settingsRepository.load();

    final serviceLines = serviceItems
        .map((item) => ReceiptLine(
              name: item.name,
              qty: item.qty,
              unitPrice: item.price,
              subtotal: item.subtotal,
            ))
        .toList();

    final partLines = partItems
        .map((item) => ReceiptLine(
              name: item.name,
              qty: item.qty,
              unitPrice: item.price,
              subtotal: item.subtotal,
            ))
        .toList();

    final lastPayment = paymentList.isEmpty ? null : paymentList.first;

    return ReceiptData(
      workshopName: settings.workshopName,
      workshopAddress: settings.workshopAddress,
      workshopPhone: settings.workshopPhone,
      transactionNumber: transaction.transactionNumber,
      dateTime: transaction.createdAt,
      customerName: transaction.customerName,
      customerPhone: transaction.customerPhone,
      plateNumber: transaction.plateNumber,
      vehicleBrand: transaction.vehicleBrand,
      vehicleModel: transaction.vehicleModel,
      serviceLines: serviceLines,
      partLines: partLines,
      serviceTotal: transaction.serviceTotal,
      partsTotal: transaction.partsTotal,
      discount: transaction.discount,
      grandTotal: transaction.grandTotal,
      paidAmount: transaction.paidAmount,
      remainingAmount: transaction.remainingAmount,
      paymentStatusLabel: transaction.paymentStatus.label,
      paymentMethodLabel: lastPayment?.method.label ?? '',
      paidAt: lastPayment?.paidAt,
      footer: settings.receiptFooter,
      isCancelled: transaction.isCancelled,
      cancelReason: transaction.cancelReason,
    );
  }

  /// Teks struk siap cetak (dipakai untuk preview teks & printer sederhana).
  String toPlainText(ReceiptData receipt) {
    final buffer = StringBuffer();
    final line = '=' * 32;

    void addRow(String left, String right) {
      buffer.writeln(left.padRight(18).substring(0, 18) +
          right.padLeft(14).substring(0, 14));
    }

    buffer
      ..writeln(line)
      ..writeln(receipt.workshopName.toUpperCase())
      ..writeln(receipt.workshopAddress)
      ..writeln(receipt.workshopPhone)
      ..writeln(line)
      ..writeln('No. Transaksi : ${receipt.transactionNumber}')
      ..writeln('Tanggal      : ${Formatters.tanggalWaktu(receipt.dateTime)}')
      ..writeln('Pelanggan    : ${receipt.customerName}')
      ..writeln('Kendaraan    : ${receipt.vehicleDisplay}')
      ..writeln(line);

    if (receipt.serviceLines.isNotEmpty) {
      buffer.writeln('LAYANAN');
      for (final item in receipt.serviceLines) {
        buffer.writeln(item.name);
        addRow('  ${item.qty} x ${Formatters.rupiah(item.unitPrice)}',
            Formatters.rupiah(item.subtotal));
      }
      buffer.writeln();
    }

    if (receipt.partLines.isNotEmpty) {
      buffer.writeln('SPAREPART');
      for (final item in receipt.partLines) {
        buffer.writeln(item.name);
        addRow('  ${item.qty} x ${Formatters.rupiah(item.unitPrice)}',
            Formatters.rupiah(item.subtotal));
      }
      buffer.writeln();
    }

    buffer
      ..writeln(line)
      ..writeln('Total item     : ${receipt.totalItems}');

    addRow('Biaya layanan', Formatters.rupiah(receipt.serviceTotal));
    addRow('Biaya sparepart', Formatters.rupiah(receipt.partsTotal));
    if (receipt.discount > 0) {
      addRow('Diskon', '-${Formatters.rupiah(receipt.discount)}');
    }
    buffer.writeln(line);
    addRow('TOTAL', Formatters.rupiah(receipt.grandTotal));
    addRow('Dibayar', Formatters.rupiah(receipt.paidAmount));
    addRow('Sisa', Formatters.rupiah(receipt.remainingAmount));
    buffer
      ..writeln('Status : ${receipt.paymentStatusLabel}')
      ..writeln(line);

    if (receipt.isCancelled) {
      buffer.writeln('TRANSAKSI BATAL: ${receipt.cancelReason}');
    }
    if (receipt.footer.isNotEmpty) {
      buffer
        ..writeln(receipt.footer)
        ..writeln(line);
    }
    return buffer.toString();
  }
}
