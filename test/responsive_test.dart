import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';

import 'support/test_helpers.dart';

/// Kembali ke halaman utama (menu navigasi terlihat lagi).
Future<void> popToHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    if (tester.any(find.byType(NavigationBar))) return;
    // Pop route teratas langsung lewat Navigator (menghindari masalah
    // "satu tombol back" saat ada beberapa AppBar bertumpuk).
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    if (navigator.canPop()) {
      navigator.pop();
    }
    await pumpFrames(tester, times: 6);
  }
}

/// Menguji tampilan pada beberapa ukuran layar HP Android.
///
/// Layout yang meluap (overflow) akan otomatis membuat pengujian gagal,
/// jadi test ini sekaligus menjadi pemeriksaan ERROR RenderFlex.
void main() {
  tearDown(closeTestDatabase);

  /// Ukuran layar yang umum dipakai HP Android.
  const sizes = <String, Size>{
    'HP kecil 320x480': Size(320, 480),
    'HP standar 360x640': Size(360, 640),
    'HP besar 411x731': Size(411, 731),
    'Tablet 800x1280': Size(800, 1280),
  };

  for (final entry in sizes.entries) {
    testWidgets('tampilan rapi di ${entry.key}', (tester) async {
      final dependencies = await prepareApp(tester);
      var transactionNumber = '';
      var unpaidNumber = '';

      // Siapkan satu transaksi supaya setiap menu punya isi.
      await tester.runAsync(() async {
        final customers = await dependencies.customers.list();
        final vehicles = await dependencies.vehicles.list();
        final services = await dependencies.services.list();
        final transaction = await dependencies.transactions.createTransaction(
          TransactionDraft(
            customerId: customers.first.id!,
            vehicleId: vehicles.first.id!,
            services: [
              ServiceSelection(serviceId: services.first.id!, qty: 1),
            ],
          ),
        );
        await dependencies.payments.addPayment(
          transactionId: transaction.id!,
          amount: transaction.grandTotal,
          method: PaymentMethod.tunai,
        );
        transactionNumber = transaction.transactionNumber;

        // Transaksi kedua yang belum dibayar (untuk menguji sheet pembayaran).
        final unpaid = await dependencies.transactions.createTransaction(
          TransactionDraft(
            customerId: customers.first.id!,
            vehicleId: vehicles.first.id!,
            services: [
              ServiceSelection(serviceId: services.first.id!, qty: 1),
            ],
          ),
        );
        unpaidNumber = unpaid.transactionNumber;
      });

      await tester.binding.setSurfaceSize(entry.value);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Kunjungi setiap menu utama (lewat label di NavigationBar).
      const tabs = ['Pelanggan', 'Transaksi', 'Sparepart', 'Laporan'];
      final navBar = find.byType(NavigationBar);
      for (final label in tabs) {
        await tester.tap(
          find.descendant(of: navBar, matching: find.text(label)),
        );
        await pumpFrames(tester, times: 8);
      }
      // Buka form transaksi (halaman terpanjang).
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')),
      );
      await pumpFrames(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester, times: 8);

      // Buka struk.
      await tester.pageBack();
      await pumpFrames(tester, times: 8);
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')),
      );
      await pumpFrames(tester);
      await tester.tap(find.text(transactionNumber));
      await pumpFrames(tester, times: 10);
      await tester.tap(find.byIcon(Icons.receipt_outlined));
      await pumpFrames(tester, times: 10);

      // Struk harus tampil utuh.
      expect(find.text('TOTAL'), findsOneWidget);

      // Sheet pembayaran (bottomsheet paling penuh).
      await popToHome(tester);
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')),
      );
      await pumpFrames(tester);
      await tester.tap(find.text(unpaidNumber));
      await pumpFrames(tester, times: 10);
      // Tombol pembayaran bisa berada di bawah layar pada HP kecil.
      await scrollTo(tester, find.text('Catat Pembayaran'));
      await tester.tap(find.text('Catat Pembayaran'));
      await pumpFrames(tester, times: 8);
      // Sheet pembayaran terbuka (label "Sisa tagihan" muncul di sheet & detail).
      expect(find.text('Sisa tagihan'), findsAtLeastNWidgets(1));
      expect(find.text('Metode pembayaran'), findsOneWidget);
      await popToHome(tester);

      // Detail pelanggan.
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Pelanggan')),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('Andi Pratama'));
      await pumpFrames(tester, times: 10);
      expect(find.text('Kendaraan'), findsOneWidget);
      await popToHome(tester);

      // Detail sparepart.
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Sparepart')),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('Oli Mesin 1 Liter'));
      await pumpFrames(tester, times: 10);
      expect(find.text('Riwayat Pergerakan Stok'), findsOneWidget);
      await popToHome(tester);

      // Katalog layanan.
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Transaksi')),
      );
      await pumpFrames(tester);
      await tester.tap(find.byIcon(Icons.local_offer_outlined));
      await pumpFrames(tester, times: 10);
      expect(find.text('Katalog Layanan'), findsOneWidget);
      await popToHome(tester);

      // Pengaturan bengkel.
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Dashboard')),
      );
      await pumpFrames(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await pumpFrames(tester, times: 10);
      expect(find.text('Pengaturan Bengkel'), findsOneWidget);
    });
  }
}
