import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/enums.dart';
import '../../../core/services/animal_photo_service.dart';
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
          if (animal.needsPhotoRefresh && !animal.isTerminal)
            RootsCard(
              color: const Color(0xFFFFF3E8),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, color: RootsColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Yearly photo update due',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          animal.photosUpdatedAt == null
                              ? 'Capture 2 new photos. Old images are deleted when you update.'
                              : 'Last photos: ${DateFormat.yMMMd().format(animal.photosUpdatedAt!)}. Take 2 new photos — old ones are removed from storage.',
                          style: const TextStyle(color: RootsColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/livestock/$animalId/edit'),
                    child: const Text('Update'),
                  ),
                ],
              ),
            ),
          if (!animal.isTerminal &&
              (animal.photo1Url != null || animal.photo2Url != null)) ...[
            const SizedBox(height: 12),
            SectionHeader(title: 'Photos'),
            Row(
              children: [
                for (final url in [animal.photo1Url, animal.photo2Url])
                  if (url != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _AnimalPhotoImage(url: url),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _VaccinationSummaryCard(animalId: animalId, farmId: animal.farmId),
          const SizedBox(height: 8),
          SectionHeader(title: 'Quick Records'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.vaccines),
                label: const Text('Vaccination'),
                onPressed: () => _addVaccination(context, ref, animal),
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
          SectionHeader(title: 'Growth Graph', live: true),
          RootsCard(
            child: SizedBox(
              height: 200,
              child: _WeightLineChart(
                key: ValueKey('weights-${weights.length}-${animal.weight}'),
                weights: weights,
                currentWeight: animal.weight,
              ),
            ),
          ),
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

  Future<void> _addVaccination(BuildContext context, WidgetRef ref, Animal animal) async {
    final vaccine = TextEditingController(text: 'FMD');
    final notes = TextEditingController();
    DateTime nextDue = DateTime.now().add(const Duration(days: 180));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record vaccination'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vaccine,
                decoration: const InputDecoration(labelText: 'Vaccine name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes / vet'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next due date'),
                subtitle: Text(DateFormat.yMMMd().format(nextDue)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: nextDue,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 800)),
                  );
                  if (picked != null) setLocal(() => nextDue = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final repo = ref.read(appRepositoryProvider);
    await repo.addTimelineEvent(AnimalTimelineEvent(
      id: repo.newId(),
      animalId: animal.id,
      farmId: animal.farmId,
      type: TimelineEventType.vaccination,
      title: '${vaccine.text.trim()} Vaccination',
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      date: DateTime.now(),
      meta: {
        'vaccine': vaccine.text.trim(),
        'nextDue': nextDue.toIso8601String(),
      },
    ));
    await repo.scanVaccinationDue(animal.farmId);
    bumpData(ref);
  }

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
      await repo.saveAnimal(animal.copyWith(status: AnimalStatus.sick, updatedAt: DateTime.now()),
          previous: animal);
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
    await repo.saveAnimal(animal.copyWith(weight: w, updatedAt: DateTime.now()), previous: animal);
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
                  if (t == TimelineEventType.vaccination) {
                    _addVaccination(context, ref, animal);
                  } else {
                    _quickEvent(context, ref, animal, t, t.label);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _VaccinationSummaryCard extends ConsumerWidget {
  const _VaccinationSummaryCard({required this.animalId, required this.farmId});

  final String animalId;
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataVersionProvider);
    final info = ref.watch(appRepositoryProvider).vaccinationForAnimal(animalId);
    final due = info?.nextDue;
    final overdue = info?.isOverdue ?? false;
    final thisMonth = info?.dueThisMonth ?? false;

    Color banner = RootsColors.greenPale;
    String headline = 'No vaccination on record';
    String detail = 'Tap Vaccination to log the first shot and set the next due date.';
    if (info?.last != null) {
      headline = info!.last!.title;
      if (due != null) {
        detail = overdue
            ? 'OVERDUE since ${DateFormat.yMMMd().format(due)} — vaccinate now'
            : thisMonth
                ? 'Must be vaccinated this month · due ${DateFormat.yMMMd().format(due)}'
                : 'Next due ${DateFormat.yMMMd().format(due)}';
        banner = overdue
            ? const Color(0xFFFFEBEE)
            : thisMonth
                ? const Color(0xFFFFF3E8)
                : RootsColors.greenPale;
      } else {
        detail = 'Last given ${DateFormat.yMMMd().format(info.last!.date)} · set a next due date next time';
      }
    }

    return RootsCard(
      color: banner,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.vaccines,
            color: overdue ? RootsColors.red : RootsColors.greenDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vaccination summary',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(color: RootsColors.muted, fontSize: 13)),
                if (thisMonth || overdue) ...[
                  const SizedBox(height: 8),
                  StatusChip(
                    label: overdue ? 'Alert: overdue' : 'Alert: due this month',
                    color: overdue ? RootsColors.red : RootsColors.orange,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalPhotoImage extends StatelessWidget {
  const _AnimalPhotoImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final provider = AnimalPhotoService.instance.imageProvider(url);
    if (provider == null) {
      return Container(color: RootsColors.bg, child: const Icon(Icons.image_not_supported));
    }
    return Image(image: provider, fit: BoxFit.cover);
  }
}

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({
    super.key,
    required this.weights,
    required this.currentWeight,
  });

  final List<AnimalTimelineEvent> weights;
  final double currentWeight;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < weights.length; i++) {
      spots.add(FlSpot(
        i.toDouble(),
        (weights[i].meta['weight'] as num?)?.toDouble() ?? currentWeight,
      ));
      labels.add(DateFormat('MM/dd').format(weights[i].date));
    }
    if (spots.isEmpty) {
      spots.add(FlSpot(0, currentWeight));
      labels.add('Now');
    } else {
      final last = spots.last.y;
      if ((last - currentWeight).abs() > 0.05) {
        spots.add(FlSpot(spots.length.toDouble(), currentWeight));
        labels.add('Now');
      }
    }

    return LineChart(
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
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Text(labels[i], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: RootsColors.teal,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: RootsColors.teal.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
    );
  }
}
