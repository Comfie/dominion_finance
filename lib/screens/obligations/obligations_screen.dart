import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/loading_skeleton.dart';

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

  /// Show add obligation modal (placeholder)
  void _showAddObligationModal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add obligation modal coming soon!')),
    );
  }

  /// Show edit obligation modal (placeholder)
  void _showEditObligationModal(dynamic obligation) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit obligation modal coming soon!')),
    );
  }

  /// Record payment for an obligation
  Future<void> _recordPayment(dynamic obligation) async {
    final amountController = TextEditingController(text: obligation.amount.toString());
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Payment for ${obligation.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'R ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final notes = notesController.text.trim();
      final success = await ref.read(obligationsProvider.notifier).recordPayment(
            obligation.id,
            amount,
            notes: notes.isEmpty ? null : notes,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Payment recorded' : 'Failed to record payment'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    }

    amountController.dispose();
    notesController.dispose();
  }

  /// Delete obligation with confirmation
  Future<void> _deleteObligation(String id) async {
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
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(obligationsProvider.notifier).deleteObligation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Obligation deleted' : 'Failed to delete obligation'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
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

    // Filter obligations by active status
    var displayedObligations = _showInactive
        ? obligationsState.obligations
        : obligationsState.activeObligations;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      displayedObligations = displayedObligations.where((obligation) {
        final name = obligation.name.toLowerCase();
        final provider = obligation.provider?.toLowerCase() ?? '';
        final category = obligation.category.name.toLowerCase();
        final amount = obligation.amount.toString();
        return name.contains(query) ||
               provider.contains(query) ||
               category.contains(query) ||
               amount.contains(query);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search bills...',
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
            : const Text('Monthly Bills'),
        actions: [
          if (obligationsState.obligations.isNotEmpty)
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
          if (!_showSearch)
            IconButton(
              icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _showInactive = !_showInactive;
                });
              },
              tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary cards section
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              child: Column(
                children: [
                  // Total obligations card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.8)],
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
                                  'Total Monthly Bills',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$currencySymbol ${obligationsState.totalMonthlyAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                _StatusChip(
                                  label: 'Paid',
                                  count: obligationsState.paidCount,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(height: 4),
                                _StatusChip(
                                  label: 'Unpaid',
                                  count: obligationsState.unpaidCount,
                                  color: AppTheme.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Category breakdown
                        Row(
                          children: [
                            Expanded(
                              child: _CategoryStat(
                                label: 'Fixed',
                                amount: obligationsState.totalUncompromised,
                                currencySymbol: currencySymbol,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CategoryStat(
                                label: 'Variable',
                                amount: obligationsState.totalVariable,
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
            // Obligations list section
            Expanded(
              child: obligationsState.isLoading
                  ? const ListScreenSkeleton()
                  : displayedObligations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                size: 64,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No bills found'
                                    : _showInactive
                                        ? 'No inactive bills'
                                        : 'No bills yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Tap + to add your monthly bills',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: displayedObligations.length,
                            itemBuilder: (context, index) {
                              final obligation = displayedObligations[index];
                              return _ObligationCard(
                                obligation: obligation,
                                currencySymbol: currencySymbol,
                                onTap: () => _showEditObligationModal(obligation),
                                onPayment: () => _recordPayment(obligation),
                                onDelete: () => _deleteObligation(obligation.id),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddObligationModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
        backgroundColor: AppTheme.warning,
      ),
    );
  }
}

/// Widget to display payment status chips
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: const TextStyle(
              color: Colors.white,
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

  const _CategoryStat({
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

/// Individual obligation card with payment tracking
class _ObligationCard extends StatelessWidget {
  final dynamic obligation;
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
    final isPaid = obligation.isPaidThisMonth;
    final isUncompromised = obligation.isUncompromised;
    final hasDebt = obligation.totalBalance != null && obligation.totalBalance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? AppTheme.success.withOpacity(0.3) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main card content
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
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
                                  color: AppTheme.warning,
                                ),
                          ),
                          if (hasDebt)
                            Text(
                              'Balance: $currencySymbol ${obligation.totalBalance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.error,
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
                            color: AppTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                              const SizedBox(width: 4),
                              Text(
                                'Paid',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.success,
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
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unpaid',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUncompromised
                              ? AppTheme.info.withOpacity(0.1)
                              : AppTheme.textMuted.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUncompromised ? 'Fixed' : 'Variable',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isUncompromised ? AppTheme.info : AppTheme.textMuted,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Due ${_formatDueDay(obligation.dueDay)}',
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
          // Action buttons
          if (!isPaid)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.payment),
                      label: const Text('Record Payment'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
