import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/roots_theme.dart';
import '../../../core/constants/enums.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final animals = ref.watch(animalsProvider);
    final equipment = ref.watch(equipmentProvider);
    final crops = ref.watch(cropsProvider);
    final alerts = ref.watch(alertsProvider);
    final inventory = ref.watch(inventoryProvider);
    final finance = ref.watch(financeProvider);
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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 28),
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
                                const Text(
                                  'Real-time insights and AI-powered farm management',
                                  style: TextStyle(color: RootsColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: RootsColors.muted),
                          const SizedBox(width: 8),
                          Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
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
                LayoutBuilder(
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
                          change: crops.isEmpty ? 'Crop module (partner)' : 'From crop plots',
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
                const SizedBox(height: 8),
                SectionHeader(title: 'Quick Actions'),
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
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final sideBySide = c.maxWidth > 900;
                    final growth = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Crop Growth Overview',
                          live: true,
                          actionLabel: 'View All →',
                          onAction: () => context.go('/crops'),
                        ),
                        RootsCard(
                          child: Column(
                            children: [
                              for (final crop in crops.take(4)) ...[
                                _cropRow(crop.name, crop.statusNote, crop.growthPercent),
                                if (crop != crops.take(4).last) const Divider(height: 20),
                              ],
                              if (crops.isNotEmpty) ...[
                                const Divider(height: 20),
                                _cropRow(
                                  'Overall Growth',
                                  'Average across all plots',
                                  crops.map((e) => e.growthPercent).reduce((a, b) => a + b) /
                                      crops.length,
                                  overall: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );

                    final right = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(title: 'Priority Animals'),
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
                                ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (!sideBySide) {
                      return Column(children: [growth, const SizedBox(height: 12), right]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: growth),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: right),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SectionHeader(title: 'Farm Snapshot'),
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
                          change: 'Income \$${income.toStringAsFixed(0)} · Expense \$${expense.toStringAsFixed(0)}',
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
                          value: '${ref.watch(tasksProvider).where((t) => t.status.name != 'completed').length}',
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

  Widget _cropRow(String name, String detail, double pct, {bool overall = false}) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: overall ? RootsColors.greyCard : RootsColors.greenPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(overall ? Icons.insights : Icons.eco, color: RootsColors.greenDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(detail, style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          width: 110,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: RootsColors.line,
                    color: overall ? RootsColors.muted : RootsColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
