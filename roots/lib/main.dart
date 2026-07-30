import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/offline/local_store.dart';
import 'core/offline/sync_coordinator.dart';
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

  runApp(const ProviderScope(child: RootsApp()));
}

class RootsApp extends ConsumerWidget {
  const RootsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return SyncBootstrap(
      child: MaterialApp.router(
        title: 'Roots',
        debugShowCheckedModeBanner: false,
        theme: RootsTheme.light(),
        darkTheme: RootsTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coordinator = ref.read(syncCoordinatorProvider);
      coordinator.onSynced = () {
        ref.read(syncStatusProvider.notifier).refresh();
        ref.read(dataVersionProvider.notifier).state++;
      };
      coordinator.start();
      ref.read(syncStatusProvider.notifier).refresh();
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
