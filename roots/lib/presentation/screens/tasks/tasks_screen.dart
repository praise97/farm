import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/farm_user.dart';
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

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.pending => RootsColors.blue,
        TaskStatus.inProgress => RootsColors.gold,
        TaskStatus.awaitingReview => RootsColors.orange,
        TaskStatus.completed => RootsColors.green,
        TaskStatus.cancelled => RootsColors.muted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final tasks = ref.watch(myTasksProvider);
    final isSupervisor = perms?.isSupervisor ?? false;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      floatingActionButton: isSupervisor
          ? FloatingActionButton.extended(
              onPressed: () => _assignTask(context, ref),
              icon: const Icon(Icons.assignment_ind),
              label: const Text('Assign Task'),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          Text(
            isSupervisor ? 'Task Management' : 'My Tasks',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            isSupervisor
                ? 'Assign work to workers, review their notes, and mark tasks complete.'
                : 'Tasks assigned by your supervisor appear here with phone notifications.',
            style: const TextStyle(color: RootsColors.muted),
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const EmptyState(icon: Icons.task_alt, title: 'No tasks yet')
          else
            ...tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RootsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${isSupervisor ? (t.assigneeName ?? 'Unassigned') : 'Supervisor: ${t.assignedByName ?? '—'}'} · '
                            'Due ${DateFormat.yMMMd().format(t.dueDate)}',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              StatusChip(label: t.status.label, color: _statusColor(t.status)),
                              StatusChip(label: t.priority.label, color: _priorityColor(t.priority)),
                            ],
                          ),
                        ),
                        if (t.description != null && t.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(t.description!, style: const TextStyle(fontSize: 13)),
                          ),
                        if (t.workerNotes != null)
                          Text('Worker notes: ${t.workerNotes}',
                              style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
                        if (t.supervisorNotes != null)
                          Text('Supervisor review: ${t.supervisorNotes}',
                              style: const TextStyle(color: RootsColors.greenDeep, fontSize: 12)),
                        const SizedBox(height: 8),
                        if (!isSupervisor && t.status != TaskStatus.completed)
                          FilledButton.tonal(
                            onPressed: () => _completeAsWorker(context, ref, t),
                            child: Text(t.status == TaskStatus.awaitingReview
                                ? 'Awaiting supervisor review'
                                : 'Mark work complete'),
                          ),
                        if (isSupervisor && t.needsSupervisorReview)
                          FilledButton(
                            onPressed: () => _reviewTask(context, ref, t),
                            child: const Text('Review & mark complete'),
                          ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _assignTask(BuildContext context, WidgetRef ref) async {
    final supervisor = ref.read(authStateProvider).valueOrNull!;
    final workers = ref
        .read(workersProvider)
        .where((w) => w.role == UserRole.worker || w.role == UserRole.manager)
        .toList();
    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create worker accounts first (Workers screen).')),
      );
      return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    FarmUser assignee = workers.first;
    var priority = TaskPriority.medium;
    var due = DateTime.now().add(const Duration(days: 3));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Assign task to worker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FarmUser>(
                  key: ValueKey(assignee.id),
                  initialValue: assignee,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: workers
                      .map((w) => DropdownMenuItem(value: w, child: Text('${w.name} (${w.role.label})')))
                      .toList(),
                  onChanged: (v) => setLocal(() => assignee = v!),
                ),
                DropdownButtonFormField<TaskPriority>(
                  key: ValueKey(priority),
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: TaskPriority.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => priority = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(DateFormat.yMMMd().format(due)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: due,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setLocal(() => due = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    final repo = ref.read(appRepositoryProvider);
    final task = FarmTask(
      id: repo.newId(),
      farmId: supervisor.farmId,
      title: title.text.trim(),
      description: description.text.trim().isEmpty ? null : description.text.trim(),
      dueDate: due,
      priority: priority,
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
    );
    await repo.assignTask(task: task, supervisor: supervisor, assignee: assignee);
    bumpData(ref);
  }

  Future<void> _completeAsWorker(BuildContext context, WidgetRef ref, FarmTask task) async {
    if (task.status == TaskStatus.awaitingReview) return;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit completed work'),
        content: TextField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'Work notes / performance notes',
            hintText: 'What did you do? Any issues?',
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appRepositoryProvider).completeTaskByWorker(
          task: task,
          workerNotes: notes.text.trim(),
        );
    bumpData(ref);
  }

  Future<void> _reviewTask(BuildContext context, WidgetRef ref, FarmTask task) async {
    final notes = TextEditingController(text: task.workerNotes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review worker performance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.workerNotes != null)
              Text('Worker notes: ${task.workerNotes}',
                  style: const TextStyle(color: RootsColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Supervisor review notes'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark complete')),
        ],
      ),
    );
    if (ok != true) return;
    final supervisor = ref.read(authStateProvider).valueOrNull!;
    await ref.read(appRepositoryProvider).reviewTaskBySupervisor(
          task: task,
          supervisorNotes: notes.text.trim(),
          supervisor: supervisor,
        );
    bumpData(ref);
  }
}

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(userAlertsProvider);
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
                      if (a.relatedId != null && a.type == AlertType.taskAssigned) {
                        if (context.mounted) context.go('/tasks');
                      }
                    },
                    color: a.read ? null : RootsColors.greenPale,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        a.type == AlertType.taskAssigned || a.type == AlertType.taskReviewed
                            ? Icons.assignment
                            : Icons.notification_important,
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
