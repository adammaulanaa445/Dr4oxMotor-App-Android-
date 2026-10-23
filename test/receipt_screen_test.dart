import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';

import 'support/test_helpers.dart';

void main() {
  tearDown(closeTestDatabase);

  group('Tahap 7 - Halaman struk', () {
    testWidgets('struk menampilkan data transaksi dari detail',
        (tester) async {
      final dependencies = await prepareApp(tester);

      // Buat satu transaksi lunas lewat repository.
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
      });

      // Buka tab Transaksi lalu transaksi yang dibuat.
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      final transactions =
          await dependencies.transactions.list(const TransactionFilter());
      await tester.tap(find.text(transactions.first.transactionNumber));
      await pumpFrames(tester, times: 12);

      // Buka struk lewat ikon pada detail transaksi.
      await tester.tap(find.byIcon(Icons.receipt_outlined));
      await pumpFrames(tester, times: 12);

      // Isi struk tampil.
      expect(find.text('Struk'), findsOneWidget);
      expect(find.text('No. Transaksi'), findsOneWidget);
      expect(find.text('Andi Pratama'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);
      expect(find.text('Bagikan PDF'), findsOneWidget);
    });
  });
}
