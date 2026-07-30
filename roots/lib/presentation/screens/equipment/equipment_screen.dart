import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class EquipmentScreen extends ConsumerWidget {
  const EquipmentScreen({super.key});

  Color _condColor(EquipmentCondition c) => switch (c) {
        EquipmentCondition.excellent => RootsColors.green,
        EquipmentCondition.good => RootsColors.blue,
        EquipmentCondition.fair => RootsColors.gold,
        EquipmentCondition.poor => RootsColors.orange,
        EquipmentCondition.broken => RootsColors.red,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(equipmentProvider);
    final perms = ref.watch(permissionsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      floatingActionButton: perms?.canAddEquipment == true
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment'),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          if (wide)
            const Text('Equipment Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          HeroBanner(
            title: 'Machinery & Tools',
            subtitle: 'Track condition, warranty, service intervals and repair history.',
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const EmptyState(icon: Icons.agriculture, title: 'No equipment yet')
          else
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RootsCard(
                    onTap: () => _showDetail(context, ref, e),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: RootsColors.greyCard,
                          child: Icon(Icons.agriculture, color: RootsColors.navy),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${e.category.label} · ${e.currentLocation ?? 'No location'}',
                                  style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
                              if (e.nextServiceDate != null)
                                Text(
                                  'Next service: ${DateFormat.yMMMd().format(e.nextServiceDate!)}'
                                  '${e.serviceDue ? ' · DUE' : ''}',
                                  style: TextStyle(
                                    color: e.serviceDue ? RootsColors.red : RootsColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        StatusChip(label: e.condition.label, color: _condColor(e.condition)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref, EquipmentItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Serial: ${item.serialNumber ?? '—'}'),
            Text('Supplier: ${item.supplier ?? '—'}'),
            Text('Purchase: ${DateFormat.yMMMd().format(item.purchaseDate)} · \$${item.purchasePrice.toStringAsFixed(0)}'),
            Text('Location: ${item.currentLocation ?? '—'}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _logService(context, ref, item);
              },
              icon: const Icon(Icons.build),
              label: const Text('Log maintenance / service'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logService(BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final cost = TextEditingController(text: '50');
    final mechanic = TextEditingController();
    final work = TextEditingController(text: 'Routine service');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: work, decoration: const InputDecoration(labelText: 'Work done')),
            TextField(controller: mechanic, decoration: const InputDecoration(labelText: 'Mechanic')),
            TextField(controller: cost, decoration: const InputDecoration(labelText: 'Cost'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    final next = now.add(Duration(days: item.serviceIntervalDays));
    final repo = ref.read(appRepositoryProvider);
    await repo.saveEquipment(item.copyWith(lastServiceDate: now, nextServiceDate: next));
    await repo.saveFinance(FinanceEntry(
      id: const Uuid().v4(),
      farmId: item.farmId,
      type: FinanceType.expense,
      category: ExpenseCategory.repairs.name,
      description: 'Service: ${item.name} — ${work.text}',
      amount: double.tryParse(cost.text) ?? 0,
      date: now,
      relatedId: item.id,
    ));
    await repo.addAlert(FarmAlert(
      id: const Uuid().v4(),
      farmId: item.farmId,
      type: AlertType.equipmentService,
      title: 'Service logged',
      message: '${item.name} next service ${DateFormat.yMMMd().format(next)}',
      createdAt: now,
    ));
    bumpData(ref);
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final price = TextEditingController(text: '1000');
    final location = TextEditingController();
    var category = EquipmentCategory.tractor;
    var condition = EquipmentCondition.good;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add equipment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                DropdownButtonFormField<EquipmentCategory>(
                  value: category,
                  items: EquipmentCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                DropdownButtonFormField<EquipmentCondition>(
                  value: condition,
                  items: EquipmentCondition.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => condition = v!),
                  decoration: const InputDecoration(labelText: 'Condition'),
                ),
                TextField(controller: price, decoration: const InputDecoration(labelText: 'Purchase price'), keyboardType: TextInputType.number),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull!;
    final repo = ref.read(appRepositoryProvider);
    final now = DateTime.now();
    await repo.saveEquipment(EquipmentItem(
      id: repo.newId(),
      farmId: user.farmId,
      name: name.text.trim(),
      category: category,
      purchaseDate: now,
      purchasePrice: double.tryParse(price.text) ?? 0,
      condition: condition,
      currentLocation: location.text.trim().isEmpty ? null : location.text.trim(),
      nextServiceDate: now.add(const Duration(days: 90)),
      createdAt: now,
    ));
    bumpData(ref);
  }
}
