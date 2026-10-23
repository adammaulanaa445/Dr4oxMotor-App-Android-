import 'package:dr4ox_motor/core/utils/date_times.dart';

/// Katalog layanan servis yang bisa dipilih saat membuat transaksi.

class ServiceItem {
  const ServiceItem({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String description;

  /// Harga layanan (rupiah). Saat transaksi dibuat, harga ini disalin
  /// ke item transaksi sehingga perubahan harga tidak memengaruhi transaksi lama.
  final int price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ServiceItem copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTimes.toIso(createdAt),
      'updated_at': updatedAt == null ? null : DateTimes.toIso(updatedAt!),
    };
  }

  factory ServiceItem.fromMap(Map<String, Object?> map) {
    return ServiceItem(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      price: (map['price'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
    );
  }
}
