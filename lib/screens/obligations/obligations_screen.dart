import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/obligation.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/forms/add_obligation_modal.dart';
import '../../widgets/forms/record_payment_modal.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/scooped_header.dart';

/// Obligations (Monthly Bills) screen with payment tracking
/// Follows SKILL.md guidelines for proper state management and widget composition
class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  bool _showInactive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    // Load obligations on screen init using microtask
    Future.microtask(() {
      ref.read(obligationsProvider.notifier).loadObligations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    await ref.read(obligationsProvider.notifier).loadObligations();
  }

  /// Show add obligation modal
  void _showAddObligationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddObligationModal(),
    );
  }

  /// Show edit obligation modal
  void _showEditObligationModal(Obligation obligation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddObligationModal(obligation: obligation),
    );
  }

  /// Show record payment modal
  void _showRecordPaymentModal(Obligation obligation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordPaymentModal(obligation: obligation),
    );
  }

  /// Delete obligation with confirmation
  Future<void> _deleteObligation(String id) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Obligation'),
        content: const Text('Are you sure you want to delete this obligation?'),
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
      final success = await ref.read(obligationsProvider.notifier).deleteObligation(id);
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Obligation deleted' : 'Failed to delete obligation'),
            backgroundColor: success ? appColors.success : colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obligationsState = ref.watch(obligationsProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Filter obligations by active status
    var displayedObligations = _showInactive
        ? obligationsState.obligations
        : obligationsState.activeObligations;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      displayedObligations = displayedObligations.where((obligation) {
        final name = obligation.name.toLowerCase();
        final provider = obligation.provider.toLowerCase();
        final category = obligation.category.name.toLowerCase();
        final amount = obligation.amount.toString();
        return name.contains(query) ||
               provider.contains(query) ||
               category.contains(query) ||
               amount.contains(query);
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
                                      hintText: 'Search bills...',
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
                                    'Monthly Bills',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          if (obligationsState.obligations.isNotEmpty)
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
                          if (!_showSearch)
                            IconButton(
                              icon: Icon(_showInactive ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                              color: colorScheme.onPrimary,
                              tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
                              onPressed: () {
                                setState(() {
                                  _showInactive = !_showInactive;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _BillsHeroFigure(
                        amount: obligationsState.totalMonthlyAmount,
                        currencySymbol: currencySymbol,
                        paidCount: obligationsState.paidCount,
                        unpaidCount: obligationsState.unpaidCount,
                        textColor: colorScheme.onPrimary,
                        successColor: appColors.success,
                        warningColor: appColors.warning,
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
                        Expanded(
                          child: _CategoryStat(
                            label: 'Fixed',
                            amount: obligationsState.totalUncompromised,
                            currencySymbol: currencySymbol,
                            color: colorScheme.primary,
                            icon: Icons.lock_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CategoryStat(
                            label: 'Variable',
                            amount: obligationsState.totalVariable,
                            currencySymbol: currencySymbol,
                            color: appColors.warning,
                            icon: Icons.tune_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (obligationsState.isLoading)
                      const ListScreenSkeleton()
                    else if (displayedObligations.isEmpty)
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
                                Icons.payments_rounded,
                                size: 48,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No bills found'
                                    : _showInactive
                                        ? 'No inactive bills'
                                        : 'No bills yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Tap + to add your monthly bills',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...displayedObligations.map((obligation) => _ObligationCard(
                            obligation: obligation,
                            currencySymbol: currencySymbol,
                            onTap: () => _showEditObligationModal(obligation),
                            onPayment: () => _showRecordPaymentModal(obligation),
                            onDelete: () => _deleteObligation(obligation.id),
                          )),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddObligationModal,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Bill'),
      ),
    );
  }
}

class _BillsHeroFigure extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final int paidCount;
  final int unpaidCount;
  final Color textColor;
  final Color successColor;
  final Color warningColor;

  const _BillsHeroFigure({
    required this.amount,
    required this.currencySymbol,
    required this.paidCount,
    required this.unpaidCount,
    required this.textColor,
    required this.successColor,
    required this.warningColor,
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
                    'Total Monthly Bills',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.payments_rounded, color: textColor.withValues(alpha: 0.7), size: 18),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusChip(label: 'Paid', count: paidCount, dotColor: successColor, textColor: textColor),
            const SizedBox(height: 4),
            _StatusChip(label: 'Unpaid', count: unpaidCount, dotColor: warningColor, textColor: textColor),
          ],
        ),
      ],
    );
  }
}

/// Widget to display payment status chips
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color dotColor;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display category statistics
class _CategoryStat extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;
  final Color color;
  final IconData icon;

  const _CategoryStat({
    required this.label,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

/// Individual obligation card with payment tracking
class _ObligationCard extends StatelessWidget {
  final Obligation obligation;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _ObligationCard({
    required this.obligation,
    required this.currencySymbol,
    required this.onTap,
    required this.onPayment,
    required this.onDelete,
  });

  String _formatDueDay(int dueDay) {
    if (dueDay == 1 || dueDay == 21 || dueDay == 31) {
      return '${dueDay}st';
    } else if (dueDay == 2 || dueDay == 22) {
      return '${dueDay}nd';
    } else if (dueDay == 3 || dueDay == 23) {
      return '${dueDay}rd';
    } else {
      return '${dueDay}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    final isPaid = obligation.isPaidThisMonth;
    final isUncompromised = obligation.isUncompromised;
    final hasDebt = obligation.totalBalance != null && obligation.totalBalance! > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPaid ? appColors.success.withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Main card content
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Provider/name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              obligation.provider,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              obligation.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currencySymbol ${obligation.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: appColors.infoText,
                                ),
                          ),
                          if (hasDebt)
                            Text(
                              'Balance: $currencySymbol ${obligation.totalBalance!.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: appColors.warning,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tags and status
                  Row(
                    children: [
                      if (isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: appColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: appColors.success),
                              const SizedBox(width: 4),
                              Text(
                                'Paid',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: appColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: appColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Unpaid',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: appColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUncompromised
                              ? colorScheme.secondary.withValues(alpha: 0.1)
                              : (mutedColor ?? Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isUncompromised ? 'Fixed' : 'Variable',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isUncompromised ? colorScheme.secondary : mutedColor,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Due ${_formatDueDay(obligation.debitOrderDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action buttons
          if (!isPaid) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: appColors.surfaceElevated),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onPayment,
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Record Payment'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
