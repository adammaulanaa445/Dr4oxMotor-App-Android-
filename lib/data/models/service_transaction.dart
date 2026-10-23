import 'enums.dart';
import 'package:dr4ox_motor/core/utils/date_times.dart';

/// Header transaksi servis.
///
/// Besaran (harga layanan, harga sparepart, diskon, total) yang tersimpan di
/// sini adalah **nilai historis** saat transaksi dibuat. Perubahan harga
/// katalog di kemudian hari tidak akan mengubah transaksi lama.
class ServiceTransaction {
  const ServiceTransaction({
    this.id,
    this.transactionNumber = '',
    required this.customerId,
    required this.vehicleId,
    this.complaint = '',
    this.mechanicNotes = '',
    this.serviceTotal = 0,
    this.partsTotal = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.paidAmount = 0,
    this.workStatus = WorkStatus.menunggu,
    this.paymentStatus = PaymentStatus.belumDibayar,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelReason = '',
    required this.createdAt,
    this.updatedAt,
    this.ttsAnnouncedAt,
    this.customerName = '',
    this.customerPhone = '',
    this.plateNumber = '',
    this.vehicleBrand = '',
    this.vehicleModel = '',
  });

  final int? id;

  /// Nomor transaksi unik, contoh: `TRX-20261021-0007`.
  final String transactionNumber;

  final int customerId;
  final int vehicleId;

  /// Keluhan pelanggan.
  final String complaint;

  /// Catatan mekanik / pengerjaan.
  final String mechanicNotes;

  final int serviceTotal;
  final int partsTotal;
  final int discount;
  final int grandTotal;

  /// Total nominal yang sudah tercatat pada tabel pembayaran.
  final int paidAmount;

  final WorkStatus workStatus;
  final PaymentStatus paymentStatus;

  /// Transaksi batal: tetap tersimpan sebagai riwayat, tapi tidak dihitung
  /// sebagai pendapatan dan stok dikembalikan melalui koreksi.
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String cancelReason;

  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Waktu pengumuman TTS terakhir (mencegah pengumuman berulang).
  final DateTime? ttsAnnouncedAt;

  // --- Data hasil JOIN, hanya tersedia pada hasil pencarian/daftar ---
  final String customerName;
  final String customerPhone;
  final String plateNumber;
  final String vehicleBrand;
  final String vehicleModel;

  ServiceTransaction copyWith({
    int? id,
    String? transactionNumber,
    int? customerId,
    int? vehicleId,
    String? complaint,
    String? mechanicNotes,
    int? serviceTotal,
    int? partsTotal,
    int? discount,
    int? grandTotal,
    int? paidAmount,
    WorkStatus? workStatus,
    PaymentStatus? paymentStatus,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? ttsAnnouncedAt,
  }) {
    return ServiceTransaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      complaint: complaint ?? this.complaint,
      mechanicNotes: mechanicNotes ?? this.mechanicNotes,
      serviceTotal: serviceTotal ?? this.serviceTotal,
      partsTotal: partsTotal ?? this.partsTotal,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      workStatus: workStatus ?? this.workStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ttsAnnouncedAt: ttsAnnouncedAt ?? this.ttsAnnouncedAt,
      customerName: customerName,
      customerPhone: customerPhone,
      plateNumber: plateNumber,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'customer_id': customerId,
      'vehicle_id': vehicleId,
      'complaint': complaint,
      'mechanic_notes': mechanicNotes,
      'service_total': serviceTotal,
      'parts_total': partsTotal,
      'discount': discount,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'work_status': workStatus.dbValue,
      'payment_status': paymentStatus.dbValue,
      'is_cancelled': isCancelled ? 1 : 0,
      'cancelled_at': cancelledAt == null ? null : DateTimes.toIso(cancelledAt!),
      'cancel_reason': cancelReason,
      'created_at': DateTimes.toIso(createdAt),
      'updated_at': updatedAt == null ? null : DateTimes.toIso(updatedAt!),
      'tts_announced_at': ttsAnnouncedAt == null ? null : DateTimes.toIso(ttsAnnouncedAt!),
    };
  }

  factory ServiceTransaction.fromMap(Map<String, Object?> map) {
    return ServiceTransaction(
      id: map['id'] as int?,
      transactionNumber: (map['transaction_number'] as String?) ?? '',
      customerId: (map['customer_id'] as int?) ?? 0,
      vehicleId: (map['vehicle_id'] as int?) ?? 0,
      complaint: (map['complaint'] as String?) ?? '',
      mechanicNotes: (map['mechanic_notes'] as String?) ?? '',
      serviceTotal: (map['service_total'] as int?) ?? 0,
      partsTotal: (map['parts_total'] as int?) ?? 0,
      discount: (map['discount'] as int?) ?? 0,
      grandTotal: (map['grand_total'] as int?) ?? 0,
      paidAmount: (map['paid_amount'] as int?) ?? 0,
      workStatus: WorkStatus.fromDb(map['work_status'] as String?),
      paymentStatus: PaymentStatus.fromDb(map['payment_status'] as String?),
      isCancelled: ((map['is_cancelled'] as int?) ?? 0) == 1,
      cancelledAt: DateTime.tryParse((map['cancelled_at'] as String?) ?? ''),
      cancelReason: (map['cancel_reason'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      ttsAnnouncedAt: DateTime.tryParse((map['tts_announced_at'] as String?) ?? ''),
      customerName: (map['customer_name'] as String?) ?? '',
      customerPhone: (map['customer_phone'] as String?) ?? '',
      plateNumber: (map['plate_number'] as String?) ?? '',
      vehicleBrand: (map['vehicle_brand'] as String?) ?? '',
      vehicleModel: (map['vehicle_model'] as String?) ?? '',
    );
  }

  /// Sisa tagihan yang belum dibayar.
  int get remainingAmount {
    final remaining = grandTotal - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  /// Ringkasan status gabungan untuk tampilan daftar.
  String get combinedStatusLabel {
    if (isCancelled) return 'Batal';
    return '${workStatus.label} • ${paymentStatus.label}';
  }
}

/// Item layanan dalam sebuah transaksi (menyimpan harga saat transaksi dibuat).
class TransactionServiceItem {
  const TransactionServiceItem({
    this.id,
    this.transactionId,
    this.serviceId,
    required this.name,
    required this.price,
    this.qty = 1,
    required this.subtotal,
  });

  final int? id;
  final int? transactionId;

  /// Id katalog layanan (boleh null bila layanannya sudah dihapus).
  final int? serviceId;

  /// Snapshot nama layanan.
  final String name;

  /// Snapshot harga satuan saat transaksi dibuat.
  final int price;
  final int qty;
  final int subtotal;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'service_id': serviceId,
      'name': name,
      'price': price,
      'qty': qty,
      'subtotal': subtotal,
    };
  }

  factory TransactionServiceItem.fromMap(Map<String, Object?> map) {
    return TransactionServiceItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      serviceId: map['service_id'] as int?,
      name: (map['name'] as String?) ?? '',
      price: (map['price'] as int?) ?? 0,
      qty: (map['qty'] as int?) ?? 1,
      subtotal: (map['subtotal'] as int?) ?? 0,
    );
  }
}

