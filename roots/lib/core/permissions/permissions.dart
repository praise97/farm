import '../constants/enums.dart';

/// Role-based permissions — Supervisor (owner/manager) vs Worker.
class Permissions {
  final UserRole role;

  const Permissions(this.role);

  bool get isOwner => role == UserRole.owner;
  bool get isManager => role == UserRole.manager;
  /// Supervisor = farm admin who creates workers, assigns tasks, reviews work, exports reports.
  bool get isSupervisor => isOwner || isManager;
  bool get isWorker => role == UserRole.worker;

  bool get canManageWorkers => isSupervisor;
  bool get canCreateWorkerAccounts => isSupervisor;
  bool get canEditFarmSettings => isOwner;
  bool get canDeleteRecords => isSupervisor;
  bool get canManageFinance => isSupervisor;
  bool get canExportReports => isSupervisor;
  bool get canAssignTasks => isSupervisor;
  bool get canReviewTasks => isSupervisor;
  bool get canViewAllTasks => isSupervisor;
  bool get canAddAnimals => isSupervisor || isWorker;
  bool get canAddEquipment => isSupervisor;
  bool get canStockAdjust => isSupervisor || isWorker;
  bool get canViewFinance => isSupervisor;
  bool get canInviteWorkers => isSupervisor;
  bool get canSellAnimals => isSupervisor;
  bool get canMarkDead => isSupervisor;
  bool get canChangeOwnPassword => true;

  /// Workers see a reduced sidebar (dashboard, tasks, livestock, alerts, settings).
  bool get showFullNavigation => isSupervisor;
}
