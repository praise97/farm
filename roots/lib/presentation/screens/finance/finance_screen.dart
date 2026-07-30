import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/shared_entities.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (perms?.canViewFinance != true) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Finance restricted',
          subtitle: 'Only Owner and Manager roles can view finance.',
        ),
      );
    }

    final entries = ref.watch(financeProvider);
    final income = entries.where((e) => e.type == FinanceType.income).fold<double>(0, (s, e) => s + e.amount);
    final expense = entries.where((e) => e.type == FinanceType.expense).fold<double>(0, (s, e) => s + e.amount);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 100),
        children: [
          if (wide)
            const Text('Finance', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Income', value: '\$${income.toStringAsFixed(0)}', changePositive: true, icon: Icons.trending_up)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Expenses', value: '\$${expense.toStringAsFixed(0)}', changePositive: false, icon: Icons.trending_down)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Profit', value: '\$${(income - expense).toStringAsFixed(0)}', changePositive: income >= expense, icon: Icons.account_balance_wallet)),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: 'Cash flow'),
          RootsCard(
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(v == 0 ? 'Income' : 'Expense', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income, color: RootsColors.green, width: 42, borderRadius: BorderRadius.circular(8))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense, color: RootsColors.orange, width: 42, borderRadius: BorderRadius.circular(8))]),
                  ],
                ),
              ),
            ),
          ),
          SectionHeader(title: 'Recent transactions'),
          ...entries.map((e) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: e.type == FinanceType.income ? RootsColors.greenPale : RootsColors.peachCard,
                  child: Icon(
                    e.type == FinanceType.income ? Icons.arrow_downward : Icons.arrow_upward,
                    color: e.type == FinanceType.income ? RootsColors.green : RootsColors.orange,
                    size: 18,
                  ),
                ),
                title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${e.category} · ${DateFormat.yMMMd().format(e.date)}'),
                trailing: Text(
                  '${e.type == FinanceType.income ? '+' : '-'}\$${e.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: e.type == FinanceType.income ? RootsColors.green : RootsColors.red,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    var type = FinanceType.expense;
    var category = ExpenseCategory.other.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add finance entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<FinanceType>(
                value: type,
                items: FinanceType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setLocal(() {
                  type = v!;
                  category = type == FinanceType.income
                      ? IncomeCategory.other.name
                      : ExpenseCategory.other.name;
                }),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
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
    final user = ref.read(authStateProvider).valueOrNull!;
    await ref.read(appRepositoryProvider).saveFinance(FinanceEntry(
          id: ref.read(appRepositoryProvider).newId(),
          farmId: user.farmId,
          type: type,
          category: category,
          description: desc.text.trim().isEmpty ? 'Entry' : desc.text.trim(),
          amount: double.tryParse(amount.text) ?? 0,
          date: DateTime.now(),
        ));
    bumpData(ref);
  }
}
