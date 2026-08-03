import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/crop_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

/// Crop Management — partner MySQL/Postgres schema ported to Firebase + Hive.
class CropsScreen extends ConsumerStatefulWidget {
  const CropsScreen({super.key});

  @override
  ConsumerState<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends ConsumerState<CropsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crops = ref.watch(cropsProvider);
    final fields = ref.watch(fieldsProvider);
    final catalog = ref.watch(cropCatalogProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final moisture = crops.isEmpty
        ? 0.0
        : crops.map((c) => c.soilMoisture ?? 0).reduce((a, b) => a + b) / crops.length;
    final pestAlerts = crops.where((c) => c.pestPresence || c.diseasePresence).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlanting(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Planting'),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    const Text('Crop Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  HeroBanner(
                    title: 'Zimbabwe Crop Dashboard',
                    subtitle: 'Fields, plantings, treatments & observations — synced via Firebase.',
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 800 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.55,
                        children: [
                          StatCard(label: 'Active Crop Plots', value: '${crops.length}', changePositive: true, icon: Icons.grid_view),
                          StatCard(label: 'Avg Soil Moisture', value: '${moisture.toStringAsFixed(0)}%', icon: Icons.water_drop),
                          StatCard(label: 'Fields', value: '${fields.length}', icon: Icons.map_outlined),
                          StatCard(label: 'Pest / Disease', value: '$pestAlerts', accent: true, icon: Icons.bug_report_outlined),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    labelColor: RootsColors.greenDeep,
                    tabs: const [
                      Tab(text: 'Active crops'),
                      Tab(text: 'Fields'),
                      Tab(text: 'Catalog'),
                      Tab(text: 'Market'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _ActiveCropsTab(crops: crops),
            _FieldsTab(fields: fields, onAdd: () => _addField(context)),
            _CatalogTab(catalog: catalog),
            const _MarketTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlanting(BuildContext context) async {
    final fields = ref.read(fieldsProvider);
    final varieties = ref.read(appRepositoryProvider).varieties(
          ref.read(authStateProvider).valueOrNull!.farmId,
        );
    final name = TextEditingController();
    final moisture = TextEditingController(text: '65');
    FarmField? field = fields.isEmpty ? null : fields.first;
    CropVariety? variety = varieties.isEmpty ? null : varieties.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add planting'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Plot label (optional)')),
                if (fields.isNotEmpty)
                  DropdownButtonFormField<FarmField>(
                    value: field,
                    items: fields.map((f) => DropdownMenuItem(value: f, child: Text(f.fieldName))).toList(),
                    onChanged: (v) => setLocal(() => field = v),
                    decoration: const InputDecoration(labelText: 'Field'),
                  ),
                if (varieties.isNotEmpty)
                  DropdownButtonFormField<CropVariety>(
                    value: variety,
                    items: varieties.map((v) => DropdownMenuItem(value: v, child: Text(v.varietyName))).toList(),
                    onChanged: (v) => setLocal(() => variety = v),
                    decoration: const InputDecoration(labelText: 'Variety'),
                  ),
                TextField(controller: moisture, decoration: const InputDecoration(labelText: 'Soil moisture %'), keyboardType: TextInputType.number),
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
    if (ok != true) return;
    final user = ref.read(authStateProvider).valueOrNull!;
    final repo = ref.read(appRepositoryProvider);
    final cropName = variety != null
        ? ref.read(cropCatalogProvider).cast<CropCatalogItem?>().firstWhere(
              (c) => c!.id == variety!.cropId,
              orElse: () => null,
            )?.cropName ??
            'Crop'
        : 'Crop';
    final maturity = variety?.daysToMaturity ?? 120;
    final planted = DateTime.now();
    await repo.saveCrop(CropPlot(
      id: repo.newId(),
      farmId: user.farmId,
      name: name.text.trim().isEmpty
          ? '$cropName — ${field?.fieldName ?? 'Field'}'
          : name.text.trim(),
      cropType: cropName,
      fieldId: field?.id,
      fieldName: field?.fieldName,
      varietyId: variety?.id,
      varietyName: variety?.varietyName,
      growthPercent: 0,
      soilMoisture: double.tryParse(moisture.text),
      statusNote: 'Newly planted',
      plantedAt: planted,
      daysToMaturity: maturity,
      expectedHarvest: planted.add(Duration(days: maturity)),
    ));
    bumpData(ref);
  }

  Future<void> _addField(BuildContext context) async {
    final name = TextEditingController();
    final size = TextEditingController(text: '1.0');
    final soil = TextEditingController(text: 'Loam');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Field name')),
            TextField(controller: size, decoration: const InputDecoration(labelText: 'Size (ha)'), keyboardType: TextInputType.number),
            TextField(controller: soil, decoration: const InputDecoration(labelText: 'Soil type')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull!;
    await ref.read(appRepositoryProvider).saveField(FarmField(
          id: ref.read(appRepositoryProvider).newId(),
          farmId: user.farmId,
          fieldName: name.text.trim(),
          sizeHa: double.tryParse(size.text) ?? 1,
          soilType: soil.text.trim(),
        ));
    bumpData(ref);
  }
}

class _ActiveCropsTab extends ConsumerWidget {
  const _ActiveCropsTab({required this.crops});
  final List<CropPlot> crops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (crops.isEmpty) {
      return const EmptyState(icon: Icons.grass, title: 'No active plantings');
    }
    final avg = crops.map((c) => c.growthPercent).reduce((a, b) => a + b) / crops.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RootsCard(
          child: Column(
            children: [
              for (final crop in crops) ...[
                _cropRow(context, ref, crop),
                const Divider(height: 18),
              ],
              _overall(avg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cropRow(BuildContext context, WidgetRef ref, CropPlot crop) {
    return InkWell(
      onTap: () => _detail(context, ref, crop),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: RootsColors.greenPale, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.eco, color: RootsColors.greenDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${crop.growthStage} · ${crop.varietyName ?? crop.cropType}'
                  '${crop.pestPresence || crop.diseasePresence ? ' · ALERT' : ''}',
                  style: TextStyle(
                    color: crop.pestPresence || crop.diseasePresence ? RootsColors.red : RootsColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: crop.growthPercent / 100,
                      minHeight: 8,
                      backgroundColor: RootsColors.line,
                      color: RootsColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${crop.growthPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overall(double avg) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: RootsColors.greyCard, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.insights, color: RootsColors.muted),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall Field Health', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Average across all plots', style: TextStyle(color: RootsColors.muted, fontSize: 12)),
            ],
          ),
        ),
        Text('${avg.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Future<void> _detail(BuildContext context, WidgetRef ref, CropPlot crop) async {
    final repo = ref.read(appRepositoryProvider);
    final treatments = repo.treatments(crop.farmId, plantingId: crop.id);
    final observations = repo.observations(crop.farmId, plantingId: crop.id);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(crop.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${crop.fieldName ?? '—'} · ${crop.varietyName ?? crop.cropType}'),
              Text('Planted ${DateFormat.yMMMd().format(crop.plantedAt)} · ${crop.daysSincePlanting} days · ${crop.growthStage}'),
              if (crop.soilMoisture != null) Text('Moisture ${crop.soilMoisture!.toStringAsFixed(0)}%'),
              const SizedBox(height: 12),
              const Text('Treatments', style: TextStyle(fontWeight: FontWeight.w800)),
              if (treatments.isEmpty) const Text('None yet', style: TextStyle(color: RootsColors.muted)),
              for (final t in treatments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${t.treatmentType.name} · ${t.productName ?? ''}'),
                  subtitle: Text(DateFormat.yMMMd().format(t.applicationDate)),
                  trailing: t.costUsd == null ? null : Text('\$${t.costUsd!.toStringAsFixed(0)}'),
                ),
              const Text('Observations', style: TextStyle(fontWeight: FontWeight.w800)),
              if (observations.isEmpty) const Text('None yet', style: TextStyle(color: RootsColors.muted)),
              for (final o in observations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(o.notes ?? 'Observation'),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(o.observationDate)}'
                    '${o.pestPresence ? ' · pest' : ''}'
                    '${o.diseasePresence ? ' · disease' : ''}',
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _addTreatment(context, ref, crop);
                    },
                    child: const Text('Add treatment'),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _addObservation(context, ref, crop);
                    },
                    child: const Text('Add observation'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTreatment(BuildContext context, WidgetRef ref, CropPlot crop) async {
    final product = TextEditingController(text: 'Urea');
    final cost = TextEditingController(text: '50');
    var type = TreatmentType.fertilizer;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Log treatment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TreatmentType>(
                value: type,
                items: TreatmentType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setLocal(() => type = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(controller: product, decoration: const InputDecoration(labelText: 'Product')),
              TextField(controller: cost, decoration: const InputDecoration(labelText: 'Cost USD'), keyboardType: TextInputType.number),
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
    await repo.saveTreatment(CropTreatment(
      id: repo.newId(),
      farmId: crop.farmId,
      plantingId: crop.id,
      treatmentType: type,
      productName: product.text.trim(),
      applicationDate: DateTime.now(),
      costUsd: double.tryParse(cost.text),
    ));
    bumpData(ref);
  }

  Future<void> _addObservation(BuildContext context, WidgetRef ref, CropPlot crop) async {
    final notes = TextEditingController();
    var pest = false;
    var disease = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add observation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              CheckboxListTile(
                value: pest,
                onChanged: (v) => setLocal(() => pest = v ?? false),
                title: const Text('Pest presence'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: disease,
                onChanged: (v) => setLocal(() => disease = v ?? false),
                title: const Text('Disease presence'),
                contentPadding: EdgeInsets.zero,
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
    await repo.saveObservation(CropObservation(
      id: repo.newId(),
      farmId: crop.farmId,
      plantingId: crop.id,
      observationDate: DateTime.now(),
      pestPresence: pest,
      diseasePresence: disease,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    ));
    bumpData(ref);
  }
}

class _FieldsTab extends StatelessWidget {
  const _FieldsTab({required this.fields, required this.onAdd});
  final List<FarmField> fields;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add field')),
        ),
        if (fields.isEmpty)
          const EmptyState(icon: Icons.map, title: 'No fields yet')
        else
          ...fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RootsCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.landscape)),
                  title: Text(f.fieldName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${f.sizeHa} ha · ${f.soilType ?? '—'} · ${f.climateZone ?? ''}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({required this.catalog});
  final List<CropCatalogItem> catalog;

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return const EmptyState(icon: Icons.menu_book, title: 'Crop catalog empty');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in catalog)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RootsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.cropName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${c.cropGroup} · ${c.daysToMaturity} days · ${c.optimalSeason ?? ''}'),
                trailing: c.marketPriceUsd == null
                    ? null
                    : Text('\$${c.marketPriceUsd!.toStringAsFixed(0)}/t',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: RootsColors.greenDeep)),
              ),
            ),
          ),
      ],
    );
  }
}

class _MarketTab extends StatelessWidget {
  const _MarketTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: 'Local Market Prices (USD/ton)'),
        RootsCard(
          child: Column(
            children: const [
              _MarketRow('Maize (white)', '\$385', '+2%', true),
              _MarketRow('Tobacco (flue-cured)', '\$4,250', '+1.5%', true),
              _MarketRow('Cotton (seed cotton)', '\$1,020', '-0.8%', false),
              _MarketRow('Tomatoes (fresh)', '\$520', '+3%', true),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow(this.name, this.price, this.change, this.up);
  final String name;
  final String price;
  final String change;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(change,
              style: TextStyle(
                  color: up ? RootsColors.green : RootsColors.red, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
