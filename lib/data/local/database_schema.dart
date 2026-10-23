import 'package:sqflite/sqflite.dart';

/// Definisi skema database Dr4ox Motor.
///
/// Semua perubahan skema harus dibuat lewat fungsi migrasi di bawah supaya
/// data pengguna lama tidak hilang saat aplikasi diperbarui.
class DatabaseSchema {
  const DatabaseSchema._();

  /// Versi skema saat ini.
  ///
  /// Naikkan nomor ini setiap kali menambah tabel/kolom, lalu tambahkan
  /// langkah migrasi pada [migrate].
  static const int version = 1;

  // ----------------------------- Nama tabel -----------------------------
  static const String tableCustomers = 'customers';
  static const String tableVehicles = 'vehicles';
  static const String tableServices = 'services';
  static const String tableParts = 'parts';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionServices = 'transaction_services';
  static const String tableTransactionParts = 'transaction_parts';
  static const String tablePayments = 'payments';
  static const String tableStockMovements = 'stock_movements';
  static const String tableSettings = 'app_settings';

  /// Dipanggil saat database dibuat untuk pertama kali.
  static Future<void> onCreate(Database db) async {
    await createTables(db);
    await seedInitialData(db);
  }

  /// Dipanggil saat aplikasi diperbarui dan versi skema naik.
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await createTables(db);
      await seedInitialData(db);
    }
    // Contoh langkah migrasi versi berikutnya:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE parts ADD COLUMN warranty INTEGER NOT NULL DEFAULT 0');
    // }
  }

  /// Membuat seluruh tabel dan indeks.
  static Future<void> createTables(Database db) async {
    final batch = db.batch();

    // 1. Pelanggan
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Kendaraan (relasi ke pelanggan)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableVehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        plate_number TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE RESTRICT
      )
    ''');

    // 3. Katalog layanan
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableServices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        price INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // 4. Sparepart / inventaris
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableParts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        purchase_price INTEGER NOT NULL DEFAULT 0,
        sell_price INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'pcs',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // 5. Header transaksi
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number TEXT NOT NULL,
        customer_id INTEGER NOT NULL,
        vehicle_id INTEGER NOT NULL,
        complaint TEXT NOT NULL DEFAULT '',
        mechanic_notes TEXT NOT NULL DEFAULT '',
        service_total INTEGER NOT NULL DEFAULT 0,
        parts_total INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        grand_total INTEGER NOT NULL DEFAULT 0,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        work_status TEXT NOT NULL DEFAULT 'menunggu',
        payment_status TEXT NOT NULL DEFAULT 'belum_dibayar',
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        cancelled_at TEXT,
        cancel_reason TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        tts_announced_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE RESTRICT,
        FOREIGN KEY (vehicle_id) REFERENCES $tableVehicles (id) ON DELETE RESTRICT
      )
    ''');

    // 6. Item layanan pada transaksi (harga disimpan sebagai snapshot)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableTransactionServices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        service_id INTEGER,
        name TEXT NOT NULL,
        price INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL DEFAULT 1,
        subtotal INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions (id) ON DELETE CASCADE,
        FOREIGN KEY (service_id) REFERENCES $tableServices (id) ON DELETE SET NULL
      )
    ''');

    // 7. Item sparepart pada transaksi (harga & jumlah disimpan sebagai snapshot)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableTransactionParts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        part_id INTEGER,
        name TEXT NOT NULL,
        code TEXT NOT NULL DEFAULT '',
        price INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL DEFAULT 0,
        subtotal INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions (id) ON DELETE CASCADE,
        FOREIGN KEY (part_id) REFERENCES $tableParts (id) ON DELETE SET NULL
      )
    ''');

    // 8. Pembayaran
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        method TEXT NOT NULL DEFAULT 'tunai',
        note TEXT NOT NULL DEFAULT '',
        paid_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions (id) ON DELETE RESTRICT
      )
    ''');

    // 9. Riwayat pergerakan stok
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableStockMovements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        part_id INTEGER NOT NULL,
        transaction_id INTEGER,
        type TEXT NOT NULL,
        qty_change INTEGER NOT NULL DEFAULT 0,
        stock_after INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (part_id) REFERENCES $tableParts (id) ON DELETE RESTRICT,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions (id) ON DELETE SET NULL
      )
    ''');

    // 10. Pengaturan bengkel (key-value)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ------------------------------- Indeks -------------------------------
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON $tableCustomers (name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON $tableCustomers (phone)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON $tableVehicles (customer_id)',
    );
    batch.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicles_plate ON $tableVehicles (plate_number)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_parts_name ON $tableParts (name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_created ON $tableTransactions (created_at)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_customer ON $tableTransactions (customer_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_vehicle ON $tableTransactions (vehicle_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_status ON $tableTransactions (work_status, payment_status)',
    );
    batch.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tx_number ON $tableTransactions (transaction_number)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_service_tx ON $tableTransactionServices (transaction_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_part_tx ON $tableTransactionParts (transaction_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_tx ON $tablePayments (transaction_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_part ON $tableStockMovements (part_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_created ON $tableStockMovements (created_at)',
    );

    await batch.commit(noResult: true);
  }

  /// Mengisi data awal (katalog layanan contoh + pengaturan bengkel).
  ///
  /// Data contoh di sini hanya katalog layanan & pengaturan, bukan transaksi,
  /// sehingga tidak akan mengotori laporan pendapatan.
  static Future<void> seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final defaultSettings = <String, String>{
      'workshop_name': 'Dr4ox Motor',
      'workshop_address': '',
      'workshop_phone': '',
      'receipt_footer': 'Terima kasih telah membawa motor Anda ke Dr4ox Motor',
      'tts_enabled': 'true',
    };

    for (final entry in defaultSettings.entries) {
      await db.insert(
        tableSettings,
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final serviceCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableServices'),
        ) ??
        0;
    if (serviceCount > 0) return;

    final services = <Map<String, Object?>>[
      {
        'name': 'Ganti Oli',
        'description': 'Penggantian oli mesin + penyaringan oli',
        'price': 60000,
        'is_active': 1,
        'created_at': now,
      },
      {
        'name': 'Servis Ringan',
        'description': 'Cek rem, busi, filter, dan tear down ringan',
        'price': 120000,
        'is_active': 1,
        'created_at': now,
      },
      {
        'name': 'Servis Lengkap',
        'description': 'Servis menyeluruh termasuk tune up dan overhaul ringan',
        'price': 350000,
        'is_active': 1,
        'created_at': now,
      },
      {
        'name': 'Penggantian Kampas Rem',
        'description': 'Ganti kampas rem depan dan belakang',
        'price': 90000,
        'is_active': 1,
        'created_at': now,
      },
      {
        'name': 'Pemeriksaan Kendaraan',
        'description': 'Diagnosis umum dan pemeriksaan kelengkapan',
        'price': 25000,
        'is_active': 1,
        'created_at': now,
      },
    ];

    final batch = db.batch();
    for (final service in services) {
      batch.insert(tableServices, service);
    }
    await batch.commit(noResult: true);
  }
}
