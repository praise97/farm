import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class Animal extends Equatable {
  final String id;
  final String farmId;
  final String tagNumber;
  final String? qrCode;
  final String breed;
  final String category;
  final AnimalGender gender;
  final DateTime birthDate;
  final double weight;
  final String? colour;
  final String? photoUrl;
  final String? photo1Url;
  final String? photo2Url;
  final DateTime? photosUpdatedAt;
  final String currentOwner;
  final String? location;
  final AnimalStatus status;
  final DateTime updatedAt;
  final DateTime createdAt;

  const Animal({
    required this.id,
    required this.farmId,
    required this.tagNumber,
    this.qrCode,
    required this.breed,
    required this.category,
    required this.gender,
    required this.birthDate,
    required this.weight,
    this.colour,
    this.photoUrl,
    this.photo1Url,
    this.photo2Url,
    this.photosUpdatedAt,
    required this.currentOwner,
    this.location,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });

  int get ageYears {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  String get ageLabel {
    final now = DateTime.now();
    final months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (months < 12) return '$months mo';
    final y = months ~/ 12;
    final m = months % 12;
    return m == 0 ? '$y yr' : '$y yr $m mo';
  }

  bool get needsPhotoRefresh {
    if (status == AnimalStatus.dead || status == AnimalStatus.sold) return false;
    if (photosUpdatedAt == null) return true;
    return DateTime.now().difference(photosUpdatedAt!).inDays >= 365;
  }

  bool get isTerminal => status == AnimalStatus.dead || status == AnimalStatus.sold;

  Animal copyWith({
    String? tagNumber,
    String? qrCode,
    String? breed,
    String? category,
    AnimalGender? gender,
    DateTime? birthDate,
    double? weight,
    String? colour,
    String? photoUrl,
    String? photo1Url,
    String? photo2Url,
    DateTime? photosUpdatedAt,
    bool clearPhoto1 = false,
    bool clearPhoto2 = false,
    bool clearPhotosUpdatedAt = false,
    String? currentOwner,
    String? location,
    AnimalStatus? status,
    DateTime? updatedAt,
  }) {
    return Animal(
      id: id,
      farmId: farmId,
      tagNumber: tagNumber ?? this.tagNumber,
      qrCode: qrCode ?? this.qrCode,
      breed: breed ?? this.breed,
      category: category ?? this.category,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      colour: colour ?? this.colour,
      photoUrl: photoUrl ?? this.photoUrl,
      photo1Url: clearPhoto1 ? null : (photo1Url ?? this.photo1Url),
      photo2Url: clearPhoto2 ? null : (photo2Url ?? this.photo2Url),
      photosUpdatedAt:
          clearPhotosUpdatedAt ? null : (photosUpdatedAt ?? this.photosUpdatedAt),
      currentOwner: currentOwner ?? this.currentOwner,
      location: location ?? this.location,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'tagNumber': tagNumber,
        'qrCode': qrCode,
        'breed': breed,
        'category': category,
        'gender': gender.name,
        'birthDate': birthDate.toIso8601String(),
        'weight': weight,
        'colour': colour,
        'photoUrl': photoUrl ?? photo1Url,
        'photo1Url': photo1Url,
        'photo2Url': photo2Url,
        'photosUpdatedAt': photosUpdatedAt?.toIso8601String(),
        'currentOwner': currentOwner,
        'location': location,
        'status': status.name,
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Animal.fromMap(Map<String, dynamic> map) => Animal(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        tagNumber: map['tagNumber'] as String,
        qrCode: map['qrCode'] as String?,
        breed: map['breed'] as String,
        category: map['category'] as String,
        gender: AnimalGender.values.byName(map['gender'] as String),
        birthDate: DateTime.parse(map['birthDate'] as String),
        weight: (map['weight'] as num).toDouble(),
        colour: map['colour'] as String?,
        photoUrl: map['photoUrl'] as String?,
        photo1Url: map['photo1Url'] as String? ?? map['photoUrl'] as String?,
        photo2Url: map['photo2Url'] as String?,
        photosUpdatedAt: map['photosUpdatedAt'] != null
            ? DateTime.tryParse(map['photosUpdatedAt'] as String)
            : null,
        currentOwner: map['currentOwner'] as String,
        location: map['location'] as String?,
        status: AnimalStatus.values.byName(map['status'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, tagNumber, status, weight];
}

class AnimalTimelineEvent extends Equatable {
  final String id;
  final String animalId;
  final String farmId;
  final TimelineEventType type;
  final String title;
  final String? notes;
  final DateTime date;
  final Map<String, dynamic> meta;
  final double? cost;

  const AnimalTimelineEvent({
    required this.id,
    required this.animalId,
    required this.farmId,
    required this.type,
    required this.title,
    this.notes,
    required this.date,
    this.meta = const {},
    this.cost,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'farmId': farmId,
        'type': type.name,
        'title': title,
        'notes': notes,
        'date': date.toIso8601String(),
        'meta': meta,
        'cost': cost,
      };

  factory AnimalTimelineEvent.fromMap(Map<String, dynamic> map) =>
      AnimalTimelineEvent(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        farmId: map['farmId'] as String,
        type: TimelineEventType.values.byName(map['type'] as String),
        title: map['title'] as String,
        notes: map['notes'] as String?,
        date: DateTime.parse(map['date'] as String),
        meta: Map<String, dynamic>.from(map['meta'] as Map? ?? {}),
        cost: (map['cost'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [id, animalId, type, date];
}

class VaccinationRecord extends Equatable {
  final String id;
  final String animalId;
  final String farmId;
  final String vaccine;
  final DateTime date;
  final DateTime? nextDueDate;
  final String? veterinarian;
  final String? notes;

  const VaccinationRecord({
    required this.id,
    required this.animalId,
    required this.farmId,
    required this.vaccine,
    required this.date,
    this.nextDueDate,
    this.veterinarian,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'farmId': farmId,
        'vaccine': vaccine,
        'date': date.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'veterinarian': veterinarian,
        'notes': notes,
      };

  factory VaccinationRecord.fromMap(Map<String, dynamic> map) =>
      VaccinationRecord(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        farmId: map['farmId'] as String,
        vaccine: map['vaccine'] as String,
        date: DateTime.parse(map['date'] as String),
        nextDueDate: map['nextDueDate'] != null
            ? DateTime.parse(map['nextDueDate'] as String)
            : null,
        veterinarian: map['veterinarian'] as String?,
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, animalId, vaccine, date];
}
