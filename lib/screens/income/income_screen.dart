import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/income.dart';
import '../../providers/incomes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/app_card.dart';
import '../../widgets/cards/month_selector.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/forms/add_income_modal.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/scooped_header.dart';

/// Income list screen with filtering, pull-to-refresh, and CRUD operations.
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
    Future.microtask(() {
      ref.read(incomesProvider.notifier).loadIncomes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(incomesProvider.notifier).loadIncomes();
  }

  void _showAddIncomeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddIncomeModal(),
    );
  }

  void _showEditIncomeModal(Income income) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddIncomeModal(income: income),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteIncome(String id) async {
    final confirmed = await _confirmDelete(context);
    if (confirmed && mounted) {
      final success = await ref.read(incomesProvider.notifier).deleteIncome(id);
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Income deleted' : 'Failed to delete income'),
            backgroundColor: success ? appColors.success : colorScheme.error,
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

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    var filteredIncomes = _selectedSource == null
        ? incomesState.incomes
        : incomesState.incomes.where((i) => i.source == _selectedSource).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredIncomes = filteredIncomes.where((income) {
        final name = income.name.toLowerCase();
        final source = income.source.name.toLowerCase();
        final amount = income.amount.toString();
        return name.contains(query) || source.contains(query) || amount.contains(query);
      }).toList();
    }

    if (_dateRange != null) {
      filteredIncomes = filteredIncomes.where((income) {
        final incomeDate = DateTime(income.date.year, income.date.month, income.date.day);
        final startDate = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endDate = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        return incomeDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            incomeDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    // The teal hero draws behind the (transparent) status bar, so this
    // screen needs dark status icons regardless of theme brightness — same
    // treatment as ExpensesScreen.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: appColors.surfaceElevated,
      systemNavigationBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
                                      hintText: 'Search income...',
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
                                    'Income',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          if (incomesState.incomes.isNotEmpty)
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
                          if (filteredIncomes.isNotEmpty && !_showSearch)
                            PopupMenuButton<String>(
                              icon: Icon(
                                _selectedSource != null
                                    ? Icons.filter_alt_rounded
                                    : Icons.filter_alt_outlined,
                                color: colorScheme.onPrimary,
                              ),
                              onSelected: (source) {
                                setState(() {
                                  _selectedSource = source == 'ALL'
                                      ? null
                                      : IncomeSource.values.firstWhere((s) => s.name == source);
                                });
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'ALL', child: Text('All Sources')),
                                const PopupMenuDivider(),
                                ...IncomeSource.values.map(
                                  (source) => PopupMenuItem(
                                    value: source.name,
                                    child: Text(source.displayName),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _IncomeHeroFigure(
                        amount: incomesState.totalIncome,
                        currencySymbol: currencySymbol,
                        itemCount: filteredIncomes.length,
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
                          currentMonth: incomesState.currentMonth,
                          onMonthChanged: (month) {
                            ref.read(incomesProvider.notifier).setMonth(month);
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
                    _IncomeBreakdownRow(
                      recurring: incomesState.recurringIncome,
                      oneTime: incomesState.oneTimeIncome,
                      currencySymbol: currencySymbol,
                    ),
                    const SizedBox(height: 16),
                    if (incomesState.isLoading)
                      const ListScreenSkeleton()
                    else if (filteredIncomes.isEmpty)
                      AppEmptyState(
                        icon: Icons.attach_money_rounded,
                        title: _searchQuery.isNotEmpty
                            ? 'No income found'
                            : _selectedSource != null
                                ? 'No ${_selectedSource!.displayName.toLowerCase()} income'
                                : 'No extra income yet',
                        message: _searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Tap + to add extra income',
                      )
                    else
                      ...filteredIncomes.map(
                        (income) => _IncomeCard(
                          income: income,
                          currencySymbol: currencySymbol,
                          onTap: () => _showEditIncomeModal(income),
                          onDelete: () => _deleteIncome(income.id),
                          confirmDelete: _confirmDelete,
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIncomeModal,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Income'),
      ),
    );
  }
}

class _IncomeHeroFigure extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final int itemCount;
  final Color textColor;

  const _IncomeHeroFigure({
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
                    'Total Additional Income',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.attach_money_rounded, color: textColor.withValues(alpha: 0.7), size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$currencySymbol ${amount.toStringAsFixed(2)}',
                style: TextStyle(color: textColor, fontSize: 34, fontWeight: FontWeight.bold),
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

class _IncomeBreakdownRow extends StatelessWidget {
  final double recurring;
  final double oneTime;
  final String currencySymbol;

  const _IncomeBreakdownRow({
    required this.recurring,
    required this.oneTime,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BreakdownStat(label: 'Recurring', amount: recurring, currencySymbol: currencySymbol),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BreakdownStat(label: 'One-time', amount: oneTime, currencySymbol: currencySymbol),
        ),
      ],
    );
  }
}

class _BreakdownStat extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;

  const _BreakdownStat({
    required this.label,
    required this.amount,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$currencySymbol ${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  final Income income;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<bool> Function(BuildContext) confirmDelete;

  const _IncomeCard({
    required this.income,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
    required this.confirmDelete,
  });

  IconData _getSourceIcon(IncomeSource source) {
    switch (source) {
      case IncomeSource.SALARY:
        return Icons.work_rounded;
      case IncomeSource.FREELANCE:
        return Icons.laptop_rounded;
      case IncomeSource.SIDE_HUSTLE:
        return Icons.storefront_rounded;
      case IncomeSource.SALE:
        return Icons.sell_rounded;
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
      case IncomeSource.OTHER:
        return Icons.attach_money_rounded;
    }
  }

  Color _getSourceColor(BuildContext context, IncomeSource source) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final palette = [colorScheme.primary, colorScheme.secondary, appColors.warning, appColors.success];
    return palette[source.index % palette.length];
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final sourceColor = _getSourceColor(context, income.source);

    return Dismissible(
      key: Key(income.id),
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
      confirmDismiss: (direction) => confirmDelete(context),
      onDismissed: (direction) => onDelete(),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_getSourceIcon(income.source), color: sourceColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    income.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(income.source.displayName, style: Theme.of(context).textTheme.bodySmall),
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
                      Text(_formatDate(income.date), style: Theme.of(context).textTheme.bodySmall),
                      if (income.isRecurring) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: appColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Recurring',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: appColors.successText,
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
            Text(
              '+$currencySymbol ${income.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: appColors.successText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
