import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class FarmUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String farmId;
  final UserRole role;
  final String? photoUrl;
  final DateTime createdAt;

  const FarmUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.farmId,
    required this.role,
    this.photoUrl,
    required this.createdAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  FarmUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? photoUrl,
  }) {
    return FarmUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      farmId: farmId,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'farmId': farmId,
        'role': role.name,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FarmUser.fromMap(Map<String, dynamic> map) => FarmUser(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        phone: map['phone'] as String?,
        farmId: map['farmId'] as String,
        role: UserRole.values.byName(map['role'] as String),
        photoUrl: map['photoUrl'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, email, role, farmId];
}

class Farm extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String? location;
  final DateTime createdAt;

  const Farm({
    required this.id,
    required this.name,
    required this.ownerId,
    this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Farm.fromMap(Map<String, dynamic> map) => Farm(
        id: map['id'] as String,
        name: map['name'] as String,
        ownerId: map['ownerId'] as String,
        location: map['location'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, name, ownerId];
}
