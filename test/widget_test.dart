import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/app.dart';
import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('aplikasi menampilkan dashboard dan 5 menu utama',
      (WidgetTester tester) async {
    final database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );

    // Pembukaan database memakai operasi I/O sungguhan, jadi harus
    // dijalankan di dalam tester.runAsync().
    await tester.runAsync(() async {
      await database.database;
    });

    await tester.pumpWidget(
      Dr4oxApp(dependencies: AppDependencies(database: database)),
    );

    // Beri waktu event loop sungguhan untuk menyelesaikan query dashboard.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Judul aplikasi.
    expect(find.text('Dr4ox Motor'), findsOneWidget);

    // Lima menu navigasi (diambil dari NavigationBar agar tidak bentrok
    // dengan label tombol lain yang sama).
    final navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.text('Dashboard')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Pelanggan')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Transaksi')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Sparepart')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Laporan')),
      findsOneWidget,
    );

    // Kartu ringkasan dashboard.
    expect(find.text('Transaksi Hari Ini'), findsOneWidget);
    expect(find.text('Pendapatan Hari Ini'), findsOneWidget);

    await tester.runAsync(() async {
      await database.close();
    });
  });
}
