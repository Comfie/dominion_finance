import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/incomes_provider.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/goals_provider.dart';
import '../../widgets/ai_gate_dialog.dart';
import '../../widgets/charts/spending_by_category_chart.dart';
import '../../widgets/charts/goals_progress_chart.dart';
import '../../widgets/forms/scan_receipt_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
      ref.read(expensesProvider.notifier).loadExpenses();
      ref.read(incomesProvider.notifier).loadIncomes();
      ref.read(obligationsProvider.notifier).loadObligations();
      ref.read(goalsProvider.notifier).loadGoals();
    });
  }

  /// Calculate total spending by category
  Map<String, double> _calculateCategoryTotals(List<Expense> expenses) {
    final Map<String, double> totals = {};
    for (final expense in expenses) {
      final category = expense.category.name;
      totals[category] = (totals[category] ?? 0) + expense.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settingsState = ref.watch(settingsProvider);
    final expensesState = ref.watch(expensesProvider);
    final incomesState = ref.watch(incomesProvider);
    final obligationsState = ref.watch(obligationsProvider);
    final goalsState = ref.watch(goalsProvider);
    final isLocalMode = ref.watch(storageModeProvider) == StorageMode.local;

    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    // Calculate financial metrics
    final monthlyIncome = settingsState.settings?.monthlyIncome ?? 0;
    final additionalIncome = incomesState.incomes.fold<double>(0, (sum, income) => sum + income.amount);
    final totalIncome = monthlyIncome + additionalIncome;

    final totalExpenses = expensesState.totalExpenses;
    final totalObligations = obligationsState.obligations
        .where((o) => o.isActive)
        .fold<double>(0, (sum, o) => sum + o.amount);

    final freeCashFlow = totalIncome - totalExpenses - totalObligations;

    final isLoading = expensesState.isLoading ||
                      incomesState.isLoading ||
                      obligationsState.isLoading ||
                      goalsState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              authState.user?.name ?? 'there',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            (authState.user?.name ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SummaryCard(
                      title: 'Free Cash Flow',
                      amount: freeCashFlow,
                      currencySymbol: currencySymbol,
                      color: freeCashFlow >= 0 ? AppTheme.success : AppTheme.error,
                      icon: freeCashFlow >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniCard(
                            title: 'Income',
                            amount: totalIncome,
                            currencySymbol: currencySymbol,
                            color: AppTheme.success,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniCard(
                            title: 'Expenses',
                            amount: totalExpenses,
                            currencySymbol: currencySymbol,
                            color: AppTheme.error,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniCard(
                            title: 'Obligations',
                            amount: totalObligations,
                            currencySymbol: currencySymbol,
                            color: AppTheme.warning,
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniCard(
                            title: 'Goals',
                            amount: goalsState.goals.fold<double>(0, (sum, g) => sum + g.currentAmount),
                            currencySymbol: currencySymbol,
                            color: AppTheme.info,
                            icon: Icons.savings_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add_rounded,
                            label: 'Add Expense',
                            onTap: () => context.go('/expenses'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.camera_alt_rounded,
                            label: 'Scan Receipt',
                            onTap: () {
                              if (isLocalMode) {
                                showAiGateDialog(
                                  context,
                                  ref,
                                  message: 'Requires an account — receipt '
                                      'data is processed via our servers '
                                      'and never stored.',
                                );
                                return;
                              }
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const ScanReceiptModal(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.insights_rounded,
                            label: 'Insights',
                            onTap: () {
                              if (isLocalMode) {
                                showAiGateDialog(
                                  context,
                                  ref,
                                  message: 'Requires an account — spending '
                                      'insights are generated via our '
                                      'servers and never stored.',
                                );
                                return;
                              }
                              context.go('/insights');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Charts section
                    if (!isLoading && expensesState.expenses.isNotEmpty) ...[
                      SpendingByCategoryChart(
                        categoryTotals: _calculateCategoryTotals(expensesState.expenses),
                        currencySymbol: currencySymbol,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isLoading && goalsState.goals.isNotEmpty) ...[
                      GoalsProgressChart(
                        goals: goalsState.goals,
                        currencySymbol: currencySymbol,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Expenses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (expensesState.expenses.isNotEmpty)
                          TextButton(
                            onPressed: () => context.go('/expenses'),
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (expensesState.expenses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 48,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No expenses yet',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first expense to get started',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: expensesState.expenses
                            .take(5)
                            .map((expense) => _ExpenseItem(
                                  expense: expense,
                                  currencySymbol: currencySymbol,
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currencySymbol;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currencySymbol,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Icon(icon, color: Colors.white70, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currencySymbol ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currencySymbol;
  final Color color;
  final IconData icon;

  const _MiniCard({
    required this.title,
    required this.amount,
    required this.currencySymbol,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currencySymbol ${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  final Expense expense;
  final String currencySymbol;

  const _ExpenseItem({
    required this.expense,
    required this.currencySymbol,
  });

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.GROCERIES:
        return Icons.shopping_cart_rounded;
      case Category.TRANSPORT:
        return Icons.directions_car_rounded;
      case Category.DINING:
        return Icons.restaurant_rounded;
      case Category.ENTERTAINMENT:
        return Icons.movie_rounded;
      case Category.UTILITIES:
        return Icons.bolt_rounded;
      case Category.SHOPPING:
        return Icons.shopping_bag_rounded;
      case Category.HOUSING:
        return Icons.home_rounded;
      case Category.INSURANCE:
        return Icons.security_rounded;
      case Category.LIVING:
        return Icons.favorite_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getCategoryColor(Category category) {
    switch (category) {
      case Category.GROCERIES:
        return Colors.green;
      case Category.TRANSPORT:
        return Colors.blue;
      case Category.DINING:
        return Colors.orange;
      case Category.ENTERTAINMENT:
        return Colors.purple;
      case Category.UTILITIES:
        return Colors.amber;
      case Category.SHOPPING:
        return Colors.pink;
      case Category.HOUSING:
        return Colors.brown;
      case Category.INSURANCE:
        return Colors.indigo;
      case Category.LIVING:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(expense.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(expense.category),
              color: _getCategoryColor(expense.category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  expense.category.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '-$currencySymbol ${expense.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
          ),
        ],
      ),
    );
  }
}
