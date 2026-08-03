import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/local_store.dart';
import '../../core/offline/sync_coordinator.dart';
import '../../core/offline/sync_service.dart';
import '../../core/permissions/permissions.dart';
import '../../data/repositories/app_repository.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/crop_entities.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/farm_user.dart';
import '../../domain/entities/shared_entities.dart';

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(localStoreProvider));
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider),
  );
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider),
  );
});

final syncStatusProvider = StateNotifierProvider<SyncStatusController, SyncStatus>((ref) {
  return SyncStatusController(ref);
});

class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.lastSync,
    this.pendingCount = 0,
    this.isOnline = true,
    this.lastError,
  });

  final bool isSyncing;
  final DateTime? lastSync;
  final int pendingCount;
  final bool isOnline;
  final String? lastError;

  SyncStatus copyWith({
    bool? isSyncing,
    DateTime? lastSync,
    int? pendingCount,
    bool? isOnline,
    String? lastError,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSync: lastSync ?? this.lastSync,
      pendingCount: pendingCount ?? this.pendingCount,
      isOnline: isOnline ?? this.isOnline,
      lastError: lastError,
    );
  }
}

class SyncStatusController extends StateNotifier<SyncStatus> {
  SyncStatusController(this._ref) : super(const SyncStatus());

  final Ref _ref;

  Future<void> refresh() async {
    final store = _ref.read(localStoreProvider);
    final sync = _ref.read(syncServiceProvider);
    state = state.copyWith(
      isSyncing: sync.isRunning,
      lastSync: sync.lastSync,
      pendingCount: store.pendingSyncCount,
      isOnline: await sync.isOnline,
      lastError: sync.lastError,
    );
  }

  Future<bool> syncNow() async {
    state = state.copyWith(isSyncing: true, lastError: null);
    final ok = await _ref.read(syncCoordinatorProvider).syncNow();
    await refresh();
    state = state.copyWith(isSyncing: false);
    if (ok) {
      _ref.read(dataVersionProvider.notifier).state++;
    }
    return ok;
  }
}

final authStateProvider =
    StateNotifierProvider<AuthController, AsyncValue<FarmUser?>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<FarmUser?>> {
  AuthController(this._ref) : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final Ref _ref;

  AppRepository get _repo => _ref.read(appRepositoryProvider);

  Future<void> _bootstrap() async {
    final user = _repo.currentUser();
    state = AsyncValue.data(user);
    if (user != null) {
      await _ref.read(syncStatusProvider.notifier).syncNow();
    }
  }

  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.login(email, password);
      if (user == null) {
        state = const AsyncValue.data(null);
        return 'Invalid email or password';
      }
      state = AsyncValue.data(user);
      await _ref.read(syncStatusProvider.notifier).refresh();
      _ref.read(dataVersionProvider.notifier).state++;
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return e.toString();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String farmName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.register(
        name: name,
        email: email,
        password: password,
        farmName: farmName,
      );
      state = AsyncValue.data(user);
      await _ref.read(syncStatusProvider.notifier).refresh();
      _ref.read(dataVersionProvider.notifier).state++;
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }

  void refresh() => state = AsyncValue.data(_repo.currentUser());
}

final permissionsProvider = Provider<Permissions?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return Permissions(user.role);
});

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(localStoreProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store)
      : super(_store.darkMode ? ThemeMode.dark : ThemeMode.light);

  final LocalStore _store;

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await _store.setDarkMode(next == ThemeMode.dark);
  }
}

final dataVersionProvider = StateProvider<int>((ref) => 0);

void bumpData(WidgetRef ref) {
  ref.read(dataVersionProvider.notifier).state++;
  ref.read(syncStatusProvider.notifier).refresh();
}

final animalsProvider = Provider<List<Animal>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).animals(user.farmId);
});

final equipmentProvider = Provider<List<EquipmentItem>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).equipment(user.farmId);
});

final inventoryProvider = Provider<List<InventoryItem>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).inventory(user.farmId);
});

final financeProvider = Provider<List<FinanceEntry>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).finance(user.farmId);
});

final tasksProvider = Provider<List<FarmTask>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).tasks(user.farmId);
});

final cropsProvider = Provider<List<CropPlot>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).crops(user.farmId);
});

final fieldsProvider = Provider<List<FarmField>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).fields(user.farmId);
});

final cropCatalogProvider = Provider<List<CropCatalogItem>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).cropCatalog(user.farmId);
});

final alertsProvider = Provider<List<FarmAlert>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).alerts(user.farmId);
});

final workersProvider = Provider<List<FarmUser>>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(appRepositoryProvider).workers(user.farmId);
});

final unreadAlertsProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).where((a) => !a.read).length;
});
