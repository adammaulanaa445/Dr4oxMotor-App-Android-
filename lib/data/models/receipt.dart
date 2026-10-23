/// Data struk dalam bentuk netral (tidak terikat PDF, printer, atau UI).
///
/// Struktur ini sengaja terpisah supaya strutur yang sama bisa dipakai untuk:
/// - tampilan struk di layar,
/// - file PDF,
/// - cetak ke printer thermal (ESC/POS) di masa depan.
class ReceiptData {
  const ReceiptData({
    required this.workshopName,
    required this.workshopAddress,
    required this.workshopPhone,
    required this.transactionNumber,
    required this.dateTime,
    required this.customerName,
    required this.customerPhone,
    required this.plateNumber,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.serviceLines,
    required this.partLines,
    required this.serviceTotal,
    required this.partsTotal,
    required this.discount,
    required this.grandTotal,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatusLabel,
    required this.paymentMethodLabel,
    required this.paidAt,
    required this.footer,
    this.isCancelled = false,
    this.cancelReason = '',
  });

  final String workshopName;
  final String workshopAddress;
  final String workshopPhone;

  final String transactionNumber;
  final DateTime dateTime;

  final String customerName;
  final String customerPhone;
  final String plateNumber;
  final String vehicleBrand;
  final String vehicleModel;

  final List<ReceiptLine> serviceLines;
  final List<ReceiptLine> partLines;

  final int serviceTotal;
  final int partsTotal;
  final int discount;
  final int grandTotal;
  final int paidAmount;
  final int remainingAmount;

  /// Label status pembayaran, contoh: `Lunas` / `Belum Dibayar`.
  final String paymentStatusLabel;

  /// Label metode pembayaran terakhir (bisa kosong bila belum ada pembayaran).
  final String paymentMethodLabel;

  /// Waktu pembayaran terakhir.
  final DateTime? paidAt;

  final String footer;
  final bool isCancelled;
  final String cancelReason;

  /// Nama kendaraan siap cetak, contoh: `B 1234 ABC - Honda Beat`.
  String get vehicleDisplay {
    final detail = [vehicleBrand, vehicleModel]
        .where((e) => e.isNotEmpty)
        .join(' ');
    if (detail.isEmpty) return plateNumber;
    return '$plateNumber - $detail';
  }

  /// Total item yang dicetak (layanan + sparepart).
  int get totalItems {
    var total = 0;
    for (final line in serviceLines) {
      total += line.qty;
    }
    for (final line in partLines) {
      total += line.qty;
    }
    return total;
  }
}

/// Satu baris item pada struk.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.unit = '',
  });

  final String name;
  final int qty;
  final int unitPrice;
  final int subtotal;

  /// Satuan barang (sparepart), kosong untuk layanan.
  final String unit;
}
