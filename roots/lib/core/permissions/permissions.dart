import '../constants/enums.dart';

/// Role-based permissions for Roots.
class Permissions {
  final UserRole role;

  const Permissions(this.role);

  bool get isOwner => role == UserRole.owner;
  bool get isManager => role == UserRole.manager || isOwner;
  bool get isWorker => role == UserRole.worker;

  bool get canManageWorkers => isOwner;
  bool get canEditFarmSettings => isOwner;
  bool get canDeleteRecords => isManager;
  bool get canManageFinance => isManager;
  bool get canExportReports => isManager;
  bool get canAssignTasks => isManager;
  bool get canAddAnimals => true;
  bool get canAddEquipment => isManager;
  bool get canStockAdjust => true;
  bool get canViewFinance => isManager;
  bool get canInviteWorkers => isOwner;
  bool get canSellAnimals => isManager;
  bool get canMarkDead => isManager;
}
