import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class InventoryItem extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final InventoryCategory category;
  final double quantity;
  final String unit;
  final String? supplier;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final double minimumStock;
  final double costPrice;
  final double? sellingPrice;
  final String? barcode;
  final String? storageLocation;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.supplier,
    this.purchaseDate,
    this.expiryDate,
    required this.minimumStock,
    required this.costPrice,
    this.sellingPrice,
    this.barcode,
    this.storageLocation,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= minimumStock;
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isNearExpiry {
    if (expiryDate == null) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 30;
  }

  double get stockValue => quantity * costPrice;

  InventoryItem copyWith({
    String? name,
    InventoryCategory? category,
    double? quantity,
    String? unit,
    String? supplier,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? minimumStock,
    double? costPrice,
    double? sellingPrice,
    String? barcode,
    String? storageLocation,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id,
      farmId: farmId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      minimumStock: minimumStock ?? this.minimumStock,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      barcode: barcode ?? this.barcode,
      storageLocation: storageLocation ?? this.storageLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'supplier': supplier,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'minimumStock': minimumStock,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'barcode': barcode,
        'storageLocation': storageLocation,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        name: map['name'] as String,
        category: InventoryCategory.values.byName(map['category'] as String),
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] as String,
        supplier: map['supplier'] as String?,
        purchaseDate: map['purchaseDate'] != null
            ? DateTime.parse(map['purchaseDate'] as String)
            : null,
        expiryDate: map['expiryDate'] != null
            ? DateTime.parse(map['expiryDate'] as String)
            : null,
        minimumStock: (map['minimumStock'] as num).toDouble(),
        costPrice: (map['costPrice'] as num).toDouble(),
        sellingPrice: (map['sellingPrice'] as num?)?.toDouble(),
        barcode: map['barcode'] as String?,
        storageLocation: map['storageLocation'] as String?,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [id, name, quantity];
}

class FinanceEntry extends Equatable {
  final String id;
  final String farmId;
  final FinanceType type;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final String? relatedId;

  const FinanceEntry({
    required this.id,
    required this.farmId,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.relatedId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'type': type.name,
        'category': category,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'relatedId': relatedId,
      };

  factory FinanceEntry.fromMap(Map<String, dynamic> map) => FinanceEntry(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        type: FinanceType.values.byName(map['type'] as String),
        category: map['category'] as String,
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        relatedId: map['relatedId'] as String?,
      );

  @override
  List<Object?> get props => [id, type, amount, date];
}

class FarmTask extends Equatable {
  final String id;
  final String farmId;
  final String title;
  final String? description;
  final String? assigneeId;
  final String? assigneeName;
  final String? assignedById;
  final String? assignedByName;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? sourceModule;
  final DateTime createdAt;
  final String? workerNotes;
  final String? supervisorNotes;
  final DateTime? completedAt;
  final DateTime? reviewedAt;

  const FarmTask({
    required this.id,
    required this.farmId,
    required this.title,
    this.description,
    this.assigneeId,
    this.assigneeName,
    this.assignedById,
    this.assignedByName,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.sourceModule,
    required this.createdAt,
    this.workerNotes,
    this.supervisorNotes,
    this.completedAt,
    this.reviewedAt,
  });

  bool get needsSupervisorReview => status == TaskStatus.awaitingReview;

  FarmTask copyWith({
    String? title,
    String? description,
    String? assigneeId,
    String? assigneeName,
    String? assignedById,
    String? assignedByName,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    String? workerNotes,
    String? supervisorNotes,
    DateTime? completedAt,
    DateTime? reviewedAt,
  }) {
    return FarmTask(
      id: id,
      farmId: farmId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      assignedById: assignedById ?? this.assignedById,
      assignedByName: assignedByName ?? this.assignedByName,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      sourceModule: sourceModule,
      createdAt: createdAt,
      workerNotes: workerNotes ?? this.workerNotes,
      supervisorNotes: supervisorNotes ?? this.supervisorNotes,
      completedAt: completedAt ?? this.completedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'title': title,
        'description': description,
        'assigneeId': assigneeId,
        'assigneeName': assigneeName,
        'assignedById': assignedById,
        'assignedByName': assignedByName,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority.name,
        'status': status.name,
        'sourceModule': sourceModule,
        'createdAt': createdAt.toIso8601String(),
        'workerNotes': workerNotes,
        'supervisorNotes': supervisorNotes,
        'completedAt': completedAt?.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory FarmTask.fromMap(Map<String, dynamic> map) => FarmTask(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        assigneeId: map['assigneeId'] as String?,
        assigneeName: map['assigneeName'] as String?,
        assignedById: map['assignedById'] as String?,
        assignedByName: map['assignedByName'] as String?,
        dueDate: DateTime.parse(map['dueDate'] as String),
        priority: TaskPriority.values.byName(map['priority'] as String),
        status: TaskStatus.values.byName(map['status'] as String),
        sourceModule: map['sourceModule'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        workerNotes: map['workerNotes'] as String?,
        supervisorNotes: map['supervisorNotes'] as String?,
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'] as String)
            : null,
        reviewedAt: map['reviewedAt'] != null
            ? DateTime.tryParse(map['reviewedAt'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, title, status, dueDate, assigneeId];
}

class FarmAlert extends Equatable {
  final String id;
  final String farmId;
  final AlertType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;
  final String? relatedId;
  final String? targetUserId;

  const FarmAlert({
    required this.id,
    required this.farmId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.relatedId,
    this.targetUserId,
  });

  FarmAlert copyWith({bool? read}) => FarmAlert(
        id: id,
        farmId: farmId,
        type: type,
        title: title,
        message: message,
        createdAt: createdAt,
        read: read ?? this.read,
        relatedId: relatedId,
        targetUserId: targetUserId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'type': type.name,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
        'relatedId': relatedId,
        'targetUserId': targetUserId,
      };

  factory FarmAlert.fromMap(Map<String, dynamic> map) => FarmAlert(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        type: AlertType.values.byName(map['type'] as String),
        title: map['title'] as String,
        message: map['message'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        read: map['read'] as bool? ?? false,
        relatedId: map['relatedId'] as String?,
        targetUserId: map['targetUserId'] as String?,
      );

  @override
  List<Object?> get props => [id, type, read, targetUserId];
}

class MapPoint extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final MapPointType type;
  final double latitude;
  final double longitude;
  final String? notes;

  const MapPoint({
    required this.id,
    required this.farmId,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'type': type.name,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
      };

  factory MapPoint.fromMap(Map<String, dynamic> map) => MapPoint(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        name: map['name'] as String,
        type: MapPointType.values.byName(map['type'] as String),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, name, type];
}
