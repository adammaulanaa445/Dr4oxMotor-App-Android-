/// Lebar kertas printer thermal.
enum PrinterPaperWidth {
  mm58('58mm', '58 mm', 32),
  mm80('80mm', '80 mm', 42);

  const PrinterPaperWidth(this.dbValue, this.label, this.columns);

  /// Nilai yang disimpan di database.
  final String dbValue;

  /// Teks yang ditampilkan ke pengguna.
  final String label;

  /// Jumlah kolom per baris pada kertas 58mm (32) atau 80mm (42).
  final int columns;

  static PrinterPaperWidth fromDb(String? value) {
    return PrinterPaperWidth.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => PrinterPaperWidth.mm80,
    );
  }
}

/// Protokol komunikasi printer.
enum PrinterProtocol {
  escPos('esc_pos', 'ESC/POS'),
  unknown('unknown', 'Belum diketahui');

  const PrinterProtocol(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PrinterProtocol fromDb(String? value) {
    return PrinterProtocol.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => PrinterProtocol.unknown,
    );
  }
}

/// Profil printer yang akan dipakai saat pencetakan.
///
/// Disimpan di pengaturan bengkel supaya informasi printer tidak hilang
/// ketika someday perangkatnya sudah dibeli.
class PrinterProfile {
  const PrinterProfile({
    this.name = '',
    this.model = '',
    this.paperWidth = PrinterPaperWidth.mm80,
    this.protocol = PrinterProtocol.escPos,
    this.notes = '',
  });

  /// Nama bebas, contoh: `Printer Meja Bengkel`.
  final String name;

  /// Merek & model, contoh: `RPP-02A`.
  final String model;

  /// Lebar kertas yang dipakai.
  final PrinterPaperWidth paperWidth;

  /// Protokol yang dipakai.
  final PrinterProtocol protocol;

  /// Catatan bebas (mis. alamat MAC / id perangkat).
  final String notes;

  /// True bila profil sudah cukup lengkap untuk dicoba dicetak.
  bool get isConfigured => model.trim().isNotEmpty;

  /// Ringkasan singkat untuk ditampilkan.
  String get summary {
    final parts = <String>[];
    if (model.trim().isNotEmpty) parts.add(model.trim());
    parts.add(paperWidth.label);
    if (protocol != PrinterProtocol.unknown) parts.add(protocol.label);
    return parts.join(' • ');
  }

  PrinterProfile copyWith({
    String? name,
    String? model,
    PrinterPaperWidth? paperWidth,
    PrinterProtocol? protocol,
    String? notes,
  }) {
    return PrinterProfile(
      name: name ?? this.name,
      model: model ?? this.model,
      paperWidth: paperWidth ?? this.paperWidth,
      protocol: protocol ?? this.protocol,
      notes: notes ?? this.notes,
    );
  }

  Map<String, String> toSettings() {
    return {
      'printer_name': name,
      'printer_model': model,
      'printer_paper_width': paperWidth.dbValue,
      'printer_protocol': protocol.dbValue,
      'printer_notes': notes,
    };
  }

  factory PrinterProfile.fromSettings(Map<String, String> values) {
    return PrinterProfile(
      name: values['printer_name'] ?? '',
      model: values['printer_model'] ?? '',
      paperWidth: PrinterPaperWidth.fromDb(values['printer_paper_width']),
      protocol: PrinterProtocol.fromDb(values['printer_protocol']),
      notes: values['printer_notes'] ?? '',
    );
  }
}
