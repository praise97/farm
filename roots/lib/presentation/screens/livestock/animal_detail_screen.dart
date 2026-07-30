import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/animal.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class AnimalDetailScreen extends ConsumerWidget {
  const AnimalDetailScreen({super.key, required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataVersionProvider);
    final repo = ref.watch(appRepositoryProvider);
    final animal = repo.animal(animalId);
    if (animal == null) {
      return const Scaffold(body: Center(child: Text('Animal not found')));
    }
    final events = repo.timelineFor(animalId);
    final weights = events
        .where((e) => e.type == TimelineEventType.weightRecord)
        .toList()
        .reversed
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(animal.tagNumber),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.push('/livestock/$animalId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventSheet(context, ref, animal),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 28 : 16, 100),
        children: [
          RootsCard(
            gradient: RootsColors.tealCardGradient,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(animal.tagNumber,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${animal.breed} · ${animal.category} · ${animal.gender.label}',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 14),
                      const Text('Current weight', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${animal.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      Text('Age ${animal.ageLabel} · ${animal.location ?? 'No location'}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                QrImageView(
                  data: animal.qrCode ?? animal.tagNumber,
                  size: 96,
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: animal.status.label, color: RootsColors.greenDeep),
              if (animal.colour != null) StatusChip(label: animal.colour!, color: RootsColors.blue),
              StatusChip(label: 'Owner: ${animal.currentOwner}', color: RootsColors.muted),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: 'Quick Records'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.vaccines),
                label: const Text('Vaccination'),
                onPressed: () => _quickEvent(context, ref, animal, TimelineEventType.vaccination, 'Vaccination'),
              ),
              ActionChip(
                avatar: const Icon(Icons.medication),
                label: const Text('Deworming'),
                onPressed: () => _quickEvent(context, ref, animal, TimelineEventType.deworming, 'Deworming'),
              ),
              ActionChip(
                avatar: const Icon(Icons.monitor_weight),
                label: const Text('Weight'),
                onPressed: () => _addWeight(context, ref, animal),
              ),
              ActionChip(
                avatar: const Icon(Icons.favorite),
                label: const Text('Breeding'),
                onPressed: () => _quickEvent(context, ref, animal, TimelineEventType.breeding, 'Breeding record'),
              ),
              ActionChip(
                avatar: const Icon(Icons.healing),
                label: const Text('Health'),
                onPressed: () => _quickEvent(context, ref, animal, TimelineEventType.disease, 'Health / disease'),
              ),
            ],
          ),
          if (weights.isNotEmpty) ...[
            SectionHeader(title: 'Growth Graph'),
            RootsCard(
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= weights.length) return const SizedBox.shrink();
                            return Text(DateFormat('MM/dd').format(weights[i].date),
                                style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < weights.length; i++)
                            FlSpot(i.toDouble(), (weights[i].meta['weight'] as num?)?.toDouble() ?? animal.weight),
                        ],
                        isCurved: true,
                        color: RootsColors.teal,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SectionHeader(title: 'Animal Timeline'),
          if (events.isEmpty)
            const EmptyState(icon: Icons.timeline, title: 'No timeline events yet')
          else
            ...events.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RootsCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: RootsColors.greenPale,
                          child: Icon(_iconFor(e.type), color: RootsColors.greenDeep, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (e.notes != null)
                                Text(e.notes!, style: const TextStyle(color: RootsColors.muted, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.yMMMd().format(e.date),
                                style: const TextStyle(fontSize: 12, color: RootsColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(e.type.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  IconData _iconFor(TimelineEventType t) => switch (t) {
        TimelineEventType.vaccination => Icons.vaccines,
        TimelineEventType.deworming => Icons.medication,
        TimelineEventType.weightRecord => Icons.monitor_weight,
        TimelineEventType.disease || TimelineEventType.treatment => Icons.healing,
        TimelineEventType.breeding || TimelineEventType.pregnancy || TimelineEventType.calving => Icons.favorite,
        TimelineEventType.sale || TimelineEventType.death => Icons.flag,
        _ => Icons.timeline,
      };

  Future<void> _quickEvent(
    BuildContext context,
    WidgetRef ref,
    Animal animal,
    TimelineEventType type,
    String title,
  ) async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(appRepositoryProvider);
    await repo.addTimelineEvent(AnimalTimelineEvent(
      id: repo.newId(),
      animalId: animal.id,
      farmId: animal.farmId,
      type: type,
      title: title,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      date: DateTime.now(),
    ));
    if (type == TimelineEventType.disease) {
      await repo.saveAnimal(animal.copyWith(status: AnimalStatus.sick, updatedAt: DateTime.now()));
    }
    bumpData(ref);
  }

  Future<void> _addWeight(BuildContext context, WidgetRef ref, Animal animal) async {
    final ctrl = TextEditingController(text: animal.weight.toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record weight'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final w = double.tryParse(ctrl.text);
    if (w == null) return;
    final repo = ref.read(appRepositoryProvider);
    await repo.saveAnimal(animal.copyWith(weight: w, updatedAt: DateTime.now()));
    await repo.addTimelineEvent(AnimalTimelineEvent(
      id: repo.newId(),
      animalId: animal.id,
      farmId: animal.farmId,
      type: TimelineEventType.weightRecord,
      title: 'Weight ${w.toStringAsFixed(1)} kg',
      date: DateTime.now(),
      meta: {'weight': w},
    ));
    bumpData(ref);
  }

  Future<void> _showAddEventSheet(BuildContext context, WidgetRef ref, Animal animal) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in [
              TimelineEventType.vaccination,
              TimelineEventType.deworming,
              TimelineEventType.treatment,
              TimelineEventType.breeding,
              TimelineEventType.pregnancy,
              TimelineEventType.calving,
              TimelineEventType.milkProduction,
              TimelineEventType.movement,
              TimelineEventType.sale,
              TimelineEventType.death,
            ])
              ListTile(
                leading: Icon(_iconFor(t)),
                title: Text(t.label),
                onTap: () {
                  Navigator.pop(ctx);
                  _quickEvent(context, ref, animal, t, t.label);
                },
              ),
          ],
        ),
      ),
    );
  }
}
