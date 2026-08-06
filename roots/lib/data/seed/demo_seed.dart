import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/offline/local_store.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/crop_entities.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/farm_user.dart';
import '../../domain/entities/shared_entities.dart';

const _uuid = Uuid();

/// Seeds demo farm data so the app works before Firebase is wired.
Future<void> seedDemoData() async {
  final store = LocalStore.instance;
  if (store.seeded) return;

  final now = DateTime.now();
  final farmId = AppConstants.defaultFarmId;

  final farm = Farm(
    id: farmId,
    name: 'Roots Homestead',
    ownerId: 'owner-001',
    location: 'Harare, Zimbabwe',
    createdAt: now.subtract(const Duration(days: 400)),
  );
  await store.putMap(HiveBoxes.farms, farm.id, farm.toMap());

  final owner = FarmUser(
    id: 'owner-001',
    name: 'John Farmer',
    email: AppConstants.demoEmail,
    phone: '+263771234567',
    farmId: farmId,
    role: UserRole.owner,
    createdAt: now.subtract(const Duration(days: 400)),
  );
  final manager = FarmUser(
    id: 'manager-001',
    name: 'Tendai Moyo',
    email: 'manager@roots.app',
    farmId: farmId,
    role: UserRole.manager,
    createdAt: now.subtract(const Duration(days: 200)),
  );
  final worker = FarmUser(
    id: 'worker-001',
    name: 'Chipo Ncube',
    email: 'worker@roots.app',
    farmId: farmId,
    role: UserRole.worker,
    createdAt: now.subtract(const Duration(days: 120)),
  );
  for (final u in [owner, manager, worker]) {
    await store.putMap(HiveBoxes.users, u.id, {
      ...u.toMap(),
      if (u.role != UserRole.owner)
        'localPassword': AppConstants.defaultPasswordForRole(u.role),
    });
  }

  final animals = <Animal>[
    Animal(
      id: 'an-001',
      farmId: farmId,
      tagNumber: 'ZW-CATTLE-4821',
      qrCode: 'ZW-CATTLE-4821',
      breed: 'Mashona',
      category: 'Cattle',
      gender: AnimalGender.female,
      birthDate: DateTime(2021, 3, 12),
      weight: 380,
      colour: 'Brown',
      currentOwner: owner.name,
      location: 'Pen A',
      status: AnimalStatus.pregnant,
      updatedAt: now,
      createdAt: now.subtract(const Duration(days: 900)),
    ),
    Animal(
      id: 'an-002',
      farmId: farmId,
      tagNumber: 'ZW-CATTLE-4822',
      qrCode: 'ZW-CATTLE-4822',
      breed: 'Brahman',
      category: 'Cattle',
      gender: AnimalGender.male,
      birthDate: DateTime(2020, 8, 4),
      weight: 520,
      colour: 'Grey',
      currentOwner: owner.name,
      location: 'Pen B',
      status: AnimalStatus.alive,
      updatedAt: now,
      createdAt: now.subtract(const Duration(days: 1100)),
    ),
    Animal(
      id: 'an-003',
      farmId: farmId,
      tagNumber: 'ZW-GOAT-1102',
      qrCode: 'ZW-GOAT-1102',
      breed: 'Matabele',
      category: 'Goat',
      gender: AnimalGender.female,
      birthDate: DateTime(2023, 1, 20),
      weight: 42,
      colour: 'White',
      currentOwner: owner.name,
      location: 'Goat Shed',
      status: AnimalStatus.sick,
      updatedAt: now,
      createdAt: now.subtract(const Duration(days: 500)),
    ),
    Animal(
      id: 'an-004',
      farmId: farmId,
      tagNumber: 'ZW-CATTLE-4901',
      qrCode: 'ZW-CATTLE-4901',
      breed: 'Tuli',
      category: 'Cattle',
      gender: AnimalGender.female,
      birthDate: DateTime(2022, 6, 15),
      weight: 310,
      colour: 'Red',
      currentOwner: owner.name,
      location: 'Pen A',
      status: AnimalStatus.alive,
      updatedAt: now,
      createdAt: now.subtract(const Duration(days: 700)),
    ),
  ];
  for (final a in animals) {
    await store.putMap(HiveBoxes.animals, a.id, a.toMap());
  }

  final timeline = [
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.born,
      title: 'Born',
      date: DateTime(2021, 3, 12),
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.tagIssued,
      title: 'Tag Issued',
      notes: 'ZW-CATTLE-4821',
      date: DateTime(2021, 3, 20),
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.vaccination,
      title: 'FMD Vaccination',
      notes: 'Dr. Sibanda — annual booster',
      date: now.subtract(const Duration(days: 320)),
      meta: {
        'vaccine': 'FMD',
        // Due this calendar month so dashboard + cow summary show it.
        'nextDue': DateTime(now.year, now.month, now.day > 28 ? 28 : now.day + 2)
            .toIso8601String(),
      },
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-002',
      farmId: farmId,
      type: TimelineEventType.vaccination,
      title: 'Anthrax Vaccination',
      notes: 'Due this month',
      date: now.subtract(const Duration(days: 350)),
      meta: {
        'vaccine': 'Anthrax',
        'nextDue': DateTime(now.year, now.month, 15).toIso8601String(),
      },
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.weightRecord,
      title: 'Weight 340 kg',
      date: now.subtract(const Duration(days: 90)),
      meta: {'weight': 340},
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.weightRecord,
      title: 'Weight 360 kg',
      date: now.subtract(const Duration(days: 45)),
      meta: {'weight': 360},
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.pregnancy,
      title: 'Pregnancy confirmed',
      date: now.subtract(const Duration(days: 90)),
      meta: {'expectedCalving': now.add(const Duration(days: 90)).toIso8601String()},
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-001',
      farmId: farmId,
      type: TimelineEventType.weightRecord,
      title: 'Weight 380 kg',
      date: now.subtract(const Duration(days: 7)),
      meta: {'weight': 380},
    ),
    AnimalTimelineEvent(
      id: _uuid.v4(),
      animalId: 'an-003',
      farmId: farmId,
      type: TimelineEventType.disease,
      title: 'Respiratory infection',
      notes: 'Coughing, reduced appetite',
      date: now.subtract(const Duration(days: 2)),
      cost: 45,
    ),
  ];
  for (final e in timeline) {
    await store.putMap(HiveBoxes.timeline, e.id, e.toMap());
  }

  final equipment = [
    EquipmentItem(
      id: 'eq-001',
      farmId: farmId,
      name: 'John Deere 5075E',
      category: EquipmentCategory.tractor,
      purchaseDate: DateTime(2022, 2, 10),
      purchasePrice: 18500,
      supplier: 'Farmtec Harare',
      condition: EquipmentCondition.good,
      currentLocation: 'Machinery Shed',
      serialNumber: 'JD5075-88921',
      serviceIntervalDays: 90,
      lastServiceDate: now.subtract(const Duration(days: 80)),
      nextServiceDate: now.add(const Duration(days: 10)),
      createdAt: now.subtract(const Duration(days: 800)),
    ),
    EquipmentItem(
      id: 'eq-002',
      farmId: farmId,
      name: 'Boom Sprayer 600L',
      category: EquipmentCategory.boomSprayer,
      purchaseDate: DateTime(2023, 5, 1),
      purchasePrice: 2200,
      condition: EquipmentCondition.excellent,
      currentLocation: 'Machinery Shed',
      serviceIntervalDays: 60,
      nextServiceDate: now.add(const Duration(days: 25)),
      createdAt: now.subtract(const Duration(days: 400)),
    ),
    EquipmentItem(
      id: 'eq-003',
      farmId: farmId,
      name: 'Disc Harrow',
      category: EquipmentCategory.discHarrow,
      purchaseDate: DateTime(2021, 11, 20),
      purchasePrice: 1400,
      condition: EquipmentCondition.fair,
      currentLocation: 'Field Bay',
      nextServiceDate: now.subtract(const Duration(days: 5)),
      createdAt: now.subtract(const Duration(days: 900)),
    ),
  ];
  for (final e in equipment) {
    await store.putMap(HiveBoxes.equipment, e.id, e.toMap());
  }

  final inventory = [
    InventoryItem(
      id: 'inv-001',
      farmId: farmId,
      name: 'Maize Seed SC627',
      category: InventoryCategory.seeds,
      quantity: 12,
      unit: 'bags',
      minimumStock: 5,
      costPrice: 45,
      sellingPrice: 60,
      storageLocation: 'Store Room A',
      expiryDate: now.add(const Duration(days: 180)),
      updatedAt: now,
    ),
    InventoryItem(
      id: 'inv-002',
      farmId: farmId,
      name: 'Cattle Feed Pellets',
      category: InventoryCategory.animalFeed,
      quantity: 8,
      unit: 'bags',
      minimumStock: 10,
      costPrice: 28,
      storageLocation: 'Feed Store',
      updatedAt: now,
    ),
    InventoryItem(
      id: 'inv-003',
      farmId: farmId,
      name: 'Ivermectin',
      category: InventoryCategory.medicine,
      quantity: 3,
      unit: 'bottles',
      minimumStock: 2,
      costPrice: 18,
      expiryDate: now.add(const Duration(days: 20)),
      storageLocation: 'Vet Cabinet',
      updatedAt: now,
    ),
    InventoryItem(
      id: 'inv-004',
      farmId: farmId,
      name: 'Diesel',
      category: InventoryCategory.fuel,
      quantity: 120,
      unit: 'L',
      minimumStock: 50,
      costPrice: 1.45,
      storageLocation: 'Fuel Tank',
      updatedAt: now,
    ),
  ];
  for (final i in inventory) {
    await store.putMap(HiveBoxes.inventory, i.id, i.toMap());
  }

  final finance = [
    FinanceEntry(
      id: _uuid.v4(),
      farmId: farmId,
      type: FinanceType.income,
      category: IncomeCategory.milkSales.name,
      description: 'Weekly milk sales',
      amount: 340,
      date: now.subtract(const Duration(days: 3)),
    ),
    FinanceEntry(
      id: _uuid.v4(),
      farmId: farmId,
      type: FinanceType.income,
      category: IncomeCategory.cropSales.name,
      description: 'Maize sale — local market',
      amount: 1250,
      date: now.subtract(const Duration(days: 12)),
    ),
    FinanceEntry(
      id: _uuid.v4(),
      farmId: farmId,
      type: FinanceType.expense,
      category: ExpenseCategory.feed.name,
      description: 'Cattle feed restock',
      amount: 224,
      date: now.subtract(const Duration(days: 5)),
    ),
    FinanceEntry(
      id: _uuid.v4(),
      farmId: farmId,
      type: FinanceType.expense,
      category: ExpenseCategory.veterinary.name,
      description: 'Goat treatment',
      amount: 45,
      date: now.subtract(const Duration(days: 2)),
    ),
    FinanceEntry(
      id: _uuid.v4(),
      farmId: farmId,
      type: FinanceType.expense,
      category: ExpenseCategory.fuel.name,
      description: 'Tractor diesel',
      amount: 174,
      date: now.subtract(const Duration(days: 8)),
    ),
  ];
  for (final f in finance) {
    await store.putMap(HiveBoxes.finance, f.id, f.toMap());
  }

  final catalog = [
    CropCatalogItem(id: 'cat-maize', farmId: farmId, cropName: 'Maize', cropGroup: 'Cereal', daysToMaturity: 120, optimalSeason: 'Summer', marketPriceUsd: 385, useCategory: 'Grain'),
    CropCatalogItem(id: 'cat-tobacco', farmId: farmId, cropName: 'Tobacco', cropGroup: 'Cash', daysToMaturity: 90, optimalSeason: 'Summer', marketPriceUsd: 4250, useCategory: 'Leaf'),
    CropCatalogItem(id: 'cat-cotton', farmId: farmId, cropName: 'Cotton', cropGroup: 'Fibre', daysToMaturity: 150, optimalSeason: 'Summer', marketPriceUsd: 1020, useCategory: 'Fibre'),
    CropCatalogItem(id: 'cat-tomatoes', farmId: farmId, cropName: 'Tomatoes', cropGroup: 'Vegetable', daysToMaturity: 80, optimalSeason: 'All', marketPriceUsd: 520, useCategory: 'Fresh'),
  ];
  for (final c in catalog) {
    await store.putMap(HiveBoxes.cropCatalog, c.id, c.toMap());
  }

  final varieties = [
    CropVariety(id: 'var-sc403', farmId: farmId, cropId: 'cat-maize', varietyName: 'SC 403', seedSource: 'SeedCo', daysToMaturity: 115),
    CropVariety(id: 'var-sc513', farmId: farmId, cropId: 'cat-maize', varietyName: 'SC 513', seedSource: 'SeedCo', daysToMaturity: 125),
    CropVariety(id: 'var-kutsaga', farmId: farmId, cropId: 'cat-tobacco', varietyName: 'Kutsaga', seedSource: 'Tobacco Research Board', daysToMaturity: 88),
    CropVariety(id: 'var-heinz', farmId: farmId, cropId: 'cat-tomatoes', varietyName: 'Heinz', seedSource: 'SeedCo', daysToMaturity: 75),
  ];
  for (final v in varieties) {
    await store.putMap(HiveBoxes.varieties, v.id, v.toMap());
  }

  final fields = [
    FarmField(id: 'field-a', farmId: farmId, fieldName: 'Field A', sizeHa: 5.2, soilType: 'Sandy Loam', gpsLat: -17.824858, gpsLon: 31.053028, elevationM: 1450, climateZone: 'Subtropical'),
    FarmField(id: 'field-b', farmId: farmId, fieldName: 'Field B', sizeHa: 3.8, soilType: 'Clay', gpsLat: -17.830000, gpsLon: 31.060000, elevationM: 1400, climateZone: 'Subtropical'),
    FarmField(id: 'field-gh1', farmId: farmId, fieldName: 'Greenhouse 1', sizeHa: 0.5, soilType: 'Loam', gpsLat: -17.820000, gpsLon: 31.055000, elevationM: 1450, climateZone: 'Controlled'),
  ];
  for (final f in fields) {
    await store.putMap(HiveBoxes.fields, f.id, f.toMap());
  }

  final plantedA = DateTime(2026, 6, 1);
  final plantedB = DateTime(2026, 6, 15);
  final plantedGh = DateTime(2026, 7, 1);
  final crops = [
    CropPlot(
      id: 'crop-001',
      farmId: farmId,
      name: 'Maize — Field A',
      cropType: 'Maize',
      fieldId: 'field-a',
      fieldName: 'Field A',
      varietyId: 'var-sc403',
      varietyName: 'SC 403',
      growthPercent: CropPlot.growthFor(DateTime.now().difference(plantedA).inDays, 115),
      soilMoisture: 61,
      statusNote: 'Tasseling stage — needs close monitoring',
      growthStage: CropPlot.stageFor(DateTime.now().difference(plantedA).inDays, 115),
      plantedAt: plantedA,
      expectedHarvest: DateTime(2026, 9, 20),
      daysToMaturity: 115,
      plantingDensity: 55000,
    ),
    CropPlot(
      id: 'crop-002',
      farmId: farmId,
      name: 'Tobacco — Field B',
      cropType: 'Tobacco',
      fieldId: 'field-b',
      fieldName: 'Field B',
      varietyId: 'var-kutsaga',
      varietyName: 'Kutsaga',
      growthPercent: CropPlot.growthFor(DateTime.now().difference(plantedB).inDays, 88),
      soilMoisture: 58,
      statusNote: 'Topping soon',
      growthStage: CropPlot.stageFor(DateTime.now().difference(plantedB).inDays, 88),
      plantedAt: plantedB,
      expectedHarvest: DateTime(2026, 9, 10),
      daysToMaturity: 88,
      plantingDensity: 25000,
    ),
    CropPlot(
      id: 'crop-003',
      farmId: farmId,
      name: 'Tomatoes — Greenhouse 1',
      cropType: 'Tomatoes',
      fieldId: 'field-gh1',
      fieldName: 'Greenhouse 1',
      varietyId: 'var-heinz',
      varietyName: 'Heinz',
      growthPercent: CropPlot.growthFor(DateTime.now().difference(plantedGh).inDays, 75),
      soilMoisture: 72,
      statusNote: 'Fruit ripening',
      growthStage: CropPlot.stageFor(DateTime.now().difference(plantedGh).inDays, 75),
      plantedAt: plantedGh,
      expectedHarvest: DateTime(2026, 9, 15),
      daysToMaturity: 75,
      plantingDensity: 30000,
    ),
  ];
  for (final c in crops) {
    await store.putMap(HiveBoxes.crops, c.id, c.toMap());
  }

  await store.putMap(
    HiveBoxes.treatments,
    'tr-001',
    CropTreatment(
      id: 'tr-001',
      farmId: farmId,
      plantingId: 'crop-001',
      treatmentType: TreatmentType.fertilizer,
      productName: 'Urea',
      applicationDate: DateTime(2026, 7, 10),
      ratePerHa: 150,
      costUsd: 75,
      notes: 'Nitrogen application',
    ).toMap(),
  );

  await store.putMap(
    HiveBoxes.observations,
    'obs-001',
    CropObservation(
      id: 'obs-001',
      farmId: farmId,
      plantingId: 'crop-001',
      observationDate: DateTime(2026, 7, 20),
      avgPlantHeightCm: 180,
      colorRating: 4,
      notes: 'Healthy',
    ).toMap(),
  );

  final tasks = [
    FarmTask(
      id: 'task-001',
      farmId: farmId,
      title: 'Vaccinate Pen A cattle',
      description: 'FMD booster due',
      assigneeId: 'worker-001',
      assigneeName: 'Chipo Ncube',
      assignedById: 'owner-001',
      assignedByName: 'John Farmer',
      dueDate: now.add(const Duration(days: 2)),
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      sourceModule: 'livestock',
      createdAt: now,
    ),
    FarmTask(
      id: 'task-002',
      farmId: farmId,
      title: 'Service John Deere tractor',
      assigneeId: 'manager-001',
      assigneeName: 'Tendai Moyo',
      assignedById: 'owner-001',
      assignedByName: 'John Farmer',
      dueDate: now.add(const Duration(days: 10)),
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
      sourceModule: 'equipment',
      createdAt: now,
    ),
    FarmTask(
      id: 'task-003',
      farmId: farmId,
      title: 'Restock cattle feed',
      dueDate: now.add(const Duration(days: 1)),
      priority: TaskPriority.urgent,
      status: TaskStatus.inProgress,
      sourceModule: 'inventory',
      createdAt: now,
    ),
  ];
  for (final t in tasks) {
    await store.putMap(HiveBoxes.tasks, t.id, t.toMap());
  }

  final alerts = [
    FarmAlert(
      id: 'al-001',
      farmId: farmId,
      type: AlertType.vaccinationDue,
      title: 'Vaccination Due',
      message: 'FMD booster for ZW-CATTLE-4821 in 10 days',
      createdAt: now.subtract(const Duration(minutes: 40)),
    ),
    FarmAlert(
      id: 'al-002',
      farmId: farmId,
      type: AlertType.animalSick,
      title: 'Animal Sick',
      message: 'Goat ZW-GOAT-1102 needs follow-up treatment',
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    FarmAlert(
      id: 'al-003',
      farmId: farmId,
      type: AlertType.lowStock,
      title: 'Low Stock',
      message: 'Cattle Feed Pellets below minimum (8 / 10 bags)',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    FarmAlert(
      id: 'al-004',
      farmId: farmId,
      type: AlertType.equipmentService,
      title: 'Equipment Service Due',
      message: 'Disc Harrow service is overdue',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    FarmAlert(
      id: 'al-005',
      farmId: farmId,
      type: AlertType.expectedCalving,
      title: 'Expected Calving',
      message: 'ZW-CATTLE-4821 expected to calve in ~90 days',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
  ];
  for (final a in alerts) {
    await store.putMap(HiveBoxes.alerts, a.id, a.toMap());
  }

  await store.setSeeded();
}
