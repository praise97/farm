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

class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersProvider);
    final perms = ref.watch(permissionsProvider);
    final isSupervisor = perms?.canCreateWorkerAccounts ?? false;

    return Scaffold(
      floatingActionButton: isSupervisor
          ? FloatingActionButton.extended(
              onPressed: () => _createAccount(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Create Account'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Staff & User Accounts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            isSupervisor
                ? 'Create worker (pwd 12345) or admin/supervisor (pwd admin123). All can reset in Settings.'
                : 'Your farm team — contact your supervisor for account changes.',
            style: const TextStyle(color: RootsColors.muted),
          ),
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
                    subtitle: Text(
                      '${w.email}\n${w.role.label}'
                      '${w.role == UserRole.worker ? ' · default pwd 12345' : ''}'
                      '${w.role == UserRole.manager ? ' · default pwd admin123' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: StatusChip(
                      label: w.role == UserRole.owner || w.role == UserRole.manager ? 'Supervisor' : 'Worker',
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

  Future<void> _createAccount(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    var role = UserRole.worker;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final defaultPwd = role == UserRole.worker ? '12345' : 'admin123';
          return AlertDialog(
            title: const Text('Create user account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Default password: $defaultPwd\nUser can change it in Settings after first login.',
                  style: const TextStyle(color: RootsColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                DropdownButtonFormField<UserRole>(
                  key: ValueKey(role),
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: UserRole.worker, child: Text('Worker (non-admin)')),
                    DropdownMenuItem(value: UserRole.manager, child: Text('Admin / Supervisor')),
                  ],
                  onChanged: (v) => setLocal(() => role = v!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
            ],
          );
        },
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !email.text.contains('@')) return;
    final supervisor = ref.read(authStateProvider).valueOrNull!;
    final defaultPwd = role == UserRole.worker ? '12345' : 'admin123';
    try {
      await ref.read(appRepositoryProvider).createWorkerAccount(
            farmId: supervisor.farmId,
            name: name.text.trim(),
            email: email.text.trim(),
            role: role,
            createdById: supervisor.id,
          );
      bumpData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created. ${name.text.trim()} can log in with password $defaultPwd')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final perms = ref.watch(permissionsProvider);
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
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change password'),
            subtitle: Text(
              perms?.isWorker == true
                  ? 'Workers: default was 12345 — set your own password here'
                  : perms?.isManager == true
                      ? 'Admins: default was admin123 — set your own password here'
                      : 'Update your login password',
            ),
            onTap: () => _changePasswordDialog(context, ref),
          ),
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

Future<void> _changePasswordDialog(BuildContext context, WidgetRef ref) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          TextField(
            controller: next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok != true) return;
  if (next.text != confirm.text) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
    }
    return;
  }
  final err = await ref.read(authStateProvider.notifier).changePassword(current.text, next.text);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Password updated')),
    );
  }
}
