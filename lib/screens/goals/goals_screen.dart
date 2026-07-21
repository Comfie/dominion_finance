import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/goals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/forms/add_goal_modal.dart';
import '../../widgets/forms/add_funds_modal.dart';
import '../../widgets/loading_skeleton.dart';

/// Savings goals screen with progress tracking, filtering, and CRUD operations
/// Follows SKILL.md guidelines for proper state management and widget composition
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    // Load goals on screen init using microtask
    Future.microtask(() {
      ref.read(goalsProvider.notifier).loadGoals();
    });
  }

  /// Handle pull-to-refresh
  Future<void> _onRefresh() async {
    await ref.read(goalsProvider.notifier).loadGoals();
  }

  /// Show add goal modal
  void _showAddGoalModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddGoalModal(),
    );
  }

  /// Show edit goal modal
  void _showEditGoalModal(dynamic goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGoalModal(goal: goal),
    );
  }

  /// Show add funds modal
  void _showAddFundsModal(dynamic goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFundsModal(goal: goal),
    );
  }

  /// Delete goal with confirmation
  Future<void> _deleteGoal(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this savings goal?'),
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
      final success = await ref.read(goalsProvider.notifier).deleteGoal(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Goal deleted' : 'Failed to delete goal'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsState = ref.watch(goalsProvider);
    final settingsState = ref.watch(settingsProvider);
    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    // Filter goals by completion status
    final filteredGoals = _showCompleted
        ? goalsState.completedGoals
        : goalsState.activeGoals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          if (goalsState.goals.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                _showCompleted
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
              ),
              onSelected: (value) {
                setState(() {
                  _showCompleted = value == 'COMPLETED';
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ACTIVE',
                  child: Text('Active Goals'),
                ),
                const PopupMenuItem(
                  value: 'COMPLETED',
                  child: Text('Completed Goals'),
                ),
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
                  // Total savings summary card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.info, AppTheme.info.withOpacity(0.8)],
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
                                  'Total Saved',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$currencySymbol ${goalsState.totalSaved.toStringAsFixed(2)}',
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
                                '${filteredGoals.length} goals',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Total target and overall progress
                        Row(
                          children: [
                            Expanded(
                              child: _SavingsStat(
                                label: 'Target',
                                amount: goalsState.totalTarget,
                                currencySymbol: currencySymbol,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Progress',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      goalsState.totalTarget > 0
                                          ? '${((goalsState.totalSaved / goalsState.totalTarget) * 100).toStringAsFixed(0)}%'
                                          : '0%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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
            // Goals list section
            Expanded(
              child: goalsState.isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 3,
                      itemBuilder: (context, index) => const GoalCardSkeleton(),
                    )
                  : filteredGoals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.savings_rounded,
                                size: 64,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _showCompleted
                                    ? 'No completed goals yet'
                                    : 'No active goals yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to create your first savings goal',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredGoals.length,
                            itemBuilder: (context, index) {
                              final goal = filteredGoals[index];
                              return _GoalCard(
                                goal: goal,
                                currencySymbol: currencySymbol,
                                onTap: () => _showEditGoalModal(goal),
                                onDelete: () => _deleteGoal(goal.id),
                                onAddFunds: () => _showAddFundsModal(goal),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
        backgroundColor: AppTheme.info,
      ),
    );
  }
}

/// Widget to display savings statistics (target amount)
class _SavingsStat extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;

  const _SavingsStat({
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

/// Individual goal card widget with progress indicators and actions
class _GoalCard extends StatelessWidget {
  final dynamic goal;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAddFunds;

  const _GoalCard({
    required this.goal,
    required this.currencySymbol,
    required this.onTap,
    required this.onDelete,
    required this.onAddFunds,
  });

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.EMERGENCY_FUND:
        return Icons.health_and_safety_rounded;
      case GoalCategory.HOLIDAY:
        return Icons.beach_access_rounded;
      case GoalCategory.CAR:
        return Icons.directions_car_rounded;
      case GoalCategory.HOME:
        return Icons.home_rounded;
      case GoalCategory.EDUCATION:
        return Icons.school_rounded;
      case GoalCategory.WEDDING:
        return Icons.favorite_rounded;
      case GoalCategory.RETIREMENT:
        return Icons.elderly_rounded;
      default:
        return Icons.savings_rounded;
    }
  }

  Color _getColorFromHex(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.info;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No target date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference <= 30) {
      return '$difference days left';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorFromHex(goal.color);
    final progress = goal.progressPercentage / 100;

    return Dismissible(
      key: Key(goal.id),
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
            title: const Text('Delete Goal'),
            content: const Text('Are you sure you want to delete this savings goal?'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon, name, and amount
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(goal.category),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Goal name and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal.category.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Current amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currencySymbol ${goal.currentAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                      Text(
                        'of $currencySymbol ${goal.targetAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (goal.targetDate != null)
                        Text(
                          _formatDate(goal.targetDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: goal.targetDate.isBefore(DateTime.now())
                                    ? AppTheme.error
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 1.0 ? 1.0 : progress,
                      minHeight: 8,
                      backgroundColor: color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
              // Add funds button (only for active goals)
              if (!goal.isCompleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddFunds,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Funds'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                    ),
                  ),
                ),
              ],
              // Completed badge
              if (goal.isCompleted) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Goal Completed!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
