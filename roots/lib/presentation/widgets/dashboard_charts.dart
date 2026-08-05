import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/roots_theme.dart';
import '../../domain/entities/shared_entities.dart';
import '../providers/app_providers.dart';
import 'common_widgets.dart';

/// Live statistical charts driven by Riverpod farm data.
class DashboardChartsSection extends ConsumerWidget {
  const DashboardChartsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataVersionProvider);
    final finance = ref.watch(financeProvider);
    final animals = ref.watch(animalsProvider);
    final alerts = ref.watch(alertsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final cashSpots = _monthlyNetSpots(finance);
    final statusCounts = <String, int>{};
    for (final a in animals) {
      statusCounts[a.status.label] = (statusCounts[a.status.label] ?? 0) + 1;
    }

    final charts = [
      _chartCard(
        title: 'Cash flow (6 mo)',
        subtitle: 'Updates when you add finance entries',
        child: _CashFlowLine(spots: cashSpots),
      ),
      _chartCard(
        title: 'Livestock by status',
        subtitle: '${animals.length} animals · live',
        child: _StatusBars(counts: statusCounts),
      ),
      _chartCard(
        title: 'Alerts this week',
        subtitle: '${alerts.length} total',
        child: _AlertsMini(alerts: alerts),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Statistical graphs', live: true),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < charts.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: charts[i]),
              ],
            ],
          )
        else
          ...charts.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)),
      ],
    );
  }

  Widget _chartCard({required String title, required String subtitle, required Widget child}) {
    return RootsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: RootsColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: child),
        ],
      ),
    );
  }

  List<FlSpot> _monthlyNetSpots(List<FinanceEntry> entries) {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final next = DateTime(month.year, month.month + 1, 1);
      final slice = entries.where((e) => !e.date.isBefore(month) && e.date.isBefore(next));
      final income = slice
          .where((e) => e.type == FinanceType.income)
          .fold<double>(0, (s, e) => s + e.amount);
      final expense = slice
          .where((e) => e.type == FinanceType.expense)
          .fold<double>(0, (s, e) => s + e.amount);
      spots.add(FlSpot((5 - i).toDouble(), income - expense));
    }
    return spots;
  }
}

class _CashFlowLine extends StatelessWidget {
  const _CashFlowLine({required this.spots});
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.every((s) => s.y == 0)) {
      return const Center(
        child: Text('Add finance entries to see the trend',
            style: TextStyle(color: RootsColors.muted, fontSize: 12)),
      );
    }
    return LineChart(
      LineChartData(
        minY: spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 50,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final now = DateTime.now();
                final m = DateTime(now.year, now.month - (5 - v.toInt()), 1);
                return Text(DateFormat('MMM').format(m), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: RootsColors.teal,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: RootsColors.teal.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBars extends StatelessWidget {
  const _StatusBars({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) {
      return const Center(child: Text('No livestock yet', style: TextStyle(color: RootsColors.muted)));
    }
    final entries = counts.entries.toList();
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                return Text(entries[i].key, style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: RootsColors.greenDeep,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AlertsMini extends StatelessWidget {
  const _AlertsMini({required this.alerts});
  final List<FarmAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = alerts.where((a) => now.difference(a.createdAt).inDays <= 7).length;
    final unread = alerts.where((a) => !a.read).length;
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                PieChartSectionData(
                  value: unread == 0 ? 1 : unread.toDouble(),
                  color: RootsColors.orange,
                  title: unread == 0 ? '' : '$unread',
                  radius: 36,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                PieChartSectionData(
                  value: (alerts.length - unread).clamp(0, 999).toDouble() + (alerts.isEmpty ? 1 : 0),
                  color: RootsColors.greenPale,
                  title: '',
                  radius: 30,
                ),
              ],
            ),
          ),
        ),
        Text('$week new this week · $unread unread',
            style: const TextStyle(fontSize: 12, color: RootsColors.muted)),
      ],
    );
  }
}
