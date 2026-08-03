import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/offline/local_store.dart';
import '../../core/offline/sync_service.dart';
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
    final users = _store.getAllMaps(HiveBoxes.users).map(FarmUser.fromMap);
    final user = users.cast<FarmUser?>().firstWhere(
          (u) => u!.email.toLowerCase() == email.toLowerCase(),
          orElse: () => null,
        );
    if (user == null) return null;
    if (password != AppConstants.demoPassword &&
        password != 'password' &&
        password.length < 4) {
      return null;
    }
    await _store.setSessionUserId(user.id);
    return user;
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
  }) async {
    final user = FarmUser(
      id: _uuid.v4(),
      name: name,
      email: email,
      farmId: farmId,
      role: role,
      createdAt: DateTime.now(),
    );
    await _store.putMap(HiveBoxes.users, user.id, user.toMap());
    await _store.enqueueSync({'op': 'upsertUser', 'data': user.toMap()});
    await _triggerSync(farmId);
    return user;
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

  Future<Animal> saveAnimal(Animal animal) async {
    await _store.putMap(HiveBoxes.animals, animal.id, animal.toMap());
    await _store.enqueueSync({'op': 'upsertAnimal', 'data': animal.toMap()});
    await _triggerSync(animal.farmId);
    return animal;
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

  Future<FarmTask> saveTask(FarmTask task) async {
    await _store.putMap(HiveBoxes.tasks, task.id, task.toMap());
    await _store.enqueueSync({'op': 'upsertTask', 'data': task.toMap()});
    await _triggerSync(task.farmId);
    return task;
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

  Future<FarmAlert> addAlert(FarmAlert alert) async {
    await _store.putMap(HiveBoxes.alerts, alert.id, alert.toMap());
    await _store.enqueueSync({'op': 'upsertAlert', 'data': alert.toMap()});
    await _triggerSync(alert.farmId);
    return alert;
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
