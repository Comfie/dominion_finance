import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/incomes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/month_selector.dart';
import '../../widgets/forms/add_income_modal.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/loading_skeleton.dart';

/// Income list screen with filtering, pull-to-refresh, and CRUD operations
/// Follows SKILL.md guidelines for proper state management and widget composition
class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  IncomeSource? _selectedSource;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Load incomes on screen init using microtask
    Future.microtask(() {
      ref.read(incomesProvider.notifier).loadIncomes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    await ref.read(incomesProvider.notifier).loadIncomes();
  }

  /// Show add income modal
  void _showAddIncomeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddIncomeModal(),
    );
  }

  /// Show edit income modal
  void _showEditIncomeModal(dynamic income) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddIncomeModal(income: income),
    );
  }

  /// Delete income with confirmation
  Future<void> _deleteIncome(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Income'),
        content: const Text('Are you sure you want to delete this income entry?'),
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
      final success = await ref.read(incomesProvider.notifier).deleteIncome(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Income deleted' : 'Failed to delete income'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomesState = ref.watch(incomesProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    // Filter incomes by selected source
    var filteredIncomes = _selectedSource == null
        ? incomesState.incomes
        : incomesState.incomes
            .where((i) => i.source == _selectedSource)
            .toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredIncomes = filteredIncomes.where((income) {
        final name = income.name.toLowerCase();
        final source = income.source.name.toLowerCase();
        final amount = income.amount.toString();
        return name.contains(query) ||
               source.contains(query) ||
               amount.contains(query);
      }).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filteredIncomes = filteredIncomes.where((income) {
        final incomeDate = DateTime(
          income.date.year,
          income.date.month,
          income.date.day,
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
        return incomeDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               incomeDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search income...',
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
            : const Text('Income'),
        actions: [
          if (incomesState.incomes.isNotEmpty)
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
          if (filteredIncomes.isNotEmpty && !_showSearch)
            PopupMenuButton<String>(
              icon: Icon(
                _selectedSource != null
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onSelected: (source) {
                setState(() {
                  _selectedSource = source == 'ALL' ? null : IncomeSource.values.firstWhere((s) => s.name == source);
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ALL',
                  child: Text('All Sources'),
                ),
                const PopupMenuDivider(),
                ...IncomeSource.values
                    .map((source) => PopupMenuItem(
                          value: source.name,
                          child: Text(_formatSourceName(source)),
                        ))
                    .toList(),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary card section
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              child: Column(
                children: [
                  MonthSelector(
                    currentMonth: incomesState.currentMonth,
                    onMonthChanged: (month) {
                      ref.read(incomesProvider.notifier).setMonth(month);
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
                  // Total income summary card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.success, AppTheme.success.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Additional Income',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$currencySymbol ${incomesState.totalIncome.toStringAsFixed(2)}',
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
                                '${filteredIncomes.length} items',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Recurring vs One-time breakdown
                        Row(
                          children: [
                            Expanded(
                              child: _IncomeStat(
                                label: 'Recurring',
                                amount: incomesState.recurringIncome,
                                currencySymbol: currencySymbol,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _IncomeStat(
                                label: 'One-time',
                                amount: incomesState.oneTimeIncome,
                                currencySymbol: currencySymbol,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Income list section
            Expanded(
              child: incomesState.isLoading
                  ? const ListScreenSkeleton()
                  : filteredIncomes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money_rounded,
                                size: 64,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No income found'
                                    : _selectedSource != null
                                        ? 'No ${_formatSourceName(_selectedSource!).toLowerCase()} income'
                                        : 'No extra income yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Tap + to add extra income',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredIncomes.length,
                            itemBuilder: (context, index) {
                              final income = filteredIncomes[index];
                              return _IncomeCard(
                                income: income,
                                currencySymbol: currencySymbol,
                                onTap: () => _showEditIncomeModal(income),
                                onDelete: () => _deleteIncome(income.id),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIncomeModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  /// Format income source name for display
  String _formatSourceName(IncomeSource source) {
    return source.name.toLowerCase().replaceFirst(
          source.name[0],
          source.name[0].toUpperCase(),
        );
  }
}

/// Widget to display income statistics (recurring/one-time)
class _IncomeStat extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;

  const _IncomeStat({
    required this.label,
    required this.amount,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$currencySymbol ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual income card widget with swipe-to-delete and tap-to-edit
class _IncomeCard extends StatelessWidget {
  final dynamic income;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _IncomeCard({
    required this.income,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getSourceIcon(IncomeSource source) {
    switch (source) {
      case IncomeSource.SALARY:
        return Icons.work_rounded;
      case IncomeSource.FREELANCE:
        return Icons.laptop_rounded;
      case IncomeSource.INVESTMENT:
        return Icons.trending_up_rounded;
      case IncomeSource.BUSINESS:
        return Icons.business_rounded;
      case IncomeSource.RENTAL:
        return Icons.home_work_rounded;
      case IncomeSource.GIFT:
        return Icons.card_giftcard_rounded;
      case IncomeSource.REFUND:
        return Icons.payment_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Color _getSourceColor(IncomeSource source) {
    switch (source) {
      case IncomeSource.SALARY:
        return Colors.blue;
      case IncomeSource.FREELANCE:
        return Colors.purple;
      case IncomeSource.INVESTMENT:
        return Colors.green;
      case IncomeSource.BUSINESS:
        return Colors.orange;
      case IncomeSource.RENTAL:
        return Colors.teal;
      case IncomeSource.GIFT:
        return Colors.pink;
      case IncomeSource.REFUND:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final incomeDate = DateTime(date.year, date.month, date.day);

    if (incomeDate == today) {
      return 'Today';
    } else if (incomeDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatSourceName(IncomeSource source) {
    return source.name.toLowerCase().replaceFirst(
          source.name[0],
          source.name[0].toUpperCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(income.id),
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
            title: const Text('Delete Income'),
            content: const Text('Are you sure you want to delete this income entry?'),
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
              // Source icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSourceColor(income.source).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSourceIcon(income.source),
                  color: _getSourceColor(income.source),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Income details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income.name,
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
                          _formatSourceName(income.source),
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
                          _formatDate(income.date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                        if (income.isRecurring) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Recurring',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.success,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '+$currencySymbol ${income.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
