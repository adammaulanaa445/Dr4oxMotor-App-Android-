/// Status pengerjaan sebuah transaksi servis.
///
/// Status ini sepenuhnya terpisah dari status pembayaran.
enum WorkStatus {
  menunggu('menunggu', 'Menunggu'),
  dikerjakan('dikerjakan', 'Sedang Dikerjakan'),
  selesai('selesai', 'Selesai');

  const WorkStatus(this.dbValue, this.label);

  /// Nilai yang disimpan di database.
  final String dbValue;

  /// Teks yang ditampilkan ke pengguna.
  final String label;

  /// Mengubah nilai database menjadi enum.
  static WorkStatus fromDb(String? value) {
    return WorkStatus.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => WorkStatus.menunggu,
    );
  }
}

/// Status pembayaran sebuah transaksi servis.
enum PaymentStatus {
  belumDibayar('belum_dibayar', 'Belum Dibayar'),
  lunas('lunas', 'Lunas');

  const PaymentStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PaymentStatus fromDb(String? value) {
    return PaymentStatus.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => PaymentStatus.belumDibayar,
    );
  }
}

/// Metode pembayaran yang dicatat manual oleh pengguna.
enum PaymentMethod {
  tunai('tunai', 'Tunai'),
  transfer('transfer', 'Transfer'),
  qris('qris', 'QRIS'),
  lainnya('lainnya', 'Lainnya');

  const PaymentMethod(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PaymentMethod fromDb(String? value) {
    return PaymentMethod.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => PaymentMethod.tunai,
    );
  }
}

/// Jenis pergerakan stok sparepart.
enum StockMovementType {
  masuk('masuk', 'Stok Masuk'),
  keluar('keluar', 'Stok Keluar'),
  koreksi('koreksi', 'Koreksi / Pembatalan'),
  penyesuaian('penyesuaian', 'Penyesuaian Manual');

  const StockMovementType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static StockMovementType fromDb(String? value) {
    return StockMovementType.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => StockMovementType.penyesuaian,
    );
  }
}
