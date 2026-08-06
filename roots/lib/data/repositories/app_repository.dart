import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/sync_service.dart';
import '../../core/services/animal_photo_service.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/crop_entities.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/farm_user.dart';
import '../../domain/entities/shared_entities.dart';

const _uuid = Uuid();

/// Offline-first repository. Writes locally first, syncs to Firestore when online.
class AppRepository {
  AppRepository(this._store, [SyncService? sync]) : _sync = sync ?? SyncService(_store);

  final LocalStore _store;
  final SyncService _sync;

  SyncService get sync => _sync;

  // ── Auth / users ──────────────────────────────────────────
  FarmUser? currentUser() {
    // Prefer local session — demo login on desktop must not depend on Firebase UID.
    final id = _store.sessionUserId;
    if (id != null) {
      final map = _store.getMap(HiveBoxes.users, id);
      if (map != null) return FarmUser.fromMap(map);
    }
    if (AppConstants.firebaseConfigured) {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        final map = _store.getMap(HiveBoxes.users, fbUser.uid);
        if (map != null) return FarmUser.fromMap(map);
      }
    }
    return null;
  }

  Future<FarmUser?> login(String email, String password) async {
    if (AppConstants.firebaseConfigured && await _sync.isOnline) {
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final uid = cred.user!.uid;
        final user = await _loadOrCreateUserDoc(uid, email.trim());
        if (user != null) {
          await _store.putMap(HiveBoxes.users, user.id, user.toMap());
          await _store.setSessionUserId(user.id);
          await _sync.syncFarm(user.farmId);
          return user;
        }
        // Firebase account exists but no Roots profile — use local demo session.
        await FirebaseAuth.instance.signOut();
        return _localLogin(email, password);
      } catch (_) {
        // Windows / network / unknown credential errors → offline demo login.
        return _localLogin(email, password);
      }
    }
    return _localLogin(email, password);
  }

  Future<FarmUser?> _localLogin(String email, String password) async {
    final users = _store.getAllMaps(HiveBoxes.users);
    for (final map in users) {
      final user = FarmUser.fromMap(map);
      if (user.email.toLowerCase() != email.toLowerCase()) continue;
      final storedPw = map['localPassword'] as String?;
      final roleDefault = AppConstants.defaultPasswordForRole(user.role);
      final valid = password == AppConstants.demoPassword ||
          password == roleDefault ||
          (storedPw != null && password == storedPw) ||
          (user.role != UserRole.worker && password == 'password');
      if (valid) {
        await _store.setSessionUserId(user.id);
        return user;
      }
    }
    return null;
  }

  Future<FarmUser> createWorkerAccount({
    required String farmId,
    required String name,
    required String email,
    required UserRole role,
    required String createdById,
  }) async {
    assert(role == UserRole.worker || role == UserRole.manager);
    final existing = workers(farmId).any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (existing) throw Exception('Email already registered on this farm');

    final userId = _uuid.v4();
    final user = FarmUser(
      id: userId,
      name: name,
      email: email.trim(),
      farmId: farmId,
      role: role,
      createdAt: DateTime.now(),
    );
    await _store.putMap(HiveBoxes.users, userId, {
      ...user.toMap(),
      'localPassword': AppConstants.defaultPasswordForRole(role),
      'createdById': createdById,
    });
    await _store.enqueueSync({'op': 'upsertUser', 'data': user.toMap()});
    await _triggerSync(farmId);
    return user;
  }

  Future<String?> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 4) return 'Password must be at least 4 characters';
    final map = _store.getMap(HiveBoxes.users, userId);
    if (map == null) return 'User not found';

    final user = FarmUser.fromMap(map);
    final roleDefault = AppConstants.defaultPasswordForRole(user.role);
    final stored = map['localPassword'] as String? ?? roleDefault;
    final ownerDemo = user.role == UserRole.owner && currentPassword == AppConstants.demoPassword;

    if (!ownerDemo &&
        currentPassword != stored &&
        currentPassword != roleDefault &&
        currentPassword != AppConstants.defaultWorkerPassword &&
        currentPassword != AppConstants.defaultAdminPassword) {
      return 'Current password is incorrect';
    }

    await _store.putMap(HiveBoxes.users, userId, {...map, 'localPassword': newPassword});

    if (AppConstants.firebaseConfigured && FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      } catch (_) {
        // Local password still updated for offline worker login.
      }
    }
    return null;
  }

  Future<FarmUser?> _loadOrCreateUserDoc(String uid, String email) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return FarmUser.fromMap({...doc.data()!, 'id': uid});
    }
    return null;
  }

  Future<FarmUser> register({
    required String name,
    required String email,
    required String password,
    required String farmName,
  }) async {
    final now = DateTime.now();

    if (AppConstants.firebaseConfigured && await _sync.isOnline) {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final farmId = _uuid.v4();
      final farm = Farm(
        id: farmId,
        name: farmName,
        ownerId: uid,
        createdAt: now,
      );
      final user = FarmUser(
        id: uid,
        name: name,
        email: email.trim(),
        farmId: farmId,
        role: UserRole.owner,
        createdAt: now,
      );
      await _store.putMap(HiveBoxes.farms, farm.id, farm.toMap());
      await _store.putMap(HiveBoxes.users, user.id, user.toMap());
      await _store.setSessionUserId(user.id);

      final db = FirebaseFirestore.instance;
      await db.collection('farms').doc(farmId).set(farm.toMap());
      await db.collection('users').doc(uid).set(user.toMap());
      return user;
    }

    final farmId = _uuid.v4();
    final userId = _uuid.v4();
    final farm = Farm(
      id: farmId,
      name: farmName,
      ownerId: userId,
      createdAt: now,
    );
    final user = FarmUser(
      id: userId,
      name: name,
      email: email.trim(),
      farmId: farmId,
      role: UserRole.owner,
      createdAt: now,
    );
    await _store.putMap(HiveBoxes.farms, farm.id, farm.toMap());
    await _store.putMap(HiveBoxes.users, user.id, user.toMap());
    await _store.setSessionUserId(user.id);
    await _store.enqueueSync({
      'op': 'register',
      'userId': userId,
      'farmId': farmId,
    });
    return user;
  }

  Future<void> logout() async {
    if (AppConstants.firebaseConfigured) {
      await FirebaseAuth.instance.signOut();
    }
    await _store.setSessionUserId(null);
  }

  List<FarmUser> workers(String farmId) => _store
      .getAllMaps(HiveBoxes.users)
      .map(FarmUser.fromMap)
      .where((u) => u.farmId == farmId)
      .toList();

  Future<FarmUser> addWorker({
    required String farmId,
    required String name,
    required String email,
    required UserRole role,
    String? createdById,
  }) async {
    return createWorkerAccount(
      farmId: farmId,
      name: name,
      email: email,
      role: role,
      createdById: createdById ?? farmId,
    );
  }

  Farm? farm(String farmId) {
    final map = _store.getMap(HiveBoxes.farms, farmId);
    return map == null ? null : Farm.fromMap(map);
  }

  Future<bool> syncCurrentFarm() async {
    final user = currentUser();
    if (user == null) return false;
    return _sync.syncFarm(user.farmId);
  }

  Future<void> _triggerSync(String farmId) async {
    if (await _sync.isOnline) {
      await _sync.syncFarm(farmId);
    }
  }

  // ── Animals ───────────────────────────────────────────────
  List<Animal> animals(String farmId) => _store
      .getAllMaps(HiveBoxes.animals)
      .map(Animal.fromMap)
      .where((a) => a.farmId == farmId)
      .toList()
    ..sort((a, b) => a.tagNumber.compareTo(b.tagNumber));

  Animal? animal(String id) {
    final map = _store.getMap(HiveBoxes.animals, id);
    return map == null ? null : Animal.fromMap(map);
  }

  Future<Animal> saveAnimal(Animal animal, {Animal? previous}) async {
    var next = animal;
    final wasTerminal = previous?.isTerminal ?? false;
    final nowTerminal = animal.isTerminal;

    if (!wasTerminal && nowTerminal) {
      await _purgeAnimalPhotos(next);
      next = next.copyWith(
        clearPhoto1: true,
        clearPhoto2: true,
        clearPhotosUpdatedAt: true,
        photoUrl: null,
        updatedAt: DateTime.now(),
      );
    }

    await _store.putMap(HiveBoxes.animals, next.id, next.toMap());
    await _store.enqueueSync({'op': 'upsertAnimal', 'data': next.toMap()});
    await _triggerSync(next.farmId);
    return next;
  }

  Future<void> _purgeAnimalPhotos(Animal animal) async {
    await AnimalPhotoService.instance.deleteUrls([
      animal.photo1Url,
      animal.photo2Url,
      animal.photoUrl,
    ]);
  }

  /// Upload 2 photos; deletes previous URLs first to save storage.
  Future<Animal> saveAnimalPhotos({
    required Animal animal,
    String? photo1LocalPath,
    String? photo2LocalPath,
  }) async {
    final oldUrls = [animal.photo1Url, animal.photo2Url];
    String? photo1Url = animal.photo1Url;
    String? photo2Url = animal.photo2Url;

    if (photo1LocalPath != null) {
      if (animal.photo1Url != null) {
        await AnimalPhotoService.instance.deleteUrls([animal.photo1Url]);
      }
      photo1Url = await AnimalPhotoService.instance.upload(
        farmId: animal.farmId,
        animalId: animal.id,
        slot: 1,
        localPath: photo1LocalPath,
      );
    }
    if (photo2LocalPath != null) {
      if (animal.photo2Url != null) {
        await AnimalPhotoService.instance.deleteUrls([animal.photo2Url]);
      }
      photo2Url = await AnimalPhotoService.instance.upload(
        farmId: animal.farmId,
        animalId: animal.id,
        slot: 2,
        localPath: photo2LocalPath,
      );
    }

    // If replacing both, ensure any leftover old URL is removed.
    if (photo1LocalPath != null || photo2LocalPath != null) {
      for (final old in oldUrls) {
        if (old != null && old != photo1Url && old != photo2Url) {
          await AnimalPhotoService.instance.deleteUrls([old]);
        }
      }
    }

    final updated = animal.copyWith(
      photo1Url: photo1Url,
      photo2Url: photo2Url,
      photoUrl: photo1Url,
      photosUpdatedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return saveAnimal(updated, previous: animal);
  }

  /// Yearly reminder: capture fresh photos (old ones are replaced on upload).
  Future<int> scanPhotoRefreshDue(String farmId) async {
    final now = DateTime.now();
    final existing = alerts(farmId)
        .where((a) => a.type == AlertType.photoRefreshDue && !a.read)
        .map((a) => a.relatedId)
        .toSet();
    var created = 0;
    for (final animal in animals(farmId)) {
      if (animal.isTerminal) continue;
      if (!animal.needsPhotoRefresh) continue;
      if (existing.contains(animal.id)) continue;

      final last = animal.photosUpdatedAt;
      final alert = FarmAlert(
        id: _uuid.v4(),
        farmId: farmId,
        type: AlertType.photoRefreshDue,
        title: 'New photos needed: ${animal.tagNumber}',
        message: last == null
            ? 'Capture 2 photos for ${animal.breed}. Old photos are removed when you update.'
            : 'Photos are over 1 year old (last: ${last.day}/${last.month}/${last.year}). Capture 2 new photos — old ones will be deleted from storage.',
        createdAt: now,
        relatedId: animal.id,
      );
      await addAlert(alert);
      created++;
    }
    return created;
  }

  Future<void> deleteAnimal(String id, String farmId) async {
    await _store.delete(HiveBoxes.animals, id);
    await _store.enqueueSync({'op': 'deleteAnimal', 'id': id, 'farmId': farmId});
    await _triggerSync(farmId);
  }

  List<AnimalTimelineEvent> timelineFor(String animalId) => _store
      .getAllMaps(HiveBoxes.timeline)
      .map(AnimalTimelineEvent.fromMap)
      .where((e) => e.animalId == animalId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<AnimalTimelineEvent> addTimelineEvent(AnimalTimelineEvent event) async {
    await _store.putMap(HiveBoxes.timeline, event.id, event.toMap());
    await _store.enqueueSync({'op': 'upsertTimeline', 'data': event.toMap()});

    if (event.type == TimelineEventType.death || event.type == TimelineEventType.sale) {
      final animal = this.animal(event.animalId);
      if (animal != null && !animal.isTerminal) {
        final status =
            event.type == TimelineEventType.death ? AnimalStatus.dead : AnimalStatus.sold;
        await saveAnimal(
          animal.copyWith(status: status, updatedAt: DateTime.now()),
          previous: animal,
        );
      }
    }

    await _triggerSync(event.farmId);
    return event;
  }

  // ── Equipment ─────────────────────────────────────────────
  List<EquipmentItem> equipment(String farmId) => _store
      .getAllMaps(HiveBoxes.equipment)
      .map(EquipmentItem.fromMap)
      .where((e) => e.farmId == farmId)
      .toList();

  Future<EquipmentItem> saveEquipment(EquipmentItem item) async {
    await _store.putMap(HiveBoxes.equipment, item.id, item.toMap());
    await _store.enqueueSync({'op': 'upsertEquipment', 'data': item.toMap()});
    await _triggerSync(item.farmId);
    return item;
  }

  Future<void> deleteEquipment(String id, String farmId) async {
    await _store.delete(HiveBoxes.equipment, id);
    await _store.enqueueSync({'op': 'deleteEquipment', 'id': id, 'farmId': farmId});
    await _triggerSync(farmId);
  }

  // ── Inventory ─────────────────────────────────────────────
  List<InventoryItem> inventory(String farmId) => _store
      .getAllMaps(HiveBoxes.inventory)
      .map(InventoryItem.fromMap)
      .where((i) => i.farmId == farmId)
      .toList();

  Future<InventoryItem> saveInventory(InventoryItem item) async {
    await _store.putMap(HiveBoxes.inventory, item.id, item.toMap());
    await _store.enqueueSync({'op': 'upsertInventory', 'data': item.toMap()});
    await _triggerSync(item.farmId);
    return item;
  }

  // ── Finance ───────────────────────────────────────────────
  List<FinanceEntry> finance(String farmId) => _store
      .getAllMaps(HiveBoxes.finance)
      .map(FinanceEntry.fromMap)
      .where((f) => f.farmId == farmId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<FinanceEntry> saveFinance(FinanceEntry entry) async {
    await _store.putMap(HiveBoxes.finance, entry.id, entry.toMap());
    await _store.enqueueSync({'op': 'upsertFinance', 'data': entry.toMap()});
    await _triggerSync(entry.farmId);
    return entry;
  }

  // ── Tasks ─────────────────────────────────────────────────
  List<FarmTask> tasks(String farmId) => _store
      .getAllMaps(HiveBoxes.tasks)
      .map(FarmTask.fromMap)
      .where((t) => t.farmId == farmId)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<FarmTask> tasksForWorker(String farmId, String workerId) => tasks(farmId)
      .where((t) => t.assigneeId == workerId)
      .toList();

  Future<FarmTask> saveTask(FarmTask task) async {
    await _store.putMap(HiveBoxes.tasks, task.id, task.toMap());
    await _store.enqueueSync({'op': 'upsertTask', 'data': task.toMap()});
    await _triggerSync(task.farmId);
    return task;
  }

  Future<FarmTask> assignTask({
    required FarmTask task,
    required FarmUser supervisor,
    required FarmUser assignee,
  }) async {
    final assigned = task.copyWith(
      assigneeId: assignee.id,
      assigneeName: assignee.name,
      assignedById: supervisor.id,
      assignedByName: supervisor.name,
      status: TaskStatus.pending,
    );
    await saveTask(assigned);
    await _notifyTaskUser(
      farmId: task.farmId,
      targetUserId: assignee.id,
      taskId: task.id,
      type: AlertType.taskAssigned,
      title: 'New task: ${task.title}',
      message: '${supervisor.name} assigned you a task due ${task.dueDate.day}/${task.dueDate.month}.',
    );
    return assigned;
  }

  Future<FarmTask> completeTaskByWorker({
    required FarmTask task,
    required String workerNotes,
  }) async {
    final updated = task.copyWith(
      status: TaskStatus.awaitingReview,
      workerNotes: workerNotes,
      completedAt: DateTime.now(),
    );
    await saveTask(updated);
    if (task.assignedById != null) {
      await _notifyTaskUser(
        farmId: task.farmId,
        targetUserId: task.assignedById!,
        taskId: task.id,
        type: AlertType.other,
        title: 'Task ready for review: ${task.title}',
        message: '${task.assigneeName ?? 'Worker'} submitted work notes.',
      );
    }
    return updated;
  }

  Future<FarmTask> reviewTaskBySupervisor({
    required FarmTask task,
    required String supervisorNotes,
    required FarmUser supervisor,
  }) async {
    final updated = task.copyWith(
      status: TaskStatus.completed,
      supervisorNotes: supervisorNotes,
      reviewedAt: DateTime.now(),
    );
    await saveTask(updated);
    if (task.assigneeId != null) {
      await _notifyTaskUser(
        farmId: task.farmId,
        targetUserId: task.assigneeId!,
        taskId: task.id,
        type: AlertType.taskReviewed,
        title: 'Task approved: ${task.title}',
        message: '${supervisor.name} marked this task complete. $supervisorNotes',
      );
    }
    return updated;
  }

  Future<void> _notifyTaskUser({
    required String farmId,
    required String targetUserId,
    required String taskId,
    required AlertType type,
    required String title,
    required String message,
  }) async {
    await addAlert(FarmAlert(
      id: _uuid.v4(),
      farmId: farmId,
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      relatedId: taskId,
      targetUserId: targetUserId,
    ));
  }

  /// CSV summary for supervisor — tasks, workers, completion rates.
  String generatePerformanceReport(String farmId) {
    final farmTasks = tasks(farmId);
    final staff = workers(farmId);
    final buf = StringBuffer();
    buf.writeln('Roots Farm Performance Report');
    buf.writeln('Generated,${DateTime.now().toIso8601String()}');
    buf.writeln('');
    buf.writeln('WORKER SUMMARY');
    buf.writeln('Name,Role,Assigned,Completed,Awaiting Review,Completion %');
    for (final w in staff) {
      final mine = farmTasks.where((t) => t.assigneeId == w.id).toList();
      final done = mine.where((t) => t.status == TaskStatus.completed).length;
      final review = mine.where((t) => t.status == TaskStatus.awaitingReview).length;
      final pct = mine.isEmpty ? 0 : ((done / mine.length) * 100).round();
      buf.writeln('${w.name},${w.role.name},${mine.length},$done,$review,$pct%');
    }
    buf.writeln('');
    buf.writeln('TASK DETAIL');
    buf.writeln('Title,Assignee,Status,Priority,Due,Worker Notes,Supervisor Notes');
    for (final t in farmTasks) {
      buf.writeln(
        '"${t.title}","${t.assigneeName ?? ''}",${t.status.name},${t.priority.name},'
        '${t.dueDate.toIso8601String()},"${t.workerNotes ?? ''}","${t.supervisorNotes ?? ''}"',
      );
    }
    return buf.toString();
  }

  List<FarmAlert> alertsForUser(String farmId, String userId, {bool isSupervisor = false}) {
    final all = alerts(farmId);
    if (isSupervisor) return all;
    return all
        .where((a) => a.targetUserId == null || a.targetUserId == userId)
        .toList();
  }

  // ── Crops (Firebase — partner MySQL schema ported) ────────
  List<CropPlot> crops(String farmId) => _store
      .getAllMaps(HiveBoxes.crops)
      .map(CropPlot.fromMap)
      .where((c) => c.farmId == farmId && c.isActive)
      .toList()
    ..sort((a, b) => b.growthPercent.compareTo(a.growthPercent));

  Future<CropPlot> saveCrop(CropPlot crop) async {
    final maturity = crop.daysToMaturity ?? 120;
    final days = crop.daysSincePlanting;
    final enriched = crop.copyWith(
      growthPercent: CropPlot.growthFor(days, maturity),
      growthStage: CropPlot.stageFor(days, maturity),
      statusNote: 'at ${CropPlot.growthFor(days, maturity).toStringAsFixed(0)}% — ${CropPlot.stageFor(days, maturity)}',
    );
    await _store.putMap(HiveBoxes.crops, enriched.id, enriched.toMap());
    await _store.enqueueSync({'op': 'upsertCrop', 'data': enriched.toMap()});
    await _triggerSync(enriched.farmId);
    return enriched;
  }

  List<FarmField> fields(String farmId) => _store
      .getAllMaps(HiveBoxes.fields)
      .map(FarmField.fromMap)
      .where((f) => f.farmId == farmId)
      .toList()
    ..sort((a, b) => a.fieldName.compareTo(b.fieldName));

  Future<FarmField> saveField(FarmField field) async {
    await _store.putMap(HiveBoxes.fields, field.id, field.toMap());
    await _store.enqueueSync({'op': 'upsertField', 'data': field.toMap()});
    await _triggerSync(field.farmId);
    return field;
  }

  List<CropCatalogItem> cropCatalog(String farmId) => _store
      .getAllMaps(HiveBoxes.cropCatalog)
      .map(CropCatalogItem.fromMap)
      .where((c) => c.farmId == farmId)
      .toList()
    ..sort((a, b) => a.cropName.compareTo(b.cropName));

  Future<CropCatalogItem> saveCropCatalog(CropCatalogItem item) async {
    await _store.putMap(HiveBoxes.cropCatalog, item.id, item.toMap());
    await _store.enqueueSync({'op': 'upsertCropCatalog', 'data': item.toMap()});
    await _triggerSync(item.farmId);
    return item;
  }

  List<CropVariety> varieties(String farmId) => _store
      .getAllMaps(HiveBoxes.varieties)
      .map(CropVariety.fromMap)
      .where((v) => v.farmId == farmId)
      .toList();

  Future<CropVariety> saveVariety(CropVariety variety) async {
    await _store.putMap(HiveBoxes.varieties, variety.id, variety.toMap());
    await _store.enqueueSync({'op': 'upsertVariety', 'data': variety.toMap()});
    await _triggerSync(variety.farmId);
    return variety;
  }

  List<CropTreatment> treatments(String farmId, {String? plantingId}) {
    final list = _store
        .getAllMaps(HiveBoxes.treatments)
        .map(CropTreatment.fromMap)
        .where((t) => t.farmId == farmId)
        .where((t) => plantingId == null || t.plantingId == plantingId)
        .toList()
      ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
    return list;
  }

  Future<CropTreatment> saveTreatment(CropTreatment treatment) async {
    await _store.putMap(HiveBoxes.treatments, treatment.id, treatment.toMap());
    await _store.enqueueSync({'op': 'upsertTreatment', 'data': treatment.toMap()});
    await _triggerSync(treatment.farmId);
    return treatment;
  }

  List<CropObservation> observations(String farmId, {String? plantingId}) {
    final list = _store
        .getAllMaps(HiveBoxes.observations)
        .map(CropObservation.fromMap)
        .where((o) => o.farmId == farmId)
        .where((o) => plantingId == null || o.plantingId == plantingId)
        .toList()
      ..sort((a, b) => b.observationDate.compareTo(a.observationDate));
    return list;
  }

  Future<CropObservation> saveObservation(CropObservation observation) async {
    await _store.putMap(HiveBoxes.observations, observation.id, observation.toMap());
    await _store.enqueueSync({'op': 'upsertObservation', 'data': observation.toMap()});
    if (observation.pestPresence || observation.diseasePresence) {
      final planting = _store.getMap(HiveBoxes.crops, observation.plantingId);
      if (planting != null) {
        final crop = CropPlot.fromMap(planting).copyWith(
          pestPresence: observation.pestPresence || (planting['pestPresence'] as bool? ?? false),
          diseasePresence: observation.diseasePresence || (planting['diseasePresence'] as bool? ?? false),
        );
        await saveCrop(crop);
        await addAlert(FarmAlert(
          id: newId(),
          farmId: observation.farmId,
          type: AlertType.other,
          title: observation.pestPresence ? 'Pest alert' : 'Disease alert',
          message: '${crop.name}: ${observation.notes ?? 'Needs attention'}',
          createdAt: DateTime.now(),
          relatedId: crop.id,
        ));
      }
    }
    await _triggerSync(observation.farmId);
    return observation;
  }

  // ── Alerts ────────────────────────────────────────────────
  List<FarmAlert> alerts(String farmId) => _store
      .getAllMaps(HiveBoxes.alerts)
      .map(FarmAlert.fromMap)
      .where((a) => a.farmId == farmId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> markAlertRead(String id, String farmId) async {
    final map = _store.getMap(HiveBoxes.alerts, id);
    if (map == null) return;
    final alert = FarmAlert.fromMap(map).copyWith(read: true);
    await _store.putMap(HiveBoxes.alerts, id, alert.toMap());
    await _store.enqueueSync({'op': 'upsertAlert', 'data': alert.toMap()});
    await _triggerSync(farmId);
  }

  Future<FarmAlert> addAlert(FarmAlert alert, {bool notify = true}) async {
    await _store.putMap(HiveBoxes.alerts, alert.id, alert.toMap());
    await _store.enqueueSync({'op': 'upsertAlert', 'data': alert.toMap()});
    await _triggerSync(alert.farmId);
    if (notify) {
      final sessionId = _store.sessionUserId;
      final forCurrentUser =
          alert.targetUserId == null || alert.targetUserId == sessionId;
      if (forCurrentUser) {
        await NotificationService.instance.showAlert(
          id: alert.id.hashCode,
          title: alert.title,
          body: alert.message,
        );
      }
    }
    return alert;
  }

  /// Latest vaccination per animal (uses timeline meta.nextDue).
  List<VaccinationDueInfo> vaccinationStatus(String farmId) {
    final out = <VaccinationDueInfo>[];
    for (final animal in animals(farmId)) {
      final info = vaccinationForAnimal(animal.id);
      if (info != null) out.add(info);
    }
    out.sort((a, b) {
      final ad = a.nextDue ?? DateTime(9999);
      final bd = b.nextDue ?? DateTime(9999);
      return ad.compareTo(bd);
    });
    return out;
  }

  VaccinationDueInfo? vaccinationForAnimal(String animalId) {
    final animal = this.animal(animalId);
    if (animal == null) return null;
    final vax = timelineFor(animalId)
        .where((e) => e.type == TimelineEventType.vaccination)
        .toList();
    if (vax.isEmpty) {
      return VaccinationDueInfo(animal: animal, last: null, nextDue: null);
    }
    final last = vax.first;
    DateTime? nextDue;
    final raw = last.meta['nextDue'];
    if (raw is String) nextDue = DateTime.tryParse(raw);
    return VaccinationDueInfo(animal: animal, last: last, nextDue: nextDue);
  }

  /// Creates alerts + phone notifications for vaccinations due this month / overdue.
  Future<int> scanVaccinationDue(String farmId) async {
    final now = DateTime.now();
    final existing = alerts(farmId)
        .where((a) => a.type == AlertType.vaccinationDue && !a.read)
        .map((a) => a.relatedId)
        .toSet();
    var created = 0;
    for (final info in vaccinationStatus(farmId)) {
      final due = info.nextDue;
      if (due == null) continue;
      final dueThisMonth = due.year == now.year && due.month == now.month;
      final overdue = due.isBefore(DateTime(now.year, now.month, now.day));
      if (!dueThisMonth && !overdue) continue;
      if (existing.contains(info.animal.id)) continue;

      final vaccine =
          info.last?.meta['vaccine'] as String? ?? info.last?.title ?? 'Vaccination';
      final alert = FarmAlert(
        id: _uuid.v4(),
        farmId: farmId,
        type: AlertType.vaccinationDue,
        title: overdue
            ? 'Overdue: ${info.animal.tagNumber}'
            : 'Vaccinate ${info.animal.tagNumber} this month',
        message: overdue
            ? '$vaccine was due ${due.day}/${due.month}/${due.year}. Schedule now.'
            : '$vaccine due ${due.day}/${due.month}/${due.year} for ${info.animal.breed}.',
        createdAt: now,
        relatedId: info.animal.id,
      );
      await addAlert(alert);
      created++;
    }
    return created;
  }

  // ── Search ────────────────────────────────────────────────
  List<Map<String, String>> search(String farmId, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final results = <Map<String, String>>[];

    for (final a in animals(farmId)) {
      if (a.tagNumber.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q)) {
        results.add({
          'type': 'Animal',
          'title': a.tagNumber,
          'subtitle': '${a.breed} · ${a.status.label}',
          'route': '/livestock/${a.id}',
        });
      }
    }
    for (final e in equipment(farmId)) {
      if (e.name.toLowerCase().contains(q) || e.category.label.toLowerCase().contains(q)) {
        results.add({
          'type': 'Equipment',
          'title': e.name,
          'subtitle': e.category.label,
          'route': '/equipment',
        });
      }
    }
    for (final i in inventory(farmId)) {
      if (i.name.toLowerCase().contains(q)) {
        results.add({
          'type': 'Inventory',
          'title': i.name,
          'subtitle': '${i.quantity} ${i.unit}',
          'route': '/inventory',
        });
      }
    }
    for (final c in crops(farmId)) {
      if (c.name.toLowerCase().contains(q) || c.cropType.toLowerCase().contains(q)) {
        results.add({
          'type': 'Crop',
          'title': c.name,
          'subtitle': '${c.growthPercent.toStringAsFixed(0)}% growth',
          'route': '/crops',
        });
      }
    }
    for (final w in workers(farmId)) {
      if (w.name.toLowerCase().contains(q) || w.email.toLowerCase().contains(q)) {
        results.add({
          'type': 'Worker',
          'title': w.name,
          'subtitle': w.role.label,
          'route': '/workers',
        });
      }
    }
    return results;
  }

  String newId() => _uuid.v4();
}

class VaccinationDueInfo {
  const VaccinationDueInfo({
    required this.animal,
    required this.last,
    required this.nextDue,
  });

  final Animal animal;
  final AnimalTimelineEvent? last;
  final DateTime? nextDue;

  bool get dueThisMonth {
    if (nextDue == null) return false;
    final now = DateTime.now();
    return nextDue!.year == now.year && nextDue!.month == now.month;
  }

  bool get isOverdue {
    if (nextDue == null) return false;
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    return nextDue!.isBefore(d);
  }
}
