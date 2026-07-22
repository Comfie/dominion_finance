import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/scooped_header.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(expensesProvider.notifier).deleteExpense(id);
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense deleted' : 'Failed to delete expense'),
            backgroundColor: success ? appColors.success : colorScheme.error,
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

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

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
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScoopedHeader(
                  background: colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _showSearch
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: TextStyle(color: colorScheme.onPrimary),
                                    cursorColor: colorScheme.onPrimary,
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      hintText: 'Search expenses...',
                                      hintStyle: TextStyle(
                                        color: colorScheme.onPrimary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  )
                                : Text(
                                    'Expenses',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          if (expensesState.expenses.isNotEmpty)
                            IconButton(
                              icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
                              color: colorScheme.onPrimary,
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
                          if (expensesState.expenses.isNotEmpty && !_showSearch)
                            PopupMenuButton<String>(
                              icon: Icon(
                                _selectedCategory != null
                                    ? Icons.filter_alt_rounded
                                    : Icons.filter_alt_outlined,
                                color: colorScheme.onPrimary,
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
                                ...[
                                  Category.GROCERIES,
                                  Category.TRANSPORT,
                                  Category.DINING,
                                  Category.ENTERTAINMENT,
                                  Category.UTILITIES,
                                  Category.SHOPPING,
                                  Category.HOUSING,
                                  Category.INSURANCE,
                                  Category.LIVING,
                                  Category.OTHER,
                                ].map((cat) => PopupMenuItem(
                                      value: cat.name,
                                      child: Text(cat.displayName),
                                    )),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _ExpensesHeroFigure(
                        amount: expensesState.totalExpenses,
                        currencySymbol: currencySymbol,
                        itemCount: filteredExpenses.length,
                        textColor: colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        MonthSelector(
                          currentMonth: expensesState.currentMonth,
                          onMonthChanged: (month) {
                            ref.read(expensesProvider.notifier).setMonth(month);
                          },
                        ),
                        const Spacer(),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (expensesState.isLoading)
                      const ListScreenSkeleton()
                    else if (filteredExpenses.isEmpty)
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
                                _searchQuery.isNotEmpty
                                    ? 'No expenses found'
                                    : _selectedCategory != null
                                        ? 'No ${_selectedCategory!.toLowerCase()} expenses'
                                        : 'No expenses yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Tap + to add your first expense',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredExpenses.map((expense) => _ExpenseCard(
                            expense: expense,
                            currencySymbol: currencySymbol,
                            onTap: () => _showEditExpenseModal(expense),
                            onDelete: () => _deleteExpense(expense.id),
                          )),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseModal,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }
}

class _ExpensesHeroFigure extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final int itemCount;
  final Color textColor;

  const _ExpensesHeroFigure({
    required this.amount,
    required this.currencySymbol,
    required this.itemCount,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Total Expenses',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.receipt_long_rounded, color: textColor.withValues(alpha: 0.7), size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$currencySymbol ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$itemCount items',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
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

  /// Category chip tint, cycled from the theme's token palette rather than
  /// ad hoc Material colors — mirrors Dashboard's `_ExpenseItem`.
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
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final categoryColor = _getCategoryColor(context, expense.category);

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_rounded, color: colorScheme.onError),
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
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
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
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: categoryColor,
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(expense.date),
                          style: Theme.of(context).textTheme.bodySmall,
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
                          color: appColors.infoText,
                        ),
                  ),
                  if (expense.personId != null)
                    Text(
                      expense.personName ?? 'Family',
                      style: Theme.of(context).textTheme.bodySmall,
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
