import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/dashboard_insights.dart';
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
import '../../widgets/scooped_header.dart';

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

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

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
    final totalGoalsSaved = goalsState.goals.fold<double>(0, (sum, g) => sum + g.currentAmount);

    final isLoading = expensesState.isLoading ||
                      incomesState.isLoading ||
                      obligationsState.isLoading ||
                      goalsState.isLoading;

    final now = DateTime.now();
    final nextAction = computeNextAction(
      freeCashFlow: freeCashFlow,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalObligations: totalObligations,
      obligations: obligationsState.obligations,
      today: now,
      currencySymbol: currencySymbol,
    );
    final upcomingBills = upcomingObligations(obligationsState.obligations, now);
    final recentExpenses = expensesState.expenses.take(5).toList();

    // The emerald hero draws behind the (transparent) status bar, so this
    // screen needs dark status icons regardless of theme brightness; the
    // other tabs' AppBars re-assert the theme's overlay style when shown.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: appColors.surfaceElevated,
      systemNavigationBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
    );

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScoopedHeader(
                background: colorScheme.primary,
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
                              style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                            ),
                            Text(
                              authState.user?.name ?? 'there',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: colorScheme.surface,
                          child: Text(
                            (authState.user?.name ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _HeroFigure(
                      amount: freeCashFlow,
                      totalIncome: totalIncome,
                      totalExpenses: totalExpenses,
                      currencySymbol: currencySymbol,
                      textColor: colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _NextActionCallout(action: nextAction),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Quick Actions'),
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 28),
                  _AtAGlanceStrip(
                    currencySymbol: currencySymbol,
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    totalObligations: totalObligations,
                    totalGoals: totalGoalsSaved,
                  ),
                  const SizedBox(height: 28),
                  // Spending section: chart + upcoming bills grouped with a
                  // tight gap (no outer header — the chart already renders
                  // its own "Spending by Category" title; see this plan's
                  // Global Constraints note).
                  if (!isLoading && expensesState.expenses.isNotEmpty) ...[
                    SpendingByCategoryChart(
                      categoryTotals: _calculateCategoryTotals(expensesState.expenses),
                      currencySymbol: currencySymbol,
                    ),
                    if (upcomingBills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _UpcomingBillsCard(upcoming: upcomingBills, currencySymbol: currencySymbol),
                    ],
                    const SizedBox(height: 16),
                  ] else if (!isLoading && upcomingBills.isNotEmpty) ...[
                    _UpcomingBillsCard(upcoming: upcomingBills, currencySymbol: currencySymbol),
                    const SizedBox(height: 16),
                  ],
                  if (!isLoading && goalsState.goals.isNotEmpty) ...[
                    GoalsProgressChart(
                      goals: goalsState.goals,
                      currencySymbol: currencySymbol,
                    ),
                    const SizedBox(height: 28),
                  ],
                  _SectionHeader(
                    title: 'Recent Expenses',
                    onViewAll: expensesState.expenses.isNotEmpty
                        ? () => context.go('/expenses')
                        : null,
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
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: Theme.of(context).textTheme.bodySmall?.color,
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
                      children: [
                        for (var i = 0; i < recentExpenses.length; i++) ...[
                          _ExpenseItem(
                            expense: recentExpenses[i],
                            currencySymbol: currencySymbol,
                          ),
                          if (i != recentExpenses.length - 1)
                            Divider(
                              height: 1,
                              color: Theme.of(context).dividerTheme.color,
                            ),
                        ],
                      ],
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final double amount;
  final double totalIncome;
  final double totalExpenses;
  final String currencySymbol;
  final Color textColor;

  const _HeroFigure({
    required this.amount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.currencySymbol,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Left to spend this month',
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$currencySymbol ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: textColor,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.arrow_upward_rounded, color: textColor.withOpacity(0.7), size: 14),
            const SizedBox(width: 4),
            Text(
              'Income $currencySymbol ${totalIncome.toStringAsFixed(2)}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(width: 16),
            Icon(Icons.arrow_downward_rounded, color: textColor.withOpacity(0.7), size: 14),
            const SizedBox(width: 4),
            Text(
              'Expenses $currencySymbol ${totalExpenses.toStringAsFixed(2)}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _NextActionCallout extends StatelessWidget {
  final NextAction action;

  const _NextActionCallout({required this.action});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final Color tint;
    final IconData icon;
    switch (action.severity) {
      case NextActionSeverity.error:
        tint = colorScheme.error;
        icon = Icons.error_outline_rounded;
        break;
      case NextActionSeverity.warning:
        tint = appColors.warning;
        icon = Icons.event_rounded;
        break;
      case NextActionSeverity.success:
        tint = appColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case NextActionSeverity.info:
        tint = appColors.info;
        icon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w600,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.onPrimary, size: 24),
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
    );
  }
}

class _AtAGlanceStrip extends StatelessWidget {
  final String currencySymbol;
  final double totalIncome;
  final double totalExpenses;
  final double totalObligations;
  final double totalGoals;

  const _AtAGlanceStrip({
    required this.currencySymbol,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalObligations,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final items = [
      (label: 'Income', amount: totalIncome, icon: Icons.arrow_upward_rounded, color: appColors.success),
      (label: 'Expenses', amount: totalExpenses, icon: Icons.arrow_downward_rounded, color: appColors.info),
      (label: 'Obligations', amount: totalObligations, icon: Icons.account_balance_wallet_rounded, color: appColors.warning),
      (label: 'Goals', amount: totalGoals, icon: Icons.savings_rounded, color: appColors.info),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                color: Theme.of(context).dividerTheme.color,
                thickness: 1,
                width: 1,
                indent: 8,
                endIndent: 8,
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].icon, color: items[i].color, size: 16),
                  const SizedBox(height: 6),
                  Text(
                    items[i].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currencySymbol ${items[i].amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingBillsCard extends StatelessWidget {
  final List<UpcomingObligation> upcoming;
  final String currencySymbol;

  const _UpcomingBillsCard({required this.upcoming, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Bills',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          for (var i = 0; i < upcoming.length; i++) ...[
            _UpcomingBillRow(upcoming: upcoming[i], currencySymbol: currencySymbol),
            if (i != upcoming.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerTheme.color),
          ],
        ],
      ),
    );
  }
}

class _UpcomingBillRow extends StatelessWidget {
  final UpcomingObligation upcoming;
  final String currencySymbol;

  const _UpcomingBillRow({required this.upcoming, required this.currencySymbol});

  String _dueLabel(int days) {
    if (days <= 0) return 'due today';
    if (days == 1) return 'due in 1 day';
    return 'due in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final obligation = upcoming.obligation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obligation.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _dueLabel(upcoming.daysUntilDue),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$currencySymbol ${obligation.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
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

  /// Category chip tint, cycled from the theme's token palette rather than
  /// ad hoc Material colors.
  Color _getCategoryColor(BuildContext context, Category category) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      appColors.warning,
      appColors.success,
    ];
    return palette[category.index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(context, expense.category).withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getCategoryIcon(expense.category),
              color: _getCategoryColor(context, expense.category),
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '-$currencySymbol ${expense.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).extension<AppColors>()!.infoText,
                ),
          ),
        ],
      ),
    );
  }
}
