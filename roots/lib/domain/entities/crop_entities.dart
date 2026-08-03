import 'package:equatable/equatable.dart';

/// Crop catalog entry (partner schema: crops table → Firestore).
class CropCatalogItem extends Equatable {
  final String id;
  final String farmId;
  final String cropName;
  final String cropGroup;
  final int daysToMaturity;
  final String? optimalSeason;
  final double? marketPriceUsd;
  final String? useCategory;

  const CropCatalogItem({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.cropGroup,
    required this.daysToMaturity,
    this.optimalSeason,
    this.marketPriceUsd,
    this.useCategory,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'cropName': cropName,
        'cropGroup': cropGroup,
        'daysToMaturity': daysToMaturity,
        'optimalSeason': optimalSeason,
        'marketPriceUsd': marketPriceUsd,
        'useCategory': useCategory,
      };

  factory CropCatalogItem.fromMap(Map<String, dynamic> map) => CropCatalogItem(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        cropName: map['cropName'] as String,
        cropGroup: map['cropGroup'] as String? ?? 'Other',
        daysToMaturity: (map['daysToMaturity'] as num?)?.toInt() ?? 90,
        optimalSeason: map['optimalSeason'] as String?,
        marketPriceUsd: (map['marketPriceUsd'] as num?)?.toDouble(),
        useCategory: map['useCategory'] as String?,
      );

  @override
  List<Object?> get props => [id, cropName];
}

class CropVariety extends Equatable {
  final String id;
  final String farmId;
  final String cropId;
  final String varietyName;
  final String? seedSource;
  final int? daysToMaturity;

