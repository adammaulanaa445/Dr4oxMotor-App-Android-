import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/part_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/vehicle_repository.dart';

/// Kumpulan seluruh repository yang dipakai aplikasi.
///
/// Dibuat sekali saat aplikasi dijalankan lalu dibagikan ke seluruh widget
/// melalui [AppScope].
class AppDependencies {
  AppDependencies({AppDatabase? database})
      : database = database ?? AppDatabase.instance;

  final AppDatabase database;

  /// Indeks menu yang sedang aktif (0 = Dashboard).
  ///
  /// Setiap halaman daftar berlangganan nilai ini dan memuat ulang data
  /// ketika menunya aktif, sehingga data selalu sinkron (misal transaksi
  /// yang dibuat dari halaman lain).
  final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  late final CustomerRepository customers = CustomerRepository(database);
  late final VehicleRepository vehicles = VehicleRepository(database);
  late final ServiceRepository services = ServiceRepository(database);
  late final PartRepository parts = PartRepository(database);
  late final TransactionRepository transactions = TransactionRepository(database);
  late final PaymentRepository payments = PaymentRepository(database);
  late final SettingsRepository settings = SettingsRepository(database);
}
