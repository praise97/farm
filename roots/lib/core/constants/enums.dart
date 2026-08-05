enum UserRole { owner, manager, worker }

enum AnimalStatus {
  alive,
  sold,
  dead,
  missing,
  pregnant,
  sick,
  quarantined,
}

enum AnimalGender { male, female, unknown }

enum TimelineEventType {
  born,
  tagIssued,
  vaccination,
  deworming,
  weightRecord,
  disease,
  treatment,
  breeding,
  pregnancy,
  calving,
  milkProduction,
  movement,
  sale,
  death,
  note,
}

enum EquipmentCondition { excellent, good, fair, poor, broken }

enum EquipmentCategory {
  tractor,
  plough,
  boomSprayer,
  trailer,
  discHarrow,
  planter,
  waterPump,
  generator,
  chainsaw,
  knapsackSprayer,
  seeder,
  cultivator,
  irrigationPipes,
  wheelbarrow,
  other,
}

enum InventoryCategory {
  seeds,
  fertilizer,
  chemicals,
  animalFeed,
  medicine,
  fuel,
  tools,
  spareParts,
  consumables,
}

enum FinanceType { income, expense }

enum IncomeCategory {
  cropSales,
  livestockSales,
  milkSales,
  equipmentHire,
  other,
}

enum ExpenseCategory {
  fuel,
  repairs,
  feed,
  seeds,
  fertilizer,
  chemicals,
  transport,
  workers,
  veterinary,
  utilities,
  other,
}

enum TaskPriority { low, medium, high, urgent }

enum TaskStatus { pending, inProgress, completed, cancelled }

enum AlertType {
  vaccinationDue,
  dewormingDue,
  pregnancyDue,
  expectedCalving,
  animalSick,
  animalMissing,
  weightLoss,
  readyForSale,
  photoRefreshDue,
  lowStock,
  expiredItem,
  nearExpiry,
  equipmentService,
  fertilizerDue,
  harvestSoon,
  rainExpected,
  other,
}

enum MapPointType { field, waterPoint, building, animalPen, road, gps }

extension EnumLabel on Enum {
  String get label {
    final raw = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(1)}',
    );
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
