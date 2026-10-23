import 'package:dr4ox_motor/core/utils/date_times.dart';

/// Data kendaraan milik pelanggan.

class Vehicle {
  const Vehicle({
    this.id,
    required this.customerId,
    required this.plateNumber,
    this.brand = '',
    this.model = '',
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
    this.isArchived = false,
  });

  final int? id;

  /// Id pelanggan pemilik kendaraan.
  final int customerId;

  /// Nomor polisi, selalu disimpan dalam format kapital.
  final String plateNumber;
  final String brand;
  final String model;
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isArchived;

  Vehicle copyWith({
    int? id,
    int? customerId,
    String? plateNumber,
    String? brand,
    String? model,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Vehicle(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      plateNumber: plateNumber ?? this.plateNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'plate_number': plateNumber,
      'brand': brand,
      'model': model,
      'notes': notes,
      'created_at': DateTimes.toIso(createdAt),
      'updated_at': updatedAt == null ? null : DateTimes.toIso(updatedAt!),
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Vehicle.fromMap(Map<String, Object?> map) {
    return Vehicle(
      id: map['id'] as int?,
      customerId: (map['customer_id'] as int?) ?? 0,
      plateNumber: (map['plate_number'] as String?) ?? '',
      brand: (map['brand'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
    );
  }

  /// Nama tampilan kendaraan, contoh: `B 1234 ABC - Honda Beat`.
  String get displayName {
    final detail = [brand, model].where((e) => e.isNotEmpty).join(' ');
    if (detail.isEmpty) return plateNumber;
    return '$plateNumber - $detail';
  }
}
