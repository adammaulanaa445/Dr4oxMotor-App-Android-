/// Pilihan layanan pada draft transaksi.
class ServiceSelection {
  const ServiceSelection({required this.serviceId, this.qty = 1});

  final int serviceId;
  final int qty;
}

/// Pilihan sparepart pada draft transaksi.
class PartSelection {
  const PartSelection({required this.partId, this.qty = 1});

  final int partId;
  final int qty;
}

/// Data yang dikumpulkan pengguna pada form transaksi baru.
///
/// Repository-lah yang menghitung total, bukan widget UI.
class TransactionDraft {
  const TransactionDraft({
    required this.customerId,
    required this.vehicleId,
    this.complaint = '',
    this.mechanicNotes = '',
    this.discount = 0,
    this.services = const [],
    this.parts = const [],
  });

  final int customerId;
  final int vehicleId;
  final String complaint;
  final String mechanicNotes;
  final int discount;
  final List<ServiceSelection> services;
  final List<PartSelection> parts;

  bool get hasItems => services.isNotEmpty || parts.isNotEmpty;

  TransactionDraft copyWith({
    int? customerId,
    int? vehicleId,
    String? complaint,
    String? mechanicNotes,
    int? discount,
    List<ServiceSelection>? services,
    List<PartSelection>? parts,
  }) {
    return TransactionDraft(
      customerId: customerId ?? this.customerId,
      vehicleId: vehicleId ?? this.vehicleId,
      complaint: complaint ?? this.complaint,
      mechanicNotes: mechanicNotes ?? this.mechanicNotes,
      discount: discount ?? this.discount,
      services: services ?? this.services,
      parts: parts ?? this.parts,
    );
  }
}
