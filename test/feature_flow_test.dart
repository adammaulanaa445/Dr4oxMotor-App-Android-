import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/repositories/transaction_repository.dart';

import 'support/test_helpers.dart';

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

void main() {
  tearDown(closeTestDatabase);

  group('Tahap 3 - Pelanggan & kendaraan', () {
    testWidgets('menambah pelanggan baru melalui form', (tester) async {
      await prepareApp(tester);

      // Pindah ke tab Pelanggan.
      await tester.tap(find.byIcon(Icons.people_outline));
      await pumpFrames(tester);

      // Tekan tombol tambah pelanggan.
      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester);

      // Isi form.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama pelanggan *'),
        'Budi Santoso',
      );
      await pumpFrames(tester);

      await tester.ensureVisible(find.text('Simpan Pelanggan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Simpan Pelanggan'));
      // 12 frame: cukup untuk animasi keluar halaman form selesai.
      await pumpFrames(tester, times: 12);
      // Pelanggan baru tampil di daftar.
      expect(find.text('Budi Santoso'), findsOneWidget);
      // Pelanggan lama juga masih ada.
      expect(find.text('Andi Pratama'), findsOneWidget);
    });

    testWidgets('mencari pelanggan berdasarkan nama', (tester) async {
      await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.people_outline));
      await pumpFrames(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cari nama atau nomor telepon'),
        'Andi',
      );
      await pumpFrames(tester);

      expect(find.text('Andi Pratama'), findsOneWidget);
    });

    testWidgets('menampilkan detail pelanggan beserta kendaraannya',
        (tester) async {
      await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.people_outline));
      await pumpFrames(tester);

      await tester.tap(find.text('Andi Pratama'));
      await pumpFrames(tester);

      expect(find.text('Detail Pelanggan'), findsOneWidget);
      expect(find.text('B 1234 ABC'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
    });
  });

  group('Tahap 4 - Transaksi', () {
    testWidgets('membuat transaksi dan transaksi muncul di daftar',
        (tester) async {
      final dependencies = await prepareApp(tester);

      // Pindah ke tab Transaksi.
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      // Tekan tombol transaksi baru.
      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester);

      // Pilih pelanggan.
      await tester.ensureVisible(find.text('Pilih pelanggan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Pilih pelanggan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Andi Pratama').last);
      await pumpFrames(tester, times: 12);

      // Pilih kendaraan.
      await tester.ensureVisible(find.text('Pilih kendaraan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Pilih kendaraan'));
      await pumpFrames(tester);
      await tester.tap(find.text('B 1234 ABC').last);
      await pumpFrames(tester, times: 12);

      // Pilih layanan.
      await tester.ensureVisible(find.text('Pilih Layanan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Pilih Layanan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Ganti Oli').last);
      await pumpFrames(tester);
      await tester.tap(find.textContaining('Simpan Pilihan'));
      await pumpFrames(tester, times: 12);

      // Simpan transaksi.
      await scrollTo(tester, find.text('Simpan Transaksi'));
      await tester.tap(find.text('Simpan Transaksi'));
      await pumpFrames(tester, times: 14);

      // Transaksi tersimpan di database.
      final transactions =
          await dependencies.transactions.list(const TransactionFilter());
      expect(transactions.length, 1);
      expect(transactions.first.plateNumber, 'B 1234 ABC');
      expect(transactions.first.workStatus, WorkStatus.menunggu);
      expect(transactions.first.paymentStatus, PaymentStatus.belumDibayar);

      // Dan tampil di daftar transaksi.
      expect(find.text(transactions.first.transactionNumber), findsOneWidget);
    });

    testWidgets('transaksi tidak bisa disimpan tanpa pelanggan',
        (tester) async {
      final dependencies = await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester);

      await scrollTo(tester, find.text('Simpan Transaksi'));
      await tester.tap(find.text('Simpan Transaksi'));
      await pumpFrames(tester);
      expect(find.text('Pilih pelanggan terlebih dahulu'), findsOneWidget);
      final transactions =
          await dependencies.transactions.list(const TransactionFilter());
      expect(transactions, isEmpty);
    });

    testWidgets('katalog layanan dapat dibuka dari menu Transaksi',
        (tester) async {
      await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      await tester.tap(find.byIcon(Icons.local_offer_outlined));
      await pumpFrames(tester);

      expect(find.text('Katalog Layanan'), findsOneWidget);
      expect(find.text('Ganti Oli'), findsOneWidget);
    });

    testWidgets('tombol simpan ditekan dua kali tidak membuat transaksi '
        'ganda', (tester) async {
      final dependencies = await prepareApp(tester);

      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpFrames(tester);

      // Pilih pelanggan & kendaraan.
      await scrollTo(tester, find.text('Pilih pelanggan'));
      await tester.tap(find.text('Pilih pelanggan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Andi Pratama').last);
      await pumpFrames(tester, times: 12);

      await scrollTo(tester, find.text('Pilih kendaraan'));
      await tester.tap(find.text('Pilih kendaraan'));
      await pumpFrames(tester);
      await tester.tap(find.text('B 1234 ABC').last);
      await pumpFrames(tester, times: 12);

      // Pilih layanan.
      await scrollTo(tester, find.text('Pilih Layanan'));
      await tester.tap(find.text('Pilih Layanan'));
      await pumpFrames(tester);
      await tester.tap(find.text('Ganti Oli').last);
      await pumpFrames(tester);
      await tester.tap(find.textContaining('Simpan Pilihan'));
      await pumpFrames(tester, times: 12);

      // Tekan tombol simpan dua kali tanpa menunggu animasi.
      await scrollTo(tester, find.text('Simpan Transaksi'));
      final saveButton = find.text('Simpan Transaksi');
      await tester.tap(saveButton);
      await tester.tap(saveButton);
      await pumpFrames(tester, times: 14);

      // Hanya satu transaksi yang boleh tersimpan.
      final transactions =
          await dependencies.transactions.list(const TransactionFilter());
      expect(transactions.length, 1);
    });
  });
}
