import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/month_selector.dart';
import '../../widgets/forms/add_expense_modal.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/loading_skeleton.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _selectedCategory;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(expensesProvider.notifier).loadExpenses();
  }

  void _showAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddExpenseModal(),
    );
  }

  void _showEditExpenseModal(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseModal(expense: expense),
    );
  }

  Future<void> _deleteExpense(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(expensesProvider.notifier).deleteExpense(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense deleted' : 'Failed to delete expense'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    // Filter by category
    var filteredExpenses = _selectedCategory == null
        ? expensesState.expenses
        : expensesState.expenses
            .where((e) => e.category.name == _selectedCategory)
            .toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredExpenses = filteredExpenses.where((expense) {
        final name = expense.name.toLowerCase();
        final category = expense.category.name.toLowerCase();
        final amount = expense.amount.toString();
        return name.contains(query) ||
               category.contains(query) ||
               amount.contains(query);
      }).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filteredExpenses = filteredExpenses.where((expense) {
        final expenseDate = DateTime(
          expense.date.year,
          expense.date.month,
          expense.date.day,
        );
        final startDate = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endDate = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        );
        return expenseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               expenseDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search expenses...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white60),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Expenses'),
        actions: [
          if (expensesState.expenses.isNotEmpty)
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
          if (filteredExpenses.isNotEmpty && !_showSearch)
            PopupMenuButton<String>(
              icon: Icon(
                _selectedCategory != null
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onSelected: (category) {
                setState(() {
                  _selectedCategory = category == 'ALL' ? null : category;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ALL',
                  child: Text('All Categories'),
                ),
                const PopupMenuDivider(),
                ...['GROCERIES', 'TRANSPORT', 'DINING', 'ENTERTAINMENT', 'UTILITIES', 'SHOPPING', 'HOUSING', 'INSURANCE', 'LIVING', 'OTHER']
                    .map((cat) => PopupMenuItem(
                          value: cat,
                          child: Text(cat.toLowerCase().replaceFirst(
                                cat[0],
                                cat[0].toUpperCase(),
                              )),
                        ))
                    .toList(),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              child: Column(
                children: [
                  MonthSelector(
                    currentMonth: expensesState.currentMonth,
                    onMonthChanged: (month) {
                      ref.read(expensesProvider.notifier).setMonth(month);
                    },
                  ),
                  const SizedBox(height: 8),
                  DateRangeFilter(
                    dateRange: _dateRange,
                    onClear: () {
                      setState(() {
                        _dateRange = null;
                      });
                    },
                    onSelect: (range) {
                      setState(() {
                        _dateRange = range;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.error, AppTheme.error.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Expenses',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$currencySymbol ${expensesState.totalExpenses.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filteredExpenses.length} items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: expensesState.isLoading
                  ? const ListScreenSkeleton()
                  : filteredExpenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 64,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No expenses found'
                                    : _selectedCategory != null
                                        ? 'No ${_selectedCategory!.toLowerCase()} expenses'
                                        : 'No expenses yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Tap + to add your first expense',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredExpenses.length,
                            itemBuilder: (context, index) {
                              final expense = filteredExpenses[index];
                              return _ExpenseCard(
                                expense: expense,
                                currencySymbol: currencySymbol,
                                onTap: () => _showEditExpenseModal(expense),
                                onDelete: () => _deleteExpense(expense.id),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today';
    } else if (expenseDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Expense'),
            content: const Text('Are you sure you want to delete this expense?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (direction) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(expense.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: _getCategoryColor(expense.category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          expense.category.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(expense.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-$currencySymbol ${expense.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.error,
                        ),
                  ),
                  if (expense.personId != null)
                    Text(
                      expense.personName ?? 'Family',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
