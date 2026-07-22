import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/goals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/forms/add_goal_modal.dart';
import '../../widgets/forms/add_funds_modal.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/scooped_header.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(goalsProvider.notifier).deleteGoal(id);
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Goal deleted' : 'Failed to delete goal'),
            backgroundColor: success ? appColors.success : colorScheme.error,
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

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Filter goals by completion status
    final filteredGoals = _showCompleted
        ? goalsState.completedGoals
        : goalsState.activeGoals;

    final overallProgress = goalsState.totalTarget > 0
        ? (goalsState.totalSaved / goalsState.totalTarget) * 100
        : 0.0;

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
                            child: Text(
                              'Savings Goals',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (goalsState.goals.isNotEmpty)
                            PopupMenuButton<String>(
                              icon: Icon(
                                _showCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: colorScheme.onPrimary,
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
                      const SizedBox(height: 24),
                      _GoalsHeroFigure(
                        amount: goalsState.totalSaved,
                        currencySymbol: currencySymbol,
                        goalCount: filteredGoals.length,
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
                        Expanded(
                          child: _CategoryStat(
                            label: 'Target',
                            amount: goalsState.totalTarget,
                            currencySymbol: currencySymbol,
                            color: colorScheme.secondary,
                            icon: Icons.flag_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProgressStat(
                            percentage: overallProgress,
                            color: appColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (goalsState.isLoading)
                      ...List.generate(3, (_) => const GoalCardSkeleton())
                    else if (filteredGoals.isEmpty)
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
                                Icons.savings_rounded,
                                size: 48,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _showCompleted
                                    ? 'No completed goals yet'
                                    : 'No active goals yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap + to create your first savings goal',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredGoals.map((goal) => _GoalCard(
                            goal: goal,
                            currencySymbol: currencySymbol,
                            onTap: () => _showEditGoalModal(goal),
                            onDelete: () => _deleteGoal(goal.id),
                            onAddFunds: () => _showAddFundsModal(goal),
                          )),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalModal,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Goal'),
      ),
    );
  }
}

class _GoalsHeroFigure extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final int goalCount;
  final Color textColor;

  const _GoalsHeroFigure({
    required this.amount,
    required this.currencySymbol,
    required this.goalCount,
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
                    'Total Saved',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.savings_rounded, color: textColor.withValues(alpha: 0.7), size: 18),
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
            '$goalCount goals',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Widget to display savings statistics (target amount)
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

/// Widget to display overall savings progress percentage
class _ProgressStat extends StatelessWidget {
  final double percentage;
  final Color color;

  const _ProgressStat({
    required this.percentage,
    required this.color,
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
                child: Icon(Icons.trending_up_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progress',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

  Color _getColorFromHex(BuildContext context, String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Theme.of(context).colorScheme.secondary;
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
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final color = _getColorFromHex(context, goal.color);
    final progress = goal.progressPercentage / 100;

    return Dismissible(
      key: Key(goal.id),
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
            title: const Text('Delete Goal'),
            content: const Text('Are you sure you want to delete this savings goal?'),
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
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getCategoryIcon(goal.category),
                      color: color,
                      size: 20,
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
                          style: Theme.of(context).textTheme.bodySmall,
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
                        style: Theme.of(context).textTheme.bodySmall,
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
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (goal.targetDate != null)
                        Text(
                          _formatDate(goal.targetDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: goal.targetDate.isBefore(DateTime.now())
                                    ? appColors.warning
                                    : null,
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
                      backgroundColor: color.withValues(alpha: 0.2),
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
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Add Funds'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      shape: const StadiumBorder(),
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
                    color: appColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: appColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Goal Completed!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: appColors.success,
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
