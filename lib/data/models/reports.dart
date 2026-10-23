/// Ringkasan data untuk Dashboard.
class DashboardSummary {
  const DashboardSummary({
    this.todayTransactionCount = 0,
    this.inProgressCount = 0,
    this.waitingCount = 0,
    this.unpaidCount = 0,
    this.todayRevenue = 0,
    this.monthRevenue = 0,
    this.periodRevenue = 0,
    this.periodTransactionCount = 0,
    this.lowStockParts = const [],
  });

  /// Jumlah transaksi dibuat hari ini (transaksi batal tidak dihitung).
  final int todayTransactionCount;

  /// Jumlah transaksi berstatus "Sedang Dikerjakan".
  final int inProgressCount;

  /// Jumlah transaksi berstatus "Menunggu".
  final int waitingCount;

  /// Jumlah transaksi belum lunas (dan belum dibatalkan).
  final int unpaidCount;

  /// Pendapatan yang benar-benar diterima hari ini (hanya transaksi lunas).
  final int todayRevenue;

  /// Pendapatan lunas bulan berjalan.
  final int monthRevenue;

  /// Pendapatan lunas pada periode yang dipilih pengguna.
  final int periodRevenue;

  /// Jumlah transaksi pada periode yang dipilih.
  final int periodTransactionCount;

  /// Sparepart yang stoknya menyentuh batas minimum.
  final List<LowStockInfo> lowStockParts;
}

/// Informasi ringkas sparepart stok menipis.
class LowStockInfo {
  const LowStockInfo({
    required this.id,
    required this.name,
    required this.stock,
    required this.minStock,
    required this.unit,
  });

  final int id;
  final String name;
  final int stock;
  final int minStock;
  final String unit;
}

/// Rekap penggunaan sparepart pada periode tertentu.
class PartUsage {
  const PartUsage({
    required this.partId,
    required this.name,
    required this.qty,
    required this.total,
  });

  final int partId;
  final String name;

  /// Total jumlah yang terpakai pada periode tersebut.
  final int qty;

  /// Total nilai penjualan sparepart pada periode tersebut.
  final int total;
}

/// Ringkasan periode laporan.
class ReportSummary {
  const ReportSummary({
    this.transactionCount = 0,
    this.revenue = 0,
    this.paidRevenue = 0,
    this.unpaidAmount = 0,
    this.cancelledCount = 0,
    this.serviceCount = 0,
    this.partsCount = 0,
  });

  final int transactionCount;

  /// Total pendapatan dari transaksi lunas (paling penting).
  final int revenue;

  /// Total nominal yang tercatat di tabel pembayaran (termasuk sebagian).
  final int paidRevenue;

  /// Total sisa tagihan transaksi yang belum lunas.
  final int unpaidAmount;

  final int cancelledCount;
  final int serviceCount;
  final int partsCount;
}
