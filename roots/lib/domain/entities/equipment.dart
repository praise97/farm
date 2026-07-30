import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class EquipmentItem extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final EquipmentCategory category;
  final DateTime purchaseDate;
  final double purchasePrice;
  final String? supplier;
  final EquipmentCondition condition;
  final String? currentLocation;
  final String? photoUrl;
  final String? serialNumber;
  final DateTime? warrantyUntil;
  final int serviceIntervalDays;
  final DateTime? lastServiceDate;
  final DateTime? nextServiceDate;
  final DateTime createdAt;

  const EquipmentItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.purchaseDate,
    required this.purchasePrice,
    this.supplier,
    required this.condition,
    this.currentLocation,
    this.photoUrl,
    this.serialNumber,
    this.warrantyUntil,
    this.serviceIntervalDays = 90,
    this.lastServiceDate,
    this.nextServiceDate,
    required this.createdAt,
  });

  bool get serviceDue {
    if (nextServiceDate == null) return false;
    return !nextServiceDate!.isAfter(DateTime.now());
  }

  EquipmentItem copyWith({
    String? name,
    EquipmentCategory? category,
    EquipmentCondition? condition,
    String? currentLocation,
    String? photoUrl,
    String? serialNumber,
    DateTime? warrantyUntil,
    int? serviceIntervalDays,
    DateTime? lastServiceDate,
    DateTime? nextServiceDate,
    double? purchasePrice,
    String? supplier,
  }) {
    return EquipmentItem(
      id: id,
      farmId: farmId,
      name: name ?? this.name,
      category: category ?? this.category,
      purchaseDate: purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      supplier: supplier ?? this.supplier,
      condition: condition ?? this.condition,
      currentLocation: currentLocation ?? this.currentLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      serialNumber: serialNumber ?? this.serialNumber,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      serviceIntervalDays: serviceIntervalDays ?? this.serviceIntervalDays,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'category': category.name,
        'purchaseDate': purchaseDate.toIso8601String(),
        'purchasePrice': purchasePrice,
        'supplier': supplier,
        'condition': condition.name,
        'currentLocation': currentLocation,
        'photoUrl': photoUrl,
        'serialNumber': serialNumber,
        'warrantyUntil': warrantyUntil?.toIso8601String(),
        'serviceIntervalDays': serviceIntervalDays,
        'lastServiceDate': lastServiceDate?.toIso8601String(),
        'nextServiceDate': nextServiceDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory EquipmentItem.fromMap(Map<String, dynamic> map) => EquipmentItem(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        name: map['name'] as String,
        category: EquipmentCategory.values.byName(map['category'] as String),
        purchaseDate: DateTime.parse(map['purchaseDate'] as String),
        purchasePrice: (map['purchasePrice'] as num).toDouble(),
        supplier: map['supplier'] as String?,
        condition: EquipmentCondition.values.byName(map['condition'] as String),
        currentLocation: map['currentLocation'] as String?,
        photoUrl: map['photoUrl'] as String?,
        serialNumber: map['serialNumber'] as String?,
        warrantyUntil: map['warrantyUntil'] != null
            ? DateTime.parse(map['warrantyUntil'] as String)
            : null,
        serviceIntervalDays: map['serviceIntervalDays'] as int? ?? 90,
        lastServiceDate: map['lastServiceDate'] != null
            ? DateTime.parse(map['lastServiceDate'] as String)
            : null,
        nextServiceDate: map['nextServiceDate'] != null
            ? DateTime.parse(map['nextServiceDate'] as String)
            : null,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, name, condition];
}

class MaintenanceRecord extends Equatable {
  final String id;
  final String equipmentId;
  final String farmId;
  final DateTime serviceDate;
  final DateTime? nextService;
  final String? workDone;
  final bool oilChange;
  final String? mechanic;
  final double cost;
  final String? notes;

  const MaintenanceRecord({
    required this.id,
    required this.equipmentId,
    required this.farmId,
    required this.serviceDate,
    this.nextService,
    this.workDone,
    this.oilChange = false,
    this.mechanic,
    required this.cost,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'equipmentId': equipmentId,
        'farmId': farmId,
        'serviceDate': serviceDate.toIso8601String(),
        'nextService': nextService?.toIso8601String(),
        'workDone': workDone,
        'oilChange': oilChange,
        'mechanic': mechanic,
        'cost': cost,
        'notes': notes,
      };

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) =>
      MaintenanceRecord(
        id: map['id'] as String,
        equipmentId: map['equipmentId'] as String,
        farmId: map['farmId'] as String,
        serviceDate: DateTime.parse(map['serviceDate'] as String),
        nextService: map['nextService'] != null
            ? DateTime.parse(map['nextService'] as String)
            : null,
        workDone: map['workDone'] as String?,
        oilChange: map['oilChange'] as bool? ?? false,
        mechanic: map['mechanic'] as String?,
        cost: (map['cost'] as num).toDouble(),
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, equipmentId, serviceDate];
}
