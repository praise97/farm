import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final low = items.where((i) => i.isLowStock).length;
    final near = items.where((i) => i.isNearExpiry).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          if (wide)
            const Text('Inventory', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Items', value: '${items.length}', icon: Icons.inventory_2)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Low stock', value: '$low', changePositive: low == 0, icon: Icons.warning_amber)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Near expiry', value: '$near', icon: Icons.hourglass_bottom)),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RootsCard(
                  onTap: () => _adjust(context, ref, item),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              '${item.category.label} · ${item.storageLocation ?? '—'}',
                              style: const TextStyle(color: RootsColors.muted, fontSize: 12),
                            ),
                            Text(
                              '${item.quantity} ${item.unit} · min ${item.minimumStock}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.isLowStock) const StatusChip(label: 'Low', color: RootsColors.red),
                          if (item.isNearExpiry) const StatusChip(label: 'Near expiry', color: RootsColors.orange),
                          if (item.isExpired) const StatusChip(label: 'Expired', color: RootsColors.red),
                          Text('\$${item.stockValue.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, InventoryItem item) async {
    final qty = TextEditingController(text: item.quantity.toString());
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: qty,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Quantity (${item.unit})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'out'), child: const Text('Stock Out')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'set'), child: const Text('Set Qty')),
        ],
      ),
    );
    if (action == null) return;
    final value = double.tryParse(qty.text);
    if (value == null) return;
    final repo = ref.read(appRepositoryProvider);
    final next = action == 'out'
        ? item.copyWith(quantity: (item.quantity - value).clamp(0, 1e9), updatedAt: DateTime.now())
        : item.copyWith(quantity: value, updatedAt: DateTime.now());
    await repo.saveInventory(next);
    if (next.isLowStock) {
      await repo.addAlert(FarmAlert(
        id: repo.newId(),
        farmId: item.farmId,
        type: AlertType.lowStock,
        title: 'Low Stock',
        message: '${item.name} is at ${next.quantity} ${item.unit}',
        createdAt: DateTime.now(),
      ));
    }
    bumpData(ref);
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final qty = TextEditingController(text: '10');
    final unit = TextEditingController(text: 'bags');
    final min = TextEditingController(text: '5');
    final cost = TextEditingController(text: '20');
    var category = InventoryCategory.animalFeed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add inventory item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                DropdownButtonFormField<InventoryCategory>(
                  value: category,
                  items: InventoryCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(controller: qty, decoration: const InputDecoration(labelText: 'Quantity')),
                TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')),
                TextField(controller: min, decoration: const InputDecoration(labelText: 'Minimum stock')),
                TextField(controller: cost, decoration: const InputDecoration(labelText: 'Cost price')),
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
    await ref.read(appRepositoryProvider).saveInventory(InventoryItem(
          id: ref.read(appRepositoryProvider).newId(),
          farmId: user.farmId,
          name: name.text.trim(),
          category: category,
          quantity: double.tryParse(qty.text) ?? 0,
          unit: unit.text.trim(),
          minimumStock: double.tryParse(min.text) ?? 0,
          costPrice: double.tryParse(cost.text) ?? 0,
          updatedAt: DateTime.now(),
        ));
    bumpData(ref);
  }
}
