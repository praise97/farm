import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'local_store.dart';
import 'sync_service.dart';

/// Watches connectivity and triggers Firestore sync when internet returns.
class SyncCoordinator {
  SyncCoordinator(this._store, this._sync);

  final LocalStore _store;
  final SyncService _sync;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;
  void Function()? onSynced;

  void start() {
    if (!AppConstants.firebaseConfigured) return;

    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _scheduleSync();
    });

    _scheduleSync();
  }

  void stop() {
    _debounce?.cancel();
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> syncNow() async {
    final farmId = _currentFarmId();
    if (farmId == null) return false;
    final ok = await _sync.syncFarm(farmId);
    if (ok) {
      debugPrint('Roots: synced farm $farmId');
      onSynced?.call();
    }
    return ok;
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncNow());
    });
  }

  String? _currentFarmId() {
    final userId = _store.sessionUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    final user = _store.getMap(HiveBoxes.users, userId);
    return user?['farmId'] as String?;
  }
}