  const CropVariety({
    required this.id,
    required this.farmId,
    required this.cropId,
    required this.varietyName,
    this.seedSource,
    this.daysToMaturity,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'cropId': cropId,
        'varietyName': varietyName,
        'seedSource': seedSource,
        'daysToMaturity': daysToMaturity,
      };

  factory CropVariety.fromMap(Map<String, dynamic> map) => CropVariety(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        cropId: map['cropId'] as String,
        varietyName: map['varietyName'] as String,
        seedSource: map['seedSource'] as String?,
        daysToMaturity: (map['daysToMaturity'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, varietyName];
}

class FarmField extends Equatable {
  final String id;
  final String farmId;
  final String fieldName;
  final double sizeHa;
  final String? soilType;
  final double? gpsLat;
  final double? gpsLon;
  final int? elevationM;
  final String? climateZone;

  const FarmField({
    required this.id,
    required this.farmId,
    required this.fieldName,
    required this.sizeHa,
    this.soilType,
    this.gpsLat,
    this.gpsLon,
    this.elevationM,
    this.climateZone,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'fieldName': fieldName,
        'sizeHa': sizeHa,
        'soilType': soilType,
        'gpsLat': gpsLat,
        'gpsLon': gpsLon,
        'elevationM': elevationM,
        'climateZone': climateZone,
      };

  factory FarmField.fromMap(Map<String, dynamic> map) => FarmField(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        fieldName: map['fieldName'] as String,
        sizeHa: (map['sizeHa'] as num).toDouble(),
        soilType: map['soilType'] as String?,
        gpsLat: (map['gpsLat'] as num?)?.toDouble(),
        gpsLon: (map['gpsLon'] as num?)?.toDouble(),
        elevationM: (map['elevationM'] as num?)?.toInt(),
        climateZone: map['climateZone'] as String?,
      );

  @override
  List<Object?> get props => [id, fieldName];
}

/// Planting / active crop plot (maps partner plantings + active_crops view).
class CropPlot extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final String cropType;
  final String? fieldId;
  final String? fieldName;
  final String? varietyId;
  final String? varietyName;
  final double growthPercent;
  final double? soilMoisture;
  final String statusNote;
  final String growthStage;
  final DateTime plantedAt;
  final DateTime? expectedHarvest;
  final DateTime? harvestDate;
  final int? daysToMaturity;
  final int? plantingDensity;
  final bool pestPresence;
  final bool diseasePresence;

  const CropPlot({
    required this.id,
    required this.farmId,
    required this.name,
    required this.cropType,
    this.fieldId,
    this.fieldName,
    this.varietyId,
    this.varietyName,
    required this.growthPercent,
    this.soilMoisture,
    required this.statusNote,
    this.growthStage = 'Vegetative',
    required this.plantedAt,
    this.expectedHarvest,
    this.harvestDate,
    this.daysToMaturity,
    this.plantingDensity,
    this.pestPresence = false,
    this.diseasePresence = false,
  });

  bool get isActive => harvestDate == null;

  int get daysSincePlanting => DateTime.now().difference(plantedAt).inDays;

  static String stageFor(int days, int maturity) {
    if (maturity <= 0) return 'Unknown';
    final r = days / maturity;
    if (r < 0.10) return 'Germination';
    if (r < 0.30) return 'Vegetative';
    if (r < 0.60) return 'Flowering';
    if (r < 0.85) return 'Fruiting/Grain fill';
    if (r < 1.0) return 'Maturation';
    return 'Harvest ready';
  }

  static double growthFor(int days, int maturity) {
    if (maturity <= 0) return 0;
    final g = (days / maturity) * 100;
    return g.clamp(0, 100).toDouble();
  }

  CropPlot copyWith({
    String? name,
    String? cropType,
    String? fieldId,
    String? fieldName,
    String? varietyId,
    String? varietyName,
    double? growthPercent,
    double? soilMoisture,
    String? statusNote,
    String? growthStage,
    DateTime? expectedHarvest,
    DateTime? harvestDate,
    int? daysToMaturity,
    int? plantingDensity,
    bool? pestPresence,
    bool? diseasePresence,
  }) {
    return CropPlot(
      id: id,
      farmId: farmId,
      name: name ?? this.name,
      cropType: cropType ?? this.cropType,
      fieldId: fieldId ?? this.fieldId,
      fieldName: fieldName ?? this.fieldName,
      varietyId: varietyId ?? this.varietyId,
      varietyName: varietyName ?? this.varietyName,
      growthPercent: growthPercent ?? this.growthPercent,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      statusNote: statusNote ?? this.statusNote,
      growthStage: growthStage ?? this.growthStage,
      plantedAt: plantedAt,
      expectedHarvest: expectedHarvest ?? this.expectedHarvest,
      harvestDate: harvestDate ?? this.harvestDate,
      daysToMaturity: daysToMaturity ?? this.daysToMaturity,
      plantingDensity: plantingDensity ?? this.plantingDensity,
      pestPresence: pestPresence ?? this.pestPresence,
      diseasePresence: diseasePresence ?? this.diseasePresence,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'cropType': cropType,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'varietyId': varietyId,
        'varietyName': varietyName,
        'growthPercent': growthPercent,
        'soilMoisture': soilMoisture,
        'statusNote': statusNote,
        'growthStage': growthStage,
        'plantedAt': plantedAt.toIso8601String(),
        'expectedHarvest': expectedHarvest?.toIso8601String(),
        'harvestDate': harvestDate?.toIso8601String(),
        'daysToMaturity': daysToMaturity,
        'plantingDensity': plantingDensity,
        'pestPresence': pestPresence,
        'diseasePresence': diseasePresence,
      };

  factory CropPlot.fromMap(Map<String, dynamic> map) => CropPlot(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        name: map['name'] as String,
        cropType: map['cropType'] as String,
        fieldId: map['fieldId'] as String?,
        fieldName: map['fieldName'] as String?,
        varietyId: map['varietyId'] as String?,
        varietyName: map['varietyName'] as String?,
        growthPercent: (map['growthPercent'] as num).toDouble(),
        soilMoisture: (map['soilMoisture'] as num?)?.toDouble(),
        statusNote: map['statusNote'] as String? ?? '',
        growthStage: map['growthStage'] as String? ?? 'Vegetative',
        plantedAt: DateTime.parse(map['plantedAt'] as String),
        expectedHarvest: map['expectedHarvest'] != null
            ? DateTime.parse(map['expectedHarvest'] as String)
            : null,
        harvestDate: map['harvestDate'] != null
            ? DateTime.parse(map['harvestDate'] as String)
            : null,
        daysToMaturity: (map['daysToMaturity'] as num?)?.toInt(),
        plantingDensity: (map['plantingDensity'] as num?)?.toInt(),
        pestPresence: map['pestPresence'] as bool? ?? false,
        diseasePresence: map['diseasePresence'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, name, growthPercent, soilMoisture];
}

enum TreatmentType { fertilizer, pesticide, herbicide, irrigation }

class CropTreatment extends Equatable {
  final String id;
  final String farmId;
  final String plantingId;
  final TreatmentType treatmentType;
  final String? productName;
  final DateTime applicationDate;
  final double? ratePerHa;
  final double? costUsd;
  final String? notes;

  const CropTreatment({
    required this.id,
    required this.farmId,
    required this.plantingId,
    required this.treatmentType,
    this.productName,
    required this.applicationDate,
    this.ratePerHa,
    this.costUsd,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'plantingId': plantingId,
        'treatmentType': treatmentType.name,
        'productName': productName,
        'applicationDate': applicationDate.toIso8601String(),
        'ratePerHa': ratePerHa,
        'costUsd': costUsd,
        'notes': notes,
      };

  factory CropTreatment.fromMap(Map<String, dynamic> map) => CropTreatment(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        plantingId: map['plantingId'] as String,
        treatmentType: TreatmentType.values.byName(map['treatmentType'] as String),
        productName: map['productName'] as String?,
        applicationDate: DateTime.parse(map['applicationDate'] as String),
        ratePerHa: (map['ratePerHa'] as num?)?.toDouble(),
        costUsd: (map['costUsd'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, plantingId, treatmentType];
}

class CropObservation extends Equatable {
  final String id;
  final String farmId;
  final String plantingId;
  final DateTime observationDate;
  final int? avgPlantHeightCm;
  final int? colorRating;
  final bool pestPresence;
  final bool diseasePresence;
  final String? notes;

  const CropObservation({
    required this.id,
    required this.farmId,
    required this.plantingId,
    required this.observationDate,
    this.avgPlantHeightCm,
    this.colorRating,
    this.pestPresence = false,
    this.diseasePresence = false,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'plantingId': plantingId,
        'observationDate': observationDate.toIso8601String(),
        'avgPlantHeightCm': avgPlantHeightCm,
        'colorRating': colorRating,
        'pestPresence': pestPresence,
        'diseasePresence': diseasePresence,
        'notes': notes,
      };

  factory CropObservation.fromMap(Map<String, dynamic> map) => CropObservation(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        plantingId: map['plantingId'] as String,
        observationDate: DateTime.parse(map['observationDate'] as String),
        avgPlantHeightCm: (map['avgPlantHeightCm'] as num?)?.toInt(),
        colorRating: (map['colorRating'] as num?)?.toInt(),
        pestPresence: map['pestPresence'] as bool? ?? false,
        diseasePresence: map['diseasePresence'] as bool? ?? false,
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, plantingId, observationDate];
}
