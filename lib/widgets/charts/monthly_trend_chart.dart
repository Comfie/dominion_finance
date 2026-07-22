import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../repositories/ai_repository.dart';

/// Line chart showing income, expenses, and net cash flow across months.
///
/// All three series share one axis deliberately (currency) — a dual-axis
/// chart is never correct here since these are three views of the same unit.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyTrend> trends;
  final String currencySymbol;

  const MonthlyTrendChart({super.key, required this.trends, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final textMuted = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    if (trends.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(24)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart_rounded, size: 48, color: textMuted),
              const SizedBox(height: 12),
              Text('No trend data yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textMuted)),
            ],
          ),
        ),
      );
    }

    final allValues = trends.expand((t) => [t.totalIncome, t.totalExpenses, t.netCashFlow]);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final minY = allValues.reduce((a, b) => a < b ? a : b);

    Widget legendDot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    List<FlSpot> spotsFor(double Function(MonthlyTrend) selector) {
      return trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList();
    }

    LineChartBarData seriesFor(Color color, double Function(MonthlyTrend) selector) {
      return LineChartBarData(
        spots: spotsFor(selector),
        isCurved: false,
        color: color,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) =>
              FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: colorScheme.surface),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Trend', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              legendDot(appColors.success, 'Income'),
              legendDot(colorScheme.error, 'Expenses'),
              legendDot(colorScheme.primary, 'Net'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY < 0 ? minY * 1.1 : 0,
                maxY: maxY * 1.1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: textMuted.withValues(alpha: 0.15), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= trends.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(trends[i].month, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => colorScheme.inverseSurface,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final trend = trends[spot.x.toInt()];
                      final onTooltip = colorScheme.onInverseSurface;
                      return LineTooltipItem(
                        '${trend.month}\n$currencySymbol ${spot.y.toStringAsFixed(2)}',
                        TextStyle(color: onTooltip, fontSize: 11, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  seriesFor(appColors.success, (t) => t.totalIncome),
                  seriesFor(colorScheme.error, (t) => t.totalExpenses),
                  seriesFor(colorScheme.primary, (t) => t.netCashFlow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
