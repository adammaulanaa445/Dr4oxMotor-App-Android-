import 'package:dr4ox_motor/core/utils/date_times.dart';

/// Data pelanggan bengkel.

class Customer {
  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    required this.createdAt,
    this.updatedAt,
    this.isArchived = false,
  });

  final int? id;
  final String name;
  final String phone;
  final String address;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Pelanggan diarsipkan (sudah tidak aktif) tetapi riwayat transaksinya disimpan.
  final bool isArchived;

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'created_at': DateTimes.toIso(createdAt),
      'updated_at': updatedAt == null ? null : DateTimes.toIso(updatedAt!),
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
    );
  }
}
