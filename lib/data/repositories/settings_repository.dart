import 'package:sqflite/sqflite.dart';

import '../local/database_schema.dart';
import '../models/printer_profile.dart';
import 'base_repository.dart';

/// Pengaturan bengkel (nama, alamat, nomor telepon, opsi TTS, dll).
class WorkshopSettings {
  const WorkshopSettings({
    this.workshopName = 'Dr4ox Motor',
    this.workshopAddress = '',
    this.workshopPhone = '',
    this.receiptFooter = '',
    this.ttsEnabled = true,
  });

  final String workshopName;
  final String workshopAddress;
  final String workshopPhone;
  final String receiptFooter;
  final bool ttsEnabled;

  WorkshopSettings copyWith({
    String? workshopName,
    String? workshopAddress,
    String? workshopPhone,
    String? receiptFooter,
    bool? ttsEnabled,
  }) {
    return WorkshopSettings(
      workshopName: workshopName ?? this.workshopName,
      workshopAddress: workshopAddress ?? this.workshopAddress,
      workshopPhone: workshopPhone ?? this.workshopPhone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    );
  }
}

/// Repository untuk menyimpan & membaca pengaturan bengkel.
class SettingsRepository extends BaseRepository {
  SettingsRepository(super.appDatabase);

  static const String keyWorkshopName = 'workshop_name';
  static const String keyWorkshopAddress = 'workshop_address';
  static const String keyWorkshopPhone = 'workshop_phone';
  static const String keyReceiptFooter = 'receipt_footer';
  static const String keyTtsEnabled = 'tts_enabled';

  // Kunci profil printer (disimpan terpisah agar mudah diubah nanti).
  static const List<String> printerKeys = [
    'printer_name',
    'printer_model',
    'printer_paper_width',
    'printer_protocol',
    'printer_notes',
  ];

  /// Mengambil satu nilai pengaturan (null bila belum ada).
  Future<String?> getValue(String key) async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Menyimpan satu nilai pengaturan (menimpa bila sudah ada).
  Future<void> setValue(String key, String value) async {
    final db = await this.db;
    await db.insert(
      DatabaseSchema.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Membaca seluruh pengaturan sekaligus.
  Future<WorkshopSettings> load() async {
    final db = await this.db;
    final rows = await db.query(DatabaseSchema.tableSettings);
    final map = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return WorkshopSettings(
      workshopName: map[keyWorkshopName] ?? 'Dr4ox Motor',
      workshopAddress: map[keyWorkshopAddress] ?? '',
      workshopPhone: map[keyWorkshopPhone] ?? '',
      receiptFooter: map[keyReceiptFooter] ?? '',
      ttsEnabled: (map[keyTtsEnabled] ?? 'true') == 'true',
    );
  }

  /// Menyimpan seluruh pengaturan sekaligus.
  Future<void> save(WorkshopSettings settings) async {    final db = await this.db;
    final batch = db.batch();
    void put(String key, String value) {
      batch.insert(
        DatabaseSchema.tableSettings,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    put(keyWorkshopName, settings.workshopName);
    put(keyWorkshopAddress, settings.workshopAddress);
    put(keyWorkshopPhone, settings.workshopPhone);
    put(keyReceiptFooter, settings.receiptFooter);
    put(keyTtsEnabled, settings.ttsEnabled ? 'true' : 'false');
    await batch.commit(noResult: true);
  }

  /// Membaca profil printer yang tersimpan.
  Future<PrinterProfile> loadPrinterProfile() async {
    final db = await this.db;
    final rows = await db.query(
      DatabaseSchema.tableSettings,
      where: 'key IN (${printerKeys.map((_) => '?').join(', ')})',
      whereArgs: printerKeys,
    );
    final values = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return PrinterProfile.fromSettings(values);
  }

  /// Menyimpan profil printer.
  Future<void> savePrinterProfile(PrinterProfile profile) async {
    final db = await this.db;
    final batch = db.batch();
    for (final entry in profile.toSettings().entries) {
      batch.insert(
        DatabaseSchema.tableSettings,
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
