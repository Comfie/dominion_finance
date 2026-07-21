import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';

/// Pie chart displaying spending breakdown by category
class SpendingByCategoryChart extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final String currencySymbol;

  const SpendingByCategoryChart({
    super.key,
    required this.categoryTotals,
    required this.currencySymbol,
  });

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'GROCERIES':
        return Colors.green;
      case 'TRANSPORT':
        return Colors.blue;
      case 'DINING':
        return Colors.orange;
      case 'ENTERTAINMENT':
        return Colors.purple;
      case 'UTILITIES':
        return Colors.amber;
      case 'SHOPPING':
        return Colors.pink;
      case 'HOUSING':
        return Colors.brown;
      case 'INSURANCE':
        return Colors.indigo;
      case 'LIVING':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatCategoryName(String category) {
    return category.toLowerCase().replaceFirst(
          category[0],
          category[0].toUpperCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) {
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
                Icons.pie_chart_outline_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No spending data',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final total = categoryTotals.values.fold<double>(0, (sum, value) => sum + value);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 categories and group the rest as "Other"
    final topCategories = sortedCategories.take(5).toList();
    final otherTotal = sortedCategories.skip(5).fold<double>(0, (sum, e) => sum + e.value);

    if (otherTotal > 0) {
      topCategories.add(MapEntry('OTHER', otherTotal));
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending by Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '$currencySymbol ${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Pie chart
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: topCategories.asMap().entries.map((entry) {
                        final category = entry.value.key;
                        final amount = entry.value.value;
                        final percentage = (amount / total) * 100;
                        final color = _getCategoryColor(category);

                        return PieChartSectionData(
                          color: color,
                          value: amount,
                          title: '${percentage.toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: topCategories.map((entry) {
                      final category = entry.key;
                      final amount = entry.value;
                      final color = _getCategoryColor(category);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatCategoryName(category),
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
