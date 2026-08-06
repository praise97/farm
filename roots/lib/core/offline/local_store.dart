import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class SyncQueueEntry {
  const SyncQueueEntry({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
}

/// Offline-first local store backed by Hive + SharedPreferences.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  late SharedPreferences prefs;
  final Map<String, Box<String>> _boxes = {};

  Future<void> init() async {
    await Hive.initFlutter();
    prefs = await SharedPreferences.getInstance();
    for (final name in [
      HiveBoxes.animals,
      HiveBoxes.equipment,
      HiveBoxes.inventory,
      HiveBoxes.finance,
      HiveBoxes.tasks,
      HiveBoxes.crops,
      HiveBoxes.cropCatalog,
      HiveBoxes.varieties,
      HiveBoxes.fields,
      HiveBoxes.treatments,
      HiveBoxes.observations,
      HiveBoxes.alerts,
      HiveBoxes.users,
      HiveBoxes.farms,
      HiveBoxes.timeline,
      HiveBoxes.syncQueue,
      HiveBoxes.settings,
    ]) {
      _boxes[name] = await Hive.openBox<String>(name);
    }
  }

  Box<String> box(String name) => _boxes[name]!;

  Future<void> putMap(String boxName, String id, Map<String, dynamic> data) async {
    await box(boxName).put(id, jsonEncode(data));
  }

  Map<String, dynamic>? getMap(String boxName, String id) {
    final raw = box(boxName).get(id);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getAllMaps(String boxName) {
    return box(boxName)
        .values
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<void> delete(String boxName, String id) async => box(boxName).delete(id);

  Future<void> clearBox(String boxName) async => box(boxName).clear();

  Future<void> enqueueSync(Map<String, dynamic> op) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await putMap(HiveBoxes.syncQueue, id, {...op, 'queuedAt': DateTime.now().toIso8601String()});
  }

  List<Map<String, dynamic>> pendingSync() => getAllMaps(HiveBoxes.syncQueue);

  List<SyncQueueEntry> pendingSyncEntries() {
    final box = this.box(HiveBoxes.syncQueue);
    return box.keys
        .map((key) {
          final raw = box.get(key);
          if (raw == null) return null;
          return SyncQueueEntry(
            id: key.toString(),
            data: jsonDecode(raw) as Map<String, dynamic>,
          );
        })
        .whereType<SyncQueueEntry>()
        .toList();
  }

  Future<void> dequeueSync(String queueId) async => delete(HiveBoxes.syncQueue, queueId);

  int get pendingSyncCount => box(HiveBoxes.syncQueue).length;

  bool get seeded => prefs.getBool('seeded_v5') ?? false;
  Future<void> setSeeded() async => prefs.setBool('seeded_v5', true);

  String? get sessionUserId => prefs.getString('sessionUserId');
  Future<void> setSessionUserId(String? id) async {
    if (id == null) {
      await prefs.remove('sessionUserId');
    } else {
      await prefs.setString('sessionUserId', id);
    }
  }

  bool get darkMode => prefs.getBool('darkMode') ?? false;
  Future<void> setDarkMode(bool v) async => prefs.setBool('darkMode', v);

  bool get appTourSeen => prefs.getBool('appTourSeen_v1') ?? false;
  Future<void> setAppTourSeen([bool v = true]) async =>
      prefs.setBool('appTourSeen_v1', v);

  bool get notificationsEnabled => prefs.getBool('notificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool v) async =>
      prefs.setBool('notificationsEnabled', v);

  /// Default farm coords (Harare) — override later from settings/GPS.
  double get weatherLat => prefs.getDouble('weatherLat') ?? -17.8252;
  double get weatherLon => prefs.getDouble('weatherLon') ?? 31.0335;
  Future<void> setWeatherCoords(double lat, double lon) async {
    await prefs.setDouble('weatherLat', lat);
    await prefs.setDouble('weatherLon', lon);
  }
}
