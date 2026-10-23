
import '../../core/app_dependencies.dart';
import '../local/database_schema.dart';
import '../models/enums.dart';
import '../models/transaction_draft.dart';

/// Alat bantu untuk mengisi data contoh saat pengujian aplikasi.
///
/// Data contoh ini sengaja dibuat manual (bukan otomatis saat aplikasi
/// dibuka) agar laporan dan Dashboard tetap menampilkan data yang benar
/// sesuai transaksi yang benar-benar dicatat pengguna.
class DevSeedService {
  DevSeedService(this.dependencies);

  final AppDependencies dependencies;

  /// Mengisi pelanggan, kendaraan, sparepart, dan dua transaksi contoh.
  Future<String> seedSampleData() async {
    final customerAndi = await dependencies.customers.create(
      name: 'Andi Pratama',
      phone: '081234567890',
      address: 'Jl. Merdeka No. 12, Bandung',
    );
    final customerSiti = await dependencies.customers.create(
      name: 'Siti Nurhaliza',
      phone: '081298765432',
      address: 'Jl. Sudirman No. 45, Bandung',
    );
    final customerBudi = await dependencies.customers.create(
      name: 'Budi Santoso',
      phone: '082112233445',
      address: 'Jl. Ahmad Yani No. 8, Bandung',
    );

    final beat = await dependencies.vehicles.create(
      customerId: customerAndi.id!,
      plateNumber: 'B 1234 ABC',
      brand: 'Honda',
      model: 'Beat',
    );
    final mio = await dependencies.vehicles.create(
      customerId: customerSiti.id!,
      plateNumber: 'D 5678 EYZ',
      brand: 'Yamaha',
      model: 'Mio',
    );
    await dependencies.vehicles.create(
      customerId: customerBudi.id!,
      plateNumber: 'B 9012 XYZ',
      brand: 'Honda',
      model: 'Vario',
    );

    final oli = await dependencies.parts.create(
      name: 'Oli Mesin 1 Liter',
      code: 'OLI-001',
      category: 'Oli & Pelumas',
      purchasePrice: 45000,
      sellPrice: 55000,
      stock: 12,
      minStock: 5,
      unit: 'botol',
    );
    final kampas = await dependencies.parts.create(
      name: 'Kampas Rem Honda Beat',
      code: 'KMP-002',
      category: 'Rem',
      purchasePrice: 35000,
      sellPrice: 45000,
      stock: 3,
      minStock: 5,
      unit: 'set',
    );
    await dependencies.parts.create(
      name: 'Filter Oli',
      code: 'FLT-003',
      category: 'Filter',
      purchasePrice: 12000,
      sellPrice: 18000,
      stock: 20,
      minStock: 5,
      unit: 'pcs',
    );
    await dependencies.parts.create(
      name: 'Busi Iridium',
      code: 'BUS-004',
      category: 'Kelistrikan',
      purchasePrice: 15000,
      sellPrice: 25000,
      stock: 2,
      minStock: 4,
      unit: 'pcs',
    );

    final services = await dependencies.services.list(activeOnly: true);
    int? serviceId(String name) {
      for (final service in services) {
        if (service.name.toLowerCase().contains(name.toLowerCase())) {
          return service.id;
        }
      }
      return null;
    }

    // Transaksi 1: sedang dikerjakan, belum dibayar.
    final transaction1 = await dependencies.transactions.createTransaction(
      TransactionDraft(
        customerId: customerAndi.id!,
        vehicleId: beat.id!,
        complaint: 'Oli sudah encok dan mesin terasa berat',
        mechanicNotes: 'Ganti oli, cek filter udara',
        services: [
          ServiceSelection(serviceId: serviceId('Ganti Oli') ?? 1, qty: 1),
        ],
        parts: [
          PartSelection(partId: oli.id!, qty: 1),
        ],
      ),
    );
    await dependencies.transactions.updateWorkStatus(
      transaction1.id!,
      WorkStatus.dikerjakan,
    );

    // Transaksi 2: selesai dan sudah lunas (tunai).
    final transaction2 = await dependencies.transactions.createTransaction(
      TransactionDraft(
        customerId: customerSiti.id!,
        vehicleId: mio.id!,
        complaint: 'Rem belakang blong',
        mechanicNotes: 'Ganti kampas rem, setel tension',
        services: [
          ServiceSelection(serviceId: serviceId('Kampas Rem') ?? 4, qty: 1),
        ],
        parts: [
          PartSelection(partId: kampas.id!, qty: 2),
        ],
      ),
    );
    await dependencies.transactions.updateWorkStatus(
      transaction2.id!,
      WorkStatus.selesai,
    );
    await dependencies.payments.addPayment(
      transactionId: transaction2.id!,
      amount: transaction2.grandTotal,
      method: PaymentMethod.tunai,
      note: 'Dibayar langsung di bengkel',
    );

    return '3 pelanggan, 3 kendaraan, 4 sparepart, dan 2 transaksi contoh '
        'berhasil ditambahkan.';
  }

  /// Menghapus seluruh data operasional (katalog layanan tetap disimpan).
  Future<void> clearAllData() async {
    final db = await dependencies.database.database;
    await db.transaction<void>((txn) async {
      await txn.delete(DatabaseSchema.tableTransactionServices);
      await txn.delete(DatabaseSchema.tableTransactionParts);
      await txn.delete(DatabaseSchema.tablePayments);
      await txn.delete(DatabaseSchema.tableStockMovements);
      await txn.delete(DatabaseSchema.tableTransactions);
      await txn.delete(DatabaseSchema.tableVehicles);
      await txn.delete(DatabaseSchema.tableCustomers);
      await txn.delete(DatabaseSchema.tableParts);

      // Mengulang penomoran otomatis agar data baru mulai dari angka 1.
      for (final table in [
        DatabaseSchema.tableTransactions,
        DatabaseSchema.tableTransactionServices,
        DatabaseSchema.tableTransactionParts,
        DatabaseSchema.tablePayments,
        DatabaseSchema.tableStockMovements,
        DatabaseSchema.tableVehicles,
        DatabaseSchema.tableCustomers,
        DatabaseSchema.tableParts,
      ]) {
        await txn.rawDelete(
          "DELETE FROM sqlite_sequence WHERE name = ?",
          [table],
        );
      }
    });
  }
}
