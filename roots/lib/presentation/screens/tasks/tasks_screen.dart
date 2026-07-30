import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.urgent => RootsColors.red,
        TaskPriority.high => RootsColors.orange,
        TaskPriority.medium => RootsColors.blue,
        TaskPriority.low => RootsColors.muted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Create Task'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          if (wide) const Text('Task Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Includes manual tasks and auto-generated reminders from livestock, harvest and maintenance.',
              style: TextStyle(color: RootsColors.muted)),
          const SizedBox(height: 16),
          ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RootsCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: t.status == TaskStatus.completed,
                      onChanged: (v) async {
                        final next = t.copyWith(
                          status: v == true ? TaskStatus.completed : TaskStatus.pending,
                        );
                        await ref.read(appRepositoryProvider).saveTask(next);
                        bumpData(ref);
                      },
                    ),
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${t.assigneeName ?? 'Unassigned'} · Due ${DateFormat.yMMMd().format(t.dueDate)}'
                      '${t.sourceModule != null ? ' · ${t.sourceModule}' : ''}',
                    ),
                    trailing: StatusChip(label: t.priority.label, color: _priorityColor(t.priority)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create task'),
        content: TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull!;
    await ref.read(appRepositoryProvider).saveTask(FarmTask(
          id: ref.read(appRepositoryProvider).newId(),
          farmId: user.farmId,
          title: title.text.trim(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
          priority: TaskPriority.medium,
          status: TaskStatus.pending,
          createdAt: DateTime.now(),
        ));
    bumpData(ref);
  }
}

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 28),
        children: [
          if (wide) const Text('Smart Alerts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const EmptyState(icon: Icons.notifications_none, title: 'No alerts')
          else
            ...alerts.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RootsCard(
                    onTap: () async {
                      final user = ref.read(authStateProvider).valueOrNull;
                      if (user == null) return;
                      await ref.read(appRepositoryProvider).markAlertRead(a.id, user.farmId);
                      bumpData(ref);
                    },
                    color: a.read ? null : RootsColors.greenPale,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.notification_important,
                        color: a.read ? RootsColors.muted : RootsColors.greenDeep,
                      ),
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${a.message}\n${DateFormat.yMMMd().add_jm().format(a.createdAt)}'),
                      isThreeLine: true,
                      trailing: a.read ? null : const StatusChip(label: 'New', color: RootsColors.green),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final results = user == null
        ? <Map<String, String>>[]
        : ref.watch(appRepositoryProvider).search(user.farmId, _q);

    return Scaffold(
      appBar: AppBar(title: const Text('Search everything')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Animals, equipment, inventory, crops, workers…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? const EmptyState(icon: Icons.search, title: 'Type to search')
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final r = results[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(r['type']![0])),
                          title: Text(r['title']!),
                          subtitle: Text('${r['type']} · ${r['subtitle']}'),
                          onTap: () => context.push(r['route']!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
