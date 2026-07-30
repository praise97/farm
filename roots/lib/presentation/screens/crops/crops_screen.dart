import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

/// Crop module — ported from the existing FarmSmartPro HTML crop dashboard.
/// Full crop features are owned by your partner; this keeps the UI + data shape ready.
class CropsScreen extends ConsumerWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crops = ref.watch(cropsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final avg = crops.isEmpty
        ? 0.0
        : crops.map((c) => c.growthPercent).reduce((a, b) => a + b) / crops.length;
    final moisture = crops.isEmpty
        ? 0.0
        : crops.map((c) => c.soilMoisture ?? 0).reduce((a, b) => a + b) / crops.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCrop(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Crop'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          if (wide)
            const Text('Zimbabwe Crop Dashboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RootsColors.lavenderCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Crop Management is shared with your partner. This screen mirrors the existing FarmSmartPro crop dashboard so both modules stay connected in Roots.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(label: 'Active Crop Plots', value: '${crops.length}', changePositive: true, icon: Icons.grid_view),
                  StatCard(label: 'Avg Soil Moisture', value: '${moisture.toStringAsFixed(0)}%', icon: Icons.water_drop),
                  StatCard(label: 'Current Temp', value: '26°C', change: 'Feels like 28°C', icon: Icons.thermostat),
                  StatCard(label: 'Smart Alerts', value: '${ref.watch(unreadAlertsProvider)}', accent: true, icon: Icons.notifications),
                ],
              );
            },
          ),
          SectionHeader(title: 'My Crop Growth', live: true),
          RootsCard(
            child: Column(
              children: [
                for (final crop in crops) ...[
                  _row(crop),
                  const Divider(height: 18),
                ],
                _overall(avg),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          RootsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weather — Harare', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text('26°C', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    SizedBox(width: 12),
                    Icon(Icons.wb_sunny, color: RootsColors.gold, size: 36),
                  ],
                ),
                const Text('Sunny · Feels like 28°C', style: TextStyle(color: RootsColors.muted)),
                const SizedBox(height: 12),
                const Text('Expected rainfall: 5mm mid-week', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CropPlot crop) {
    return Row(
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
              Text(crop.statusNote, style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
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

  Future<void> _addCrop(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final type = TextEditingController(text: 'Maize');
    final growth = TextEditingController(text: '50');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add crop plot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Plot name')),
            TextField(controller: type, decoration: const InputDecoration(labelText: 'Crop type')),
            TextField(controller: growth, decoration: const InputDecoration(labelText: 'Growth %')),
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
    final g = double.tryParse(growth.text) ?? 0;
    await ref.read(appRepositoryProvider).saveCrop(CropPlot(
          id: ref.read(appRepositoryProvider).newId(),
          farmId: user.farmId,
          name: name.text.trim(),
          cropType: type.text.trim(),
          growthPercent: g,
          soilMoisture: 65,
          statusNote: 'at ${g.toStringAsFixed(0)}% growth',
          plantedAt: DateTime.now(),
        ));
    bumpData(ref);
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
          Text(change, style: TextStyle(color: up ? RootsColors.green : RootsColors.red, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
