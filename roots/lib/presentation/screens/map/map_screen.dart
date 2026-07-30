import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final points = [
      (MapPointType.field, 'Field A — Wheat', -17.8252, 31.0335),
      (MapPointType.field, 'Field B — Corn', -17.8260, 31.0350),
      (MapPointType.waterPoint, 'Borehole 1', -17.8245, 31.0320),
      (MapPointType.animalPen, 'Pen A', -17.8270, 31.0340),
      (MapPointType.building, 'Machinery Shed', -17.8238, 31.0315),
      (MapPointType.animalPen, 'Goat Shed', -17.8275, 31.0330),
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Farm Map', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Store GPS points for fields, water, buildings, pens and roads.',
              style: TextStyle(color: RootsColors.muted)),
          const SizedBox(height: 16),
          RootsCard(
            gradient: RootsColors.heroGradient,
            child: const SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text('Interactive map overlay',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('Harare demo coordinates', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...points.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: RootsColors.greenPale,
                  child: Icon(_icon(p.$1), color: RootsColors.greenDeep),
                ),
                title: Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.$1.label} · ${p.$3.toStringAsFixed(4)}, ${p.$4.toStringAsFixed(4)}'),
              )),
        ],
      ),
    );
  }

  IconData _icon(MapPointType t) => switch (t) {
        MapPointType.field => Icons.grass,
        MapPointType.waterPoint => Icons.water_drop,
        MapPointType.building => Icons.home_work,
        MapPointType.animalPen => Icons.fence,
        MapPointType.road => Icons.alt_route,
        MapPointType.gps => Icons.my_location,
      };
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animals = ref.watch(animalsProvider);
    final equipment = ref.watch(equipmentProvider);
    final inventory = ref.watch(inventoryProvider);
    final finance = ref.watch(financeProvider);
    final crops = ref.watch(cropsProvider);

    final reports = [
      ('Livestock Report', '${animals.length} animals', Icons.pets, '/livestock'),
      ('Equipment Report', '${equipment.length} assets', Icons.agriculture, '/equipment'),
      ('Inventory Report', '${inventory.length} items · \$${inventory.fold<double>(0, (s, i) => s + i.stockValue).toStringAsFixed(0)} value', Icons.inventory_2, '/inventory'),
      ('Financial Report', '${finance.length} entries', Icons.assessment, '/finance'),
      ('Crop Report', '${crops.length} plots', Icons.grass, '/crops'),
      ('Weather Report', 'Harare forecast snapshot', Icons.cloud, '/map'),
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Reports & Export', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Generate PDF, Excel and CSV exports for farm records.',
              style: TextStyle(color: RootsColors.muted)),
          const SizedBox(height: 16),
          ...reports.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RootsCard(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${r.$1}: export helpers ready (pdf/excel/csv packages included).')),
                    );
                    context.go(r.$4);
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: RootsColors.mintCard,
                      child: Icon(r.$3, color: RootsColors.greenDeep),
                    ),
                    title: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(r.$2),
                    trailing: const Icon(Icons.file_download_outlined),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersProvider);
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      floatingActionButton: perms?.canInviteWorkers == true
          ? FloatingActionButton.extended(
              onPressed: () => _invite(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Worker'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('User Accounts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Each farm has one Owner. Managers and Workers have different permissions.',
              style: TextStyle(color: RootsColors.muted)),
          const SizedBox(height: 16),
          ...workers.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RootsCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: RootsColors.sidebarAccent,
                      child: Text(w.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${w.email}\n${w.role.label}'),
                    isThreeLine: true,
                    trailing: StatusChip(
                      label: w.role.label,
                      color: w.role == UserRole.owner
                          ? RootsColors.greenDeep
                          : w.role == UserRole.manager
                              ? RootsColors.blue
                              : RootsColors.muted,
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    var role = UserRole.worker;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Invite worker'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              DropdownButtonFormField<UserRole>(
                value: role,
                items: [UserRole.manager, UserRole.worker]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (v) => setLocal(() => role = v!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invite')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final user = ref.read(authStateProvider).valueOrNull!;
    await ref.read(appRepositoryProvider).addWorker(
          farmId: user.farmId,
          name: name.text.trim(),
          email: email.text.trim(),
          role: role,
        );
    bumpData(ref);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final theme = ref.watch(themeModeProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          RootsCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(user?.initials ?? 'R')),
              title: Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${user?.email}\nRole: ${user?.role.label} · Farm: ${user?.farmId}'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: theme == ThemeMode.dark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          ListTile(
            leading: Icon(
              syncStatus.isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: syncStatus.isOnline ? RootsColors.green : RootsColors.orange,
            ),
            title: Text(syncStatus.isOnline ? 'Online — auto sync active' : 'Offline — changes saved locally'),
            subtitle: Text(
              syncStatus.isSyncing
                  ? 'Syncing…'
                  : '${syncStatus.pendingCount} pending · Last sync: '
                      '${syncStatus.lastSync == null ? 'never' : syncStatus.lastSync!.toLocal().toString().substring(0, 16)}',
            ),
            trailing: IconButton(
              tooltip: 'Sync now',
              onPressed: syncStatus.isSyncing
                  ? null
                  : () async {
                      final ok = await ref.read(syncStatusProvider.notifier).syncNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Synced with Firestore' : 'Sync failed or offline')),
                        );
                      }
                    },
              icon: const Icon(Icons.sync),
            ),
          ),
          if (syncStatus.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(syncStatus.lastError!, style: const TextStyle(color: RootsColors.red, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
