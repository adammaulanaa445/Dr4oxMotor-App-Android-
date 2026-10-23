import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/app.dart';
import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';

/// Pump beberapa frame tanpa pumpAndSettle.
///
/// `pumpAndSettle` tidak boleh dipakai di aplikasi ini karena
/// CircularProgressIndicator selalu menychedule frame baru.
Future<void> pumpFrames(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Menggulir halaman sampai widget yang dicari terlihat.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView).last,
    const Offset(0, -240),
  );
  await pumpFrames(tester);
}

/// Database terakhir yang dipakai, ditutup setelah setiap pengujian
/// supaya tiap pengujian memakai database in-memory yang benar-benar baru.
AppDatabase? lastDatabase;

/// Menyiapkan aplikasi dengan database in-memory + data contoh minimal.
Future<AppDependencies> prepareApp(
  WidgetTester tester, {
  bool withSparepart = true,
}) async {
  sqfliteFfiInit();

  final database = AppDatabase.forTesting(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
  final dependencies = AppDependencies(database: database);
  lastDatabase = database;

  await tester.runAsync(() async {
    await database.database;
    await initializeDateFormatting('id_ID', null);

    final customer = await dependencies.customers.create(
      name: 'Andi Pratama',
      phone: '081234567890',
    );
    await dependencies.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 1234 ABC',
      brand: 'Honda',
      model: 'Beat',
    );

    if (withSparepart) {
      await dependencies.parts.create(
        name: 'Oli Mesin 1 Liter',
        sellPrice: 55000,
        stock: 10,
        minStock: 2,
        unit: 'botol',
      );
    }
  });

  await tester.pumpWidget(
    Dr4oxApp(dependencies: dependencies),
  );
  await pumpFrames(tester);
  return dependencies;
}

/// Menutup database pengujian (dipanggil di tearDown).
Future<void> closeTestDatabase() async {
  await lastDatabase?.close();
  lastDatabase = null;
}
