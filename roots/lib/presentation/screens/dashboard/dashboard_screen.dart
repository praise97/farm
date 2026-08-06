import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../core/tour/app_tour.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dashboard_charts.dart';
import '../../widgets/weather_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
  }

  void _maybeStartTour() {
    if (!mounted) return;
    if (LocalStore.instance.appTourSeen) return;
    // Slight delay so layout keys are attached.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      try {
        RootsTour.start(context);
        LocalStore.instance.setAppTourSeen();
      } catch (_) {}
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final perms = ref.watch(permissionsProvider);
    final myTasks = ref.watch(myTasksProvider);
    final isWorker = perms?.isWorker ?? false;
    final animals = ref.watch(animalsProvider);
    final equipment = ref.watch(equipmentProvider);
    final crops = ref.watch(cropsProvider);
    final alerts = ref.watch(alertsProvider);
    final inventory = ref.watch(inventoryProvider);
    final finance = ref.watch(financeProvider);
    final vaxDue = ref.watch(vaccinationsDueProvider).where((v) => v.dueThisMonth || v.isOverdue);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final date = DateFormat('MMM d, y').format(DateTime.now());

    final alive = animals.where((a) => a.status.name != 'dead' && a.status.name != 'sold').length;
    final avgMoisture = crops.isEmpty
        ? 0.0
        : crops.map((c) => c.soilMoisture ?? 0).reduce((a, b) => a + b) / crops.length;
    final income = finance.where((f) => f.type.name == 'income').fold<double>(0, (s, e) => s + e.amount);
    final expense = finance.where((f) => f.type.name == 'expense').fold<double>(0, (s, e) => s + e.amount);
    final lowStock = inventory.where((i) => i.isLowStock).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          LocalStore.instance.setAppTourSeen(false);
          RootsTour.start(context);
          LocalStore.instance.setAppTourSeen();
        },
        icon: const Icon(Icons.help_outline),
        label: const Text('Guide'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 88),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (wide)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Farm Dashboard',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _pill(Icons.circle, 'Monitoring active', RootsColors.green),
                                _pill(Icons.memory, 'Roots farm control center', RootsColors.blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  )
                else ...[
                  HeroBanner(
                    title: '${_greeting()}, ${user?.name.split(' ').first ?? 'Farmer'}',
                    subtitle: 'Your livestock, equipment and farm ops at a glance.',
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 18),
                if (isWorker) ...[
                  SectionHeader(
                    title: 'My assigned tasks',
                    actionLabel: '${myTasks.where((t) => t.status != TaskStatus.completed).length} open',
                    onAction: () => context.go('/tasks'),
                  ),
                  if (myTasks.isEmpty)
                    const RootsCard(
                      child: Text('No tasks yet — your supervisor will assign work here.',
                          style: TextStyle(color: RootsColors.muted)),
                    )
                  else
                    for (final t in myTasks.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RootsCard(
                          onTap: () => context.go('/tasks'),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              t.status == TaskStatus.awaitingReview
                                  ? Icons.hourglass_top
                                  : Icons.assignment,
                              color: RootsColors.greenDeep,
                            ),
                            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              'Due ${DateFormat.MMMd().format(t.dueDate)} · ${t.status.label}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                ],
                tourTarget(
                  key: TourKeys.stats,
                  title: 'Live farm stats',
                  description: 'These cards update as livestock, crops and alerts change.',
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: cols == 1 ? 2.4 : 1.55,
                        children: [
                          StatCard(
                            label: 'Active Livestock',
                            value: '$alive',
                            change: '${animals.length} total on farm',
                            changePositive: true,
                            icon: Icons.pets,
                          ),
                          StatCard(
                            label: 'Avg Soil Moisture',
                            value: '${avgMoisture.toStringAsFixed(0)}%',
                            change: crops.isEmpty ? 'No crop plots yet' : 'From crop plots',
                            icon: Icons.water_drop_outlined,
                          ),
                          StatCard(
                            label: 'Equipment',
                            value: '${equipment.length}',
                            change: '${equipment.where((e) => e.serviceDue).length} service due',
                            changePositive: equipment.where((e) => e.serviceDue).isEmpty,
                            icon: Icons.agriculture,
                          ),
                          StatCard(
                            label: 'Smart Alerts',
                            value: '${alerts.where((a) => !a.read).length}',
                            accent: true,
                            icon: Icons.notifications_active_outlined,
                            trailing: TextButton(
                              onPressed: () => context.go('/alerts'),
                              child: const Text('View all alerts →'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                tourTarget(
                  key: TourKeys.alerts,
                  title: 'Vaccination & alerts',
                  description:
                      'Animals due for vaccination this month appear here. Alerts also pop up as phone notifications.',
                  child: vaxDue.isEmpty
                      ? RootsCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.notifications_active_outlined,
                                color: RootsColors.greenDeep),
                            title: const Text('Smart alerts',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                                '${alerts.where((a) => !a.read).length} unread · tap to open'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/alerts'),
                          ),
                        )
                      : RootsCard(
                          color: const Color(0xFFFFF3E8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vaccinations this month',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              for (final v in vaxDue.take(4))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(
                                    Icons.vaccines,
                                    color: v.isOverdue ? RootsColors.red : RootsColors.orange,
                                  ),
                                  title: Text(v.animal.tagNumber,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    v.isOverdue
                                        ? 'OVERDUE · ${v.last?.title ?? 'Vaccination'}'
                                        : 'Due ${DateFormat.MMMd().format(v.nextDue!)} · ${v.last?.title ?? 'Vaccination'}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('/livestock/${v.animal.id}'),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                tourTarget(
                  key: TourKeys.weather,
                  title: 'Weather forecast',
                  description: '5-day forecast from Open-Meteo (free). Helps plan spraying and grazing.',
                  child: const WeatherCard(),
                ),
                const SizedBox(height: 8),
                tourTarget(
                  key: TourKeys.charts,
                  title: 'Statistical graphs',
                  description: 'Cash flow, livestock status and alerts update live when farm data changes.',
                  child: const DashboardChartsSection(),
                ),
                tourTarget(
                  key: TourKeys.quickActions,
                  title: 'Quick Actions',
                  description: 'Tap these shortcuts to add livestock, log service, record harvest or open tasks.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Quick Actions'),
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth > 700 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: cols,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.15,
                            children: [
                              QuickActionTile(
                                icon: Icons.add_circle_outline,
                                label: 'Add Livestock',
                                color: RootsColors.mintCard,
                                iconColor: RootsColors.greenDeep,
                                onTap: () => context.push('/livestock/add'),
                              ),
                              QuickActionTile(
                                icon: Icons.build_circle_outlined,
                                label: 'Equipment Service',
                                color: RootsColors.greyCard,
                                iconColor: RootsColors.navy,
                                onTap: () => context.go('/equipment'),
                              ),
                              QuickActionTile(
                                icon: Icons.grass,
                                label: 'Record Harvest',
                                color: RootsColors.lavenderCard,
                                iconColor: RootsColors.navy,
                                onTap: () => context.go('/crops'),
                              ),
                              QuickActionTile(
                                icon: Icons.task_alt,
                                label: 'View Tasks',
                                color: RootsColors.peachCard,
                                iconColor: RootsColors.orange,
                                onTap: () => context.go('/tasks'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                tourTarget(
                  key: TourKeys.livestock,
                  title: 'Priority animals',
                  description: 'Open any cow for vaccination summary, weight graph and health timeline.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Priority Animals'),
                      for (final a in animals.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RootsCard(
                            gradient: RootsColors.tealCardGradient,
                            onTap: () => context.push('/livestock/${a.id}'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.tagNumber,
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text('${a.breed} · ${a.status.label}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      const SizedBox(height: 10),
                                      Text('${a.weight.toStringAsFixed(0)} kg · ${a.ageLabel}',
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.qr_code_2, color: Colors.white70, size: 36),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SectionHeader(title: 'AI Insights', actionLabel: '${alerts.length} new'),
                RootsCard(
                  child: Column(
                    children: [
                      for (final alert in alerts.take(3))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: RootsColors.greenPale,
                            child: Icon(Icons.science_outlined, color: RootsColors.greenDeep),
                          ),
                          title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(alert.message),
                          dense: true,
                          onTap: alert.relatedId != null
                              ? () => context.push('/livestock/${alert.relatedId}')
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Farm Snapshot'),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth > 800 ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        StatCard(
                          label: 'Net (demo period)',
                          value: '\$${(income - expense).toStringAsFixed(0)}',
                          change:
                              'Income \$${income.toStringAsFixed(0)} · Expense \$${expense.toStringAsFixed(0)}',
                          changePositive: income >= expense,
                          icon: Icons.payments_outlined,
                        ),
                        StatCard(
                          label: 'Low stock items',
                          value: '$lowStock',
                          change: 'Inventory alerts',
                          changePositive: lowStock == 0,
                          icon: Icons.inventory_2_outlined,
                        ),
                        StatCard(
                          label: 'Open tasks',
                          value:
                              '${ref.watch(tasksProvider).where((t) => t.status.name != 'completed').length}',
                          icon: Icons.task_alt,
                        ),
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
