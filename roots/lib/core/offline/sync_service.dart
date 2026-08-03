import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'local_store.dart';

/// Offline-first Firestore sync: push local queue, then pull cloud data into Hive.
class SyncService {
  SyncService(this._store);

  final LocalStore _store;
  bool _running = false;
  DateTime? _lastSync;
  String? _lastError;

  bool get isRunning => _running;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;

  Future<bool> get isOnline async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Full sync for the signed-in user's farm.
  Future<bool> syncFarm(String farmId) async {
    if (!AppConstants.firebaseConfigured || _running) return false;
    if (!await isOnline) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;

    _running = true;
    _lastError = null;
    try {
      await _pushPending(farmId);
      await _pullFarmData(farmId);
      _lastSync = DateTime.now();
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('Sync failed: $e\n$st');
      return false;
    } finally {
      _running = false;
    }
  }

  Future<void> _pushPending(String farmId) async {
    final db = FirebaseFirestore.instance;
    final pending = _store.pendingSyncEntries();

    for (final entry in pending) {
      final op = entry.data;
      final queueId = entry.id;
      final type = op['op'] as String?;
      final data = op['data'] as Map<String, dynamic>?;

      try {
        switch (type) {
          case 'register':
            await _pushRegister(op);
          case 'upsertFarm':
            if (data != null) {
              await db.collection('farms').doc(data['id'] as String).set(data, SetOptions(merge: true));
            }
          case 'upsertUser':
            if (data != null) {
              await db.collection('users').doc(data['id'] as String).set(data, SetOptions(merge: true));
            }
          case 'upsertAnimal':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('animals')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertEquipment':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('equipment')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertInventory':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('inventory')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertFinance':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('finance')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertTask':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('tasks')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertCrop':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('crops')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertField':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('fields')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertCropCatalog':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('cropCatalog')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertVariety':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('varieties')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertTreatment':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('treatments')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertObservation':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('observations')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertTimeline':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('timeline')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'upsertAlert':
            if (data != null) {
              await db
                  .collection('farms')
                  .doc(farmId)
                  .collection('alerts')
                  .doc(data['id'] as String)
                  .set(data, SetOptions(merge: true));
            }
          case 'deleteAnimal':
            await db.collection('farms').doc(farmId).collection('animals').doc(op['id'] as String).delete();
          case 'deleteEquipment':
            await db.collection('farms').doc(farmId).collection('equipment').doc(op['id'] as String).delete();
          default:
            debugPrint('Sync: unhandled op $type');
            continue;
        }
        await _store.dequeueSync(queueId);
      } catch (e) {
        debugPrint('Sync op failed ($type): $e');
        rethrow;
      }
    }
  }

  Future<void> _pushRegister(Map<String, dynamic> op) async {
    final farmId = op['farmId'] as String?;
    final userId = op['userId'] as String?;
    if (farmId == null || userId == null) return;

    final farm = _store.getMap(HiveBoxes.farms, farmId);
    final user = _store.getMap(HiveBoxes.users, userId);
    final db = FirebaseFirestore.instance;
    if (farm != null) {
      await db.collection('farms').doc(farmId).set(farm, SetOptions(merge: true));
    }
    if (user != null) {
      await db.collection('users').doc(userId).set(user, SetOptions(merge: true));
    }
  }

  Future<void> _pullFarmData(String farmId) async {
    final db = FirebaseFirestore.instance;

    final farmDoc = await db.collection('farms').doc(farmId).get();
    if (farmDoc.exists && farmDoc.data() != null) {
      await _store.putMap(HiveBoxes.farms, farmId, farmDoc.data()!);
    }

    await _pullCollection(db, farmId, 'animals', HiveBoxes.animals);
    await _pullCollection(db, farmId, 'equipment', HiveBoxes.equipment);
    await _pullCollection(db, farmId, 'inventory', HiveBoxes.inventory);
    await _pullCollection(db, farmId, 'finance', HiveBoxes.finance);
    await _pullCollection(db, farmId, 'tasks', HiveBoxes.tasks);
    await _pullCollection(db, farmId, 'crops', HiveBoxes.crops);
    await _pullCollection(db, farmId, 'cropCatalog', HiveBoxes.cropCatalog);
    await _pullCollection(db, farmId, 'varieties', HiveBoxes.varieties);
    await _pullCollection(db, farmId, 'fields', HiveBoxes.fields);
    await _pullCollection(db, farmId, 'treatments', HiveBoxes.treatments);
    await _pullCollection(db, farmId, 'observations', HiveBoxes.observations);
    await _pullCollection(db, farmId, 'alerts', HiveBoxes.alerts);
    await _pullCollection(db, farmId, 'timeline', HiveBoxes.timeline);

    final users = await db.collection('users').where('farmId', isEqualTo: farmId).get();
    for (final doc in users.docs) {
      await _store.putMap(HiveBoxes.users, doc.id, doc.data());
    }
  }

  Future<void> _pullCollection(
    FirebaseFirestore db,
    String farmId,
    String collection,
    String hiveBox,
  ) async {
    final snap = await db.collection('farms').doc(farmId).collection(collection).get();
    for (final doc in snap.docs) {
      await _store.putMap(hiveBox, doc.id, doc.data());
    }
  }
}
