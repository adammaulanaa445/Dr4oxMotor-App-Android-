import 'package:dr4ox_motor/core/utils/date_times.dart';

/// Data sparepart / inventaris bengkel.

class Part {
  const Part({
    this.id,
    required this.name,
    this.code = '',
    this.category = '',
    this.purchasePrice = 0,
    required this.sellPrice,
    this.stock = 0,
    this.minStock = 0,
    this.unit = 'pcs',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String code;
  final String category;

  /// Harga modal (harga beli dari supplier).
  final int purchasePrice;

  /// Harga jual ke pelanggan.
  final int sellPrice;

  /// Jumlah stok tersedia saat ini.
  final int stock;

  /// Batas minimum stok; jika `stock <= minStock` maka muncul peringatan.
  final int minStock;

  /// Satuan barang, contoh: `pcs`, `botol`, `set`.
  final String unit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Part copyWith({
    int? id,
    String? name,
    String? code,
    String? category,
    int? purchasePrice,
    int? sellPrice,
    int? stock,
    int? minStock,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Part(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'category': category,
      'purchase_price': purchasePrice,
      'sell_price': sellPrice,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTimes.toIso(createdAt),
      'updated_at': updatedAt == null ? null : DateTimes.toIso(updatedAt!),
    };
  }

  factory Part.fromMap(Map<String, Object?> map) {
    return Part(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      code: (map['code'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      purchasePrice: (map['purchase_price'] as int?) ?? 0,
      sellPrice: (map['sell_price'] as int?) ?? 0,
      stock: (map['stock'] as int?) ?? 0,
      minStock: (map['min_stock'] as int?) ?? 0,
      unit: (map['unit'] as String?) ?? 'pcs',
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
    );
  }

  /// True bila stok menyentuh atau turun di bawah batas minimum.
  bool get isLowStock => stock <= minStock;
}
