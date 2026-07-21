import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';

/// Bar chart displaying progress of savings goals
class GoalsProgressChart extends StatelessWidget {
  final List<SavingsGoal> goals;
  final String currencySymbol;

  const GoalsProgressChart({
    super.key,
    required this.goals,
    required this.currencySymbol,
  });

  Color _getColorFromHex(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.savings_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No goals yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Take top 5 goals by progress percentage
    final sortedGoals = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    final topGoals = sortedGoals.take(5).toList();

    if (topGoals.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppTheme.success,
              ),
              const SizedBox(height: 12),
              Text(
                'All goals completed!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.success,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goals Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final goal = topGoals[group.x.toInt()];
                      return BarTooltipItem(
                        '${goal.name}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$currencySymbol ${goal.currentAmount.toStringAsFixed(0)} / $currencySymbol ${goal.targetAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= topGoals.length) {
                          return const SizedBox();
                        }
                        final goal = topGoals[value.toInt()];
                        final name = goal.name.length > 8
                            ? '${goal.name.substring(0, 8)}...'
                            : goal.name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.textMuted.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: topGoals.asMap().entries.map((entry) {
                  final index = entry.key;
                  final goal = entry.value;
                  final color = _getColorFromHex(goal.color);

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: goal.progressPercentage,
                        color: color,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
