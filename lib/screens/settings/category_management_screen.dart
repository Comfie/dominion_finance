import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/expense.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';

/// Category management screen for viewing expense category usage and statistics
/// Follows SKILL.md guidelines for proper state management and widget composition
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load expenses to calculate category statistics
    Future.microtask(() {
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  /// Calculate category statistics
  Map<ExpenseCategory, CategoryStats> _calculateCategoryStats(List<Expense> expenses) {
    final Map<ExpenseCategory, CategoryStats> stats = {};

    // Initialize all categories with zero stats
    for (final category in ExpenseCategory.values) {
      stats[category] = CategoryStats(
        category: category,
        count: 0,
        totalAmount: 0,
      );
    }

    // Calculate actual stats from expenses
    for (final expense in expenses) {
      try {
        final category = ExpenseCategory.values.firstWhere(
          (c) => c.name == expense.category.name,
          orElse: () => ExpenseCategory.OTHER,
        );
        stats[category] = CategoryStats(
          category: category,
          count: stats[category]!.count + 1,
          totalAmount: stats[category]!.totalAmount + expense.amount,
        );
      } catch (e) {
        // Skip invalid categories
      }
    }

    return stats;
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.GROCERIES:
        return Colors.green;
      case ExpenseCategory.TRANSPORT:
        return Colors.blue;
      case ExpenseCategory.DINING:
        return Colors.orange;
      case ExpenseCategory.ENTERTAINMENT:
        return Colors.purple;
      case ExpenseCategory.UTILITIES:
        return Colors.amber;
      case ExpenseCategory.SHOPPING:
        return Colors.pink;
      case ExpenseCategory.HOUSING:
        return Colors.brown;
      case ExpenseCategory.INSURANCE:
        return Colors.indigo;
      case ExpenseCategory.LIVING:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.GROCERIES:
        return Icons.shopping_cart_rounded;
      case ExpenseCategory.TRANSPORT:
        return Icons.directions_car_rounded;
      case ExpenseCategory.DINING:
        return Icons.restaurant_rounded;
      case ExpenseCategory.ENTERTAINMENT:
        return Icons.movie_rounded;
      case ExpenseCategory.UTILITIES:
        return Icons.bolt_rounded;
      case ExpenseCategory.SHOPPING:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.HOUSING:
        return Icons.home_rounded;
      case ExpenseCategory.INSURANCE:
        return Icons.security_rounded;
      case ExpenseCategory.LIVING:
        return Icons.favorite_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    final categoryStats = _calculateCategoryStats(expensesState.expenses);
    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) => b.value.totalAmount.compareTo(a.value.totalAmount));

    final totalExpenses = expensesState.expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
      ),
      body: expensesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Summary section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Statistics',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'View spending breakdown by category',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Spent',
                                value: '$currencySymbol ${totalExpenses.toStringAsFixed(2)}',
                                icon: Icons.payments_rounded,
                                color: AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Categories Used',
                                value: '${sortedCategories.where((e) => e.value.count > 0).length}',
                                icon: Icons.category_rounded,
                                color: AppTheme.info,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Categories list
                  Expanded(
                    child: sortedCategories.isEmpty || totalExpenses == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 64,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No expenses yet',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add expenses to see category statistics',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: sortedCategories.length,
                            itemBuilder: (context, index) {
                              final entry = sortedCategories[index];
                              final category = entry.key;
                              final stats = entry.value;
                              final percentage = totalExpenses > 0
                                  ? (stats.totalAmount / totalExpenses) * 100
                                  : 0.0;

                              return _CategoryCard(
                                category: category,
                                stats: stats,
                                percentage: percentage,
                                currencySymbol: currencySymbol,
                                color: _getCategoryColor(category),
                                icon: _getCategoryIcon(category),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Category statistics data class
class CategoryStats {
  final ExpenseCategory category;
  final int count;
  final double totalAmount;

  CategoryStats({
    required this.category,
    required this.count,
    required this.totalAmount,
  });
}

/// Small stat card widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

/// Individual category card widget
class _CategoryCard extends StatelessWidget {
  final ExpenseCategory category;
  final CategoryStats stats;
  final double percentage;
  final String currencySymbol;
  final Color color;
  final IconData icon;

  const _CategoryCard({
    required this.category,
    required this.stats,
    required this.percentage,
    required this.currencySymbol,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.count} ${stats.count == 1 ? 'expense' : 'expenses'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currencySymbol ${stats.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (stats.count > 0) ...[
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
