import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';

import 'support/test_helpers.dart';

void main() {
  tearDown(closeTestDatabase);

  group('Tahap 5 - Menu Sparepart', () {
    testWidgets('daftar sparepart menampilkan data dari database',
        (tester) async {
      await prepareApp(tester);

      // Pindah ke tab Sparepart.
      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await pumpFrames(tester);

      expect(find.text('Sparepart'), findsWidgets);
      expect(find.text('Oli Mesin 1 Liter'), findsOneWidget);
      expect(find.textContaining('stok 10 botol'), findsOneWidget);
    });

    testWidgets('menambah sparepart baru melalui form', (tester) async {
      final dependencies = await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await pumpFrames(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama sparepart *'),
        'Kampas Rem Beat',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Harga jual *'),
        '45000',
      );
      await pumpFrames(tester);

      await scrollTo(tester, find.text('Simpan Sparepart'));
      await tester.tap(find.text('Simpan Sparepart'));
      await pumpFrames(tester, times: 12);

      final parts = await dependencies.parts.list();
      expect(parts.any((p) => p.name == 'Kampas Rem Beat'), isTrue);
      expect(find.text('Kampas Rem Beat'), findsOneWidget);
    });

    testWidgets('detail sparepart menampilkan stok & riwayat pergerakan',
        (tester) async {
      final dependencies = await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await pumpFrames(tester);

      await tester.tap(find.text('Oli Mesin 1 Liter'));
      await pumpFrames(tester);

      expect(find.text('Detail Sparepart'), findsOneWidget);
      expect(find.text('Stok tersedia'), findsOneWidget);
      expect(find.text('10 botol'), findsOneWidget);
      expect(find.text('Riwayat Pergerakan Stok'), findsOneWidget);

      // Riwayat awal: stok awal tercatat saat sparepart dibuat.
      final parts = await dependencies.parts.list();
      final part = parts.firstWhere((p) => p.name == 'Oli Mesin 1 Liter');
      final movements = await dependencies.parts.history(part.id!);
      expect(movements.length, 1);
      expect(movements.first.type, StockMovementType.masuk);
    });
  });

  group('Tahap 6 - Laporan', () {
    testWidgets('laporan menampilkan ringkasan periode', (tester) async {
      await prepareApp(tester);

      // Pindah ke tab Laporan.
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await pumpFrames(tester);

      expect(find.text('Laporan'), findsWidgets);
      expect(find.text('Total Transaksi'), findsOneWidget);
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Sisa Tagihan'), findsOneWidget);
      expect(find.text('Transaksi Batal'), findsOneWidget);
    });

    testWidgets('pendapatan laporan hanya menghitung transaksi lunas',
        (tester) async {
      final dependencies = await prepareApp(tester);

      // Buat satu transaksi lunas dan satu belum lunas.
      await tester.runAsync(() async {
        final customer = await dependencies.customers.list();
        final vehicles = await dependencies.vehicles.list();
        final services = await dependencies.services.list();
        final customerId = customer.first.id!;
        final vehicleId = vehicles.first.id!;

        final lunas = await dependencies.transactions.createTransaction(
          TransactionDraft(
            customerId: customerId,
            vehicleId: vehicleId,
            services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
          ),
        );
        await dependencies.transactions.createTransaction(
          TransactionDraft(
            customerId: customerId,
            vehicleId: vehicleId,
            services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
          ),
        );
        await dependencies.payments.addPayment(
          transactionId: lunas.id!,
          amount: lunas.grandTotal,
          method: PaymentMethod.tunai,
        );
      });

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await pumpFrames(tester);

      // Dua transaksi tercatat, hanya satu yang lunas.
      final summary = await dependencies.transactions.reportSummary(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );
      expect(summary.transactionCount, 2);
      expect(summary.revenue, greaterThan(0));
      expect(summary.unpaidAmount, greaterThan(0));
    });
  });

  group('Pengaturan', () {
    testWidgets('halaman pengaturan dapat dibuka & menyimpan TTS',
        (tester) async {
      final dependencies = await prepareApp(tester);

      // Tombol pengaturan ada di Dashboard.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await pumpFrames(tester);

      expect(find.text('Pengaturan Bengkel'), findsOneWidget);
      expect(find.text('Umum saat servis selesai'), findsOneWidget);

      // Matikan TTS lalu simpan.
      await tester.tap(find.byType(Switch));
      await pumpFrames(tester);
      await scrollTo(tester, find.text('Simpan Pengaturan'));
      await tester.tap(find.text('Simpan Pengaturan'));
      await pumpFrames(tester, times: 8);

      final settings = await dependencies.settings.load();
      expect(settings.ttsEnabled, isFalse);
    });
  });
}
