import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/animal.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class LivestockListScreen extends ConsumerStatefulWidget {
  const LivestockListScreen({super.key});

  @override
  ConsumerState<LivestockListScreen> createState() => _LivestockListScreenState();
}

class _LivestockListScreenState extends ConsumerState<LivestockListScreen> {
  String _query = '';
  AnimalStatus? _status;

  Color _statusColor(AnimalStatus s) => switch (s) {
        AnimalStatus.alive => RootsColors.green,
        AnimalStatus.pregnant => RootsColors.blue,
        AnimalStatus.sick => RootsColors.orange,
        AnimalStatus.quarantined => RootsColors.gold,
        AnimalStatus.missing => RootsColors.red,
        AnimalStatus.sold => RootsColors.muted,
        AnimalStatus.dead => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final animals = ref.watch(animalsProvider).where((a) {
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty ||
          a.tagNumber.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q);
      final matchesStatus = _status == null || a.status == _status;
      return matchesQuery && matchesStatus;
    }).toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/livestock/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Animal'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              const Text('Livestock Management',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            HeroBanner(
              title: 'Herd Overview',
              subtitle: '${ref.watch(animalsProvider).length} animals tracked with QR tags, timelines and health records.',
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search tag, breed, category…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  const SizedBox(width: 8),
                  for (final s in AnimalStatus.values) ...[
                    FilterChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: animals.isEmpty
                  ? const EmptyState(
                      icon: Icons.pets,
                      title: 'No animals found',
                      subtitle: 'Add your first animal or clear filters.',
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wide ? 3 : MediaQuery.sizeOf(context).width > 600 ? 2 : 1,
                        mainAxisExtent: 168,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: animals.length,
                      itemBuilder: (context, i) => _AnimalCard(
                        animal: animals[i],
                        color: _statusColor(animals[i].status),
                        onTap: () => context.push('/livestock/${animals[i].id}'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.animal, required this.color, required this.onTap});

  final Animal animal;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RootsCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.pets, color: color),
              ),
              const Spacer(),
              StatusChip(label: animal.status.label, color: color),
            ],
          ),
          const Spacer(),
          Text(animal.tagNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${animal.breed} · ${animal.category}',
              style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text('${animal.weight.toStringAsFixed(0)} kg · ${animal.ageLabel} · ${animal.location ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
