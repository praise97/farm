import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import 'core/notifications/notification_service.dart';
import 'core/offline/local_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/roots_theme.dart';
import 'data/seed/demo_seed.dart';
import 'firebase_bootstrap.dart';
import 'presentation/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.instance.init();
  await seedDemoData();
  await initializeFirebase();
  await restoreFirebaseSession();
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: RootsApp()));
}

class RootsApp extends ConsumerWidget {
  const RootsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ShowCaseWidget(
      builder: (context) => SyncBootstrap(
        child: MaterialApp.router(
          title: 'Roots',
          debugShowCheckedModeBanner: false,
          theme: RootsTheme.light(),
          darkTheme: RootsTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}

class SyncBootstrap extends ConsumerStatefulWidget {
  const SyncBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<SyncBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final coordinator = ref.read(syncCoordinatorProvider);
      coordinator.onSynced = () {
        ref.read(syncStatusProvider.notifier).refresh();
        ref.read(dataVersionProvider.notifier).state++;
      };
      coordinator.start();
      ref.read(syncStatusProvider.notifier).refresh();

      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        final repo = ref.read(appRepositoryProvider);
        final vax = await repo.scanVaccinationDue(user.farmId);
        final photos = await repo.scanPhotoRefreshDue(user.farmId);
        if (vax > 0 || photos > 0) bumpData(ref);
      }
    });
  }

  @override
  void dispose() {
    ref.read(syncCoordinatorProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