/// Item sparepart dalam sebuah transaksi (menyimpan harga & jumlah historis).
class TransactionPartItem {
  const TransactionPartItem({
    this.id,
    this.transactionId,
    this.partId,
    required this.name,
    this.code = '',
    required this.price,
    required this.qty,
    required this.subtotal,
  });

  final int? id;
  final int? transactionId;
  final int? partId;

  /// Snapshot nama sparepart.
  final String name;

  /// Snapshot kode barang.
  final String code;

  /// Snapshot harga jual saat transaksi dibuat.
  final int price;
  final int qty;
  final int subtotal;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'part_id': partId,
      'name': name,
      'code': code,
      'price': price,
      'qty': qty,
      'subtotal': subtotal,
    };
  }

  factory TransactionPartItem.fromMap(Map<String, Object?> map) {
    return TransactionPartItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      partId: map['part_id'] as int?,
      name: (map['name'] as String?) ?? '',
      code: (map['code'] as String?) ?? '',
      price: (map['price'] as int?) ?? 0,
      qty: (map['qty'] as int?) ?? 0,
      subtotal: (map['subtotal'] as int?) ?? 0,
    );
  }
}

/// Catatan pembayaran yang disimpan untuk sebuah transaksi.
class Payment {
  const Payment({
    this.id,
    required this.transactionId,
    required this.amount,
    required this.method,
    this.note = '',
    required this.paidAt,
    required this.createdAt,
  });

  final int? id;
  final int transactionId;

  /// Nominal yang dibayar (bisa sebagian).
  final int amount;

  final PaymentMethod method;
  final String note;
  final DateTime paidAt;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'amount': amount,
      'method': method.dbValue,
      'note': note,
      'paid_at': DateTimes.toIso(paidAt),
      'created_at': DateTimes.toIso(createdAt),
    };
  }

  factory Payment.fromMap(Map<String, Object?> map) {
    return Payment(
      id: map['id'] as int?,
      transactionId: (map['transaction_id'] as int?) ?? 0,
      amount: (map['amount'] as int?) ?? 0,
      method: PaymentMethod.fromDb(map['method'] as String?),
      note: (map['note'] as String?) ?? '',
      paidAt: DateTime.tryParse((map['paid_at'] as String?) ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
    );
  }
}

/// Riwayat pergerakan stok sparepart.
class StockMovement {
  const StockMovement({
    this.id,
    required this.partId,
    this.transactionId,
    required this.type,
    required this.qtyChange,
    required this.stockAfter,
    this.note = '',
    required this.createdAt,
    this.partName = '',
  });

  final int? id;
  final int partId;
  final int? transactionId;
  final StockMovementType type;

  /// Bertanda positif untuk stok masuk, negatif untuk stok keluar.
  final int qtyChange;

  /// Jumlah stok setelah perubahan.
  final int stockAfter;
  final String note;
  final DateTime createdAt;

  /// Nama sparepart (diisi dari JOIN).
  final String partName;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'part_id': partId,
      'transaction_id': transactionId,
      'type': type.dbValue,
      'qty_change': qtyChange,
      'stock_after': stockAfter,
      'note': note,
      'created_at': DateTimes.toIso(createdAt),
    };
  }

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      partId: (map['part_id'] as int?) ?? 0,
      transactionId: map['transaction_id'] as int?,
      type: StockMovementType.fromDb(map['type'] as String?),
      qtyChange: (map['qty_change'] as int?) ?? 0,
      stockAfter: (map['stock_after'] as int?) ?? 0,
      note: (map['note'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      partName: (map['part_name'] as String?) ?? '',
    );
  }
}
