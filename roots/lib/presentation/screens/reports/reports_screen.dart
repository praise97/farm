import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/services/farm_report_service.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/animal.dart';
import '../../../domain/entities/crop_entities.dart';
import '../../../domain/entities/farm_user.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

enum _ReportKind {
  perAnimal,
  perCrop,
  allLivestock,
  allCrops,
  marketSales,
  dutyRoster,
  staffAccounts,
  farmPerformance,
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (perms?.canExportReports != true) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Reports restricted',
          subtitle: 'Only supervisors can download farm summary documents.',
        ),
      );
    }

    final animals = ref.watch(animalsProvider);
    final crops = ref.watch(cropsProvider);
    final finance = ref.watch(financeProvider);
    final tasks = ref.watch(tasksProvider);
    final staff = ref.watch(workersProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final farmName = user == null
        ? 'Farm'
        : (ref.read(appRepositoryProvider).farm(user.farmId)?.name ?? 'Farm');

    final reports = <(_ReportKind kind, String title, String subtitle, IconData icon)>[
      (_ReportKind.perAnimal, 'Per Animal Report', 'PDF summary for one animal', Icons.pets),
      (_ReportKind.allLivestock, 'All Livestock Summary', '${animals.length} animals · PDF', Icons.list_alt),
      (_ReportKind.perCrop, 'Per Crop Report', 'PDF summary for one crop plot', Icons.grass),
      (_ReportKind.allCrops, 'All Crops Summary', '${crops.length} active plots · PDF', Icons.eco),
      (_ReportKind.marketSales, 'Market Sales Report', 'Income & market sales · PDF', Icons.storefront),
      (_ReportKind.dutyRoster, 'Employee Duty Roster', '${tasks.length} tasks · PDF', Icons.calendar_month),
      (_ReportKind.staffAccounts, 'Staff & User Accounts', '${staff.length} accounts · PDF', Icons.groups),
      (_ReportKind.farmPerformance, 'Farm Performance Report', 'Tasks, workers, completion rates · PDF', Icons.insights),
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Reports & Export', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Download summary documents (PDF) — per animal, per crop, market sales, duty roster, staff accounts, and overall farm performance.',
            style: TextStyle(color: RootsColors.muted),
          ),
          const SizedBox(height: 16),
          ...reports.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RootsCard(
                  onTap: user == null
                      ? null
                      : () => _export(context, ref, r.$1, farmName, user.farmId, animals, crops, finance, tasks, staff),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: RootsColors.mintCard,
                      child: Icon(r.$4, color: RootsColors.greenDeep),
                    ),
                    title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(r.$3),
                    trailing: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    _ReportKind kind,
    String farmName,
    String farmId,
    List<Animal> animals,
    List<CropPlot> crops,
    List<FinanceEntry> finance,
    List<FarmTask> tasks,
    List<FarmUser> staff,
  ) async {
    final repo = ref.read(appRepositoryProvider);
    final svc = FarmReportService.instance;

    try {
      switch (kind) {
        case _ReportKind.perAnimal:
          if (animals.isEmpty) {
            _snack(context, 'No animals on this farm yet.');
            return;
          }
          final picked = await _pickAnimal(context, animals);
          if (picked == null || !context.mounted) return;
          await svc.perAnimal(
            farmName: farmName,
            animal: picked,
            timeline: repo.timelineFor(picked.id),
            vaccination: repo.vaccinationForAnimal(picked.id),
          );
        case _ReportKind.allLivestock:
          await svc.allLivestock(farmName: farmName, animals: animals);
        case _ReportKind.perCrop:
          if (crops.isEmpty) {
            _snack(context, 'No active crop plots yet.');
            return;
          }
          final picked = await _pickCrop(context, crops);
          if (picked == null || !context.mounted) return;
          await svc.perCrop(farmName: farmName, crop: picked);
        case _ReportKind.allCrops:
          await svc.allCrops(farmName: farmName, crops: crops);
        case _ReportKind.marketSales:
          await svc.marketSales(farmName: farmName, entries: finance);
        case _ReportKind.dutyRoster:
          await svc.dutyRoster(farmName: farmName, tasks: tasks, staff: staff);
        case _ReportKind.staffAccounts:
          await svc.staffAccounts(farmName: farmName, staff: staff);
        case _ReportKind.farmPerformance:
          final csv = repo.generatePerformanceReport(farmId);
          await svc.farmPerformance(farmName: farmName, csvBody: csv);
      }
      if (context.mounted) {
        _snack(context, 'PDF ready — use Save or Share in the dialog.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Export failed: $e');
      }
    }
  }

  Future<Animal?> _pickAnimal(BuildContext context, List<Animal> animals) {
    return showDialog<Animal>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select animal'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: animals.length,
            itemBuilder: (_, i) {
              final a = animals[i];
              return ListTile(
                title: Text(a.tagNumber),
                subtitle: Text('${a.breed} · ${a.status.label}'),
                onTap: () => Navigator.pop(ctx, a),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<CropPlot?> _pickCrop(BuildContext context, List<CropPlot> crops) {
    return showDialog<CropPlot>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select crop plot'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: crops.length,
            itemBuilder: (_, i) {
              final c = crops[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text('${c.cropType} · ${c.growthPercent.toStringAsFixed(0)}%'),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
