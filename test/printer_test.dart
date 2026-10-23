import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dr4ox_motor/core/app_dependencies.dart';
import 'package:dr4ox_motor/data/local/app_database.dart';
import 'package:dr4ox_motor/data/models/enums.dart';
import 'package:dr4ox_motor/data/models/printer_profile.dart';
import 'package:dr4ox_motor/data/models/transaction_draft.dart';
import 'package:dr4ox_motor/data/repositories/receipt_repository.dart';
import 'package:dr4ox_motor/data/services/printing/printer_transport.dart';
import 'package:dr4ox_motor/data/services/printing/receipt_print_service.dart';

/// Transport palsu untuk menguji alur cetak tanpa perangkat bluetooth.
class FakePrinterTransport implements PrinterTransport {
  final List<int> written = [];
  bool ready = true;
  bool failOnWrite = false;
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> connect() async {
    connectCount++;
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (failOnWrite) throw StateError('Koneksi terputus');
    written.addAll(bytes);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late AppDependencies deps;

  setUp(() async {
    await initializeDateFormatting('id_ID', null);
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    deps = AppDependencies(database: database);
    await database.database;
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> buatTransaksi() async {
    final customer = await deps.customers.create(name: 'Andi');
    final vehicle = await deps.vehicles.create(
      customerId: customer.id!,
      plateNumber: 'B 1234 ABC',
    );
    final services = await deps.services.list();
    final transaction = await deps.transactions.createTransaction(
      TransactionDraft(
        customerId: customer.id!,
        vehicleId: vehicle.id!,
        services: [ServiceSelection(serviceId: services.first.id!, qty: 1)],
      ),
    );
    await deps.payments.addPayment(
      transactionId: transaction.id!,
      amount: transaction.grandTotal,
      method: PaymentMethod.tunai,
    );
    return transaction.id!;
  }

  group('Tahap 9 - Pemisahan logika struk & mekanisme cetak', () {
    test('model struk tidak mengimpor PDF maupun apa pun', () {
      // Model data harus bebas dari dependensi apa pun (PDF, printer, UI).
      final source = File('lib/data/models/receipt.dart').readAsStringSync();
      expect(source.contains('import'), isFalse);
    });

    test('repository struk tidak mengimpor PDF maupun printer', () {
      final source =
          File('lib/data/repositories/receipt_repository.dart').readAsStringSync();
      expect(source.contains('package:pdf'), isFalse);
      expect(source.contains('printing/'), isFalse);
      expect(source.contains('receipt_pdf_service'), isFalse);
    });

    test('PDF & ESC/POS memakai sumber data yang sama', () async {
      final transactionId = await buatTransaksi();
      final receipt = await ReceiptRepository(database).build(transactionId);

      // Satu data struk bisa dipakai untuk PDF maupun payload printer.
      final bytes = const EscPosPayloadBuilder().build(receipt!);
      final text = utf8.decode(bytes, allowMalformed: true);
      expect(text, contains('B 1234 ABC'));
      expect(text, contains('Andi'));
    });
  });

  group('Tahap 9 - Titik integrasi printer', () {
    test('lebar kertas menentukan jumlah kolom payload', () {
      const paper58 = PrinterProfile(
        model: 'Test 58',
        paperWidth: PrinterPaperWidth.mm58,
      );
      const paper80 = PrinterProfile(
        model: 'Test 80',
        paperWidth: PrinterPaperWidth.mm80,
      );

      expect(
        EscPosPayloadBuilder.forProfile(paper58).columns,
        32,
      );
      expect(
        EscPosPayloadBuilder.forProfile(paper80).columns,
        42,
      );
    });

    test('payload 80mm lebih lebar dari 58mm (garis pemisah)', () async {
      final transactionId = await buatTransaksi();
      final receipt = await ReceiptRepository(database).build(transactionId);

      final narrow = utf8.decode(
        const EscPosPayloadBuilder(columns: 32).build(receipt!),
        allowMalformed: true,
      );
      final wide = utf8.decode(
        const EscPosPayloadBuilder(columns: 42).build(receipt),
        allowMalformed: true,
      );
      expect(wide.length, greaterThan(narrow.length));
    });

    test('layanan cetak mengirim payload ke transport', () async {
      final transactionId = await buatTransaksi();
      final receipt = await ReceiptRepository(database).build(transactionId);
      final transport = FakePrinterTransport();

      final service = EscPosPrinterService(
        transport: transport,
        profile: const PrinterProfile(
          model: 'Printer Uji',
          paperWidth: PrinterPaperWidth.mm80,
        ),
      );
      final result = await service.print(receipt!);

      expect(result.success, isTrue);
      expect(result.bytesSent, greaterThan(100));
      expect(transport.written.length, result.bytesSent);
      expect(transport.connectCount, 1);
      expect(transport.disconnectCount, 1);
    });

    test('printer tidak terhubung -> gagal dengan pesan jujur', () async {
      final transactionId = await buatTransaksi();
      final receipt = await ReceiptRepository(database).build(transactionId);
      final transport = FakePrinterTransport()..ready = false;

      final service = EscPosPrinterService(
        transport: transport,
        profile: const PrinterProfile(model: 'Printer Uji'),
      );
      final result = await service.print(receipt!);

      expect(result.success, isFalse);
      expect(result.message, contains('belum terhubung'));
      expect(transport.written, isEmpty);
    });

    test('kesalahan koneksi tidak diklaim berhasil', () async {
      final transactionId = await buatTransaksi();
      final receipt = await ReceiptRepository(database).build(transactionId);
      final transport = FakePrinterTransport()..failOnWrite = true;

      final service = EscPosPrinterService(
        transport: transport,
        profile: const PrinterProfile(model: 'Printer Uji'),
      );
      final result = await service.print(receipt!);

      expect(result.success, isFalse);
      expect(result.message, contains('Gagal mencetak'));
    });

    test('transport bawaan selalu belum tersedia', () async {
      const transport = UnavailablePrinterTransport();
      expect(await transport.isReady(), isFalse);
      await expectLater(
        transport.connect(),
        throwsA(isA<StateError>()),
      );
    });

    test('profil printer tersimpan & dimuat kembali', () async {
      const profile = PrinterProfile(
        name: 'Printer meja',
        model: 'RPP-02A',
        paperWidth: PrinterPaperWidth.mm58,
        protocol: PrinterProtocol.escPos,
        notes: 'MAC 00:11:22',
      );
      await deps.settings.savePrinterProfile(profile);

      final loaded = await deps.settings.loadPrinterProfile();
      expect(loaded.name, 'Printer meja');
      expect(loaded.model, 'RPP-02A');
      expect(loaded.paperWidth, PrinterPaperWidth.mm58);
      expect(loaded.protocol, PrinterProtocol.escPos);
      expect(loaded.notes, 'MAC 00:11:22');
      expect(loaded.isConfigured, isTrue);
      expect(loaded.summary, contains('58 mm'));
    });

    test('aplikasi tidak meminta izin printer dari Android', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      // Tidak ada izin Bluetooth/disimpan yang belum diperlukan.
      expect(manifest.contains('BLUETOOTH'), isFalse);
      expect(manifest.contains('WRITE_EXTERNAL_STORAGE'), isFalse);
    });
  });
}
