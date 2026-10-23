import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';
import 'package:dr4ox_motor/features/transactions/payment_sheet.dart';

import 'support/test_helpers.dart';

/// Menguji pengaman klik ganda pada tombol yang mengubah data.
void main() {
  tearDown(closeTestDatabase);

  group('Pengaman klik ganda', () {
    testWidgets('tombol catat pembayaran ditekan dua kali tidak membuka '
        'dua sheet', (tester) async {
      final dependencies = await prepareApp(tester);

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
          amount: 1000,
          method: PaymentMethod.tunai,
        );
      });

      // Buka detail transaksi.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transaksi'),
        ),
      );
      await pumpFrames(tester);

      final transactions =
          await dependencies.transactions.list(const TransactionFilter());
      final transactionId = transactions.first.id!;
      final paymentsBefore =
          await dependencies.payments.listByTransaction(transactionId);
      expect(paymentsBefore.length, 1);

      // Buka detail transaksi.
      await tester.tap(find.text(transactions.first.transactionNumber));
      await pumpFrames(tester, times: 12);

      // Tekan tombol "Catat Pembayaran" dua kali tanpa menunggu.
      await scrollTo(tester, find.text('Catat Pembayaran'));
      final button = find.text('Catat Pembayaran');
      await tester.tap(button);
      await tester.tap(button);
      await pumpFrames(tester, times: 10);

      // Hanya SATU sheet pembayaran yang boleh terbuka.
      // (Dua sheet = tombol bisa dipakai dua kali & pembayaran ganda.)
      expect(find.byType(PaymentSheet), findsOneWidget);

      // Simpan pembayaran di sheet tersebut.
      if (find.text('Simpan Pembayaran').evaluate().isNotEmpty) {
        await tester.tap(find.text('Simpan Pembayaran'));
        await pumpFrames(tester, times: 14);
      }

      // Satu klik ganda tidak boleh menambah lebih dari satu pembayaran.
      final paymentsAfter =
          await dependencies.payments.listByTransaction(transactionId);
      expect(
        paymentsAfter.length,
        lessThanOrEqualTo(paymentsBefore.length + 1),
        reason: 'klik ganda tidak boleh mencatat 2 pembayaran',
      );
    });

    testWidgets('pembayaran ganda tetap ditolak oleh aturan data',
        (tester) async {
      final dependencies = await prepareApp(tester);

      // Transaksi sudah lunas -> pembayaran tambahan harus ditolak.
      final transactionId = await tester.runAsync(() async {
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
        return transaction.id!;
      });
      final id = transactionId!;

      // Pembayaran kedua pada transaksi lunas ditolak.
      await expectLater(
        dependencies.payments.addPayment(
          transactionId: id,
          amount: 1000,
          method: PaymentMethod.tunai,
        ),
        throwsA(isA<Exception>()),
      );

      // Dan tidak ada pembayaran ganda yang tersimpan.
      final payments = await dependencies.payments.listByTransaction(id);
      expect(payments.length, 1);
    });
  });
}
