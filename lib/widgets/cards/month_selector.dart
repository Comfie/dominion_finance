import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthSelector extends StatelessWidget {
  final String currentMonth;
  final ValueChanged<String> onMonthChanged;

  const MonthSelector({
    super.key,
    required this.currentMonth,
    required this.onMonthChanged,
  });

  DateTime get _currentDate {
    final parts = currentMonth.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  void _previousMonth() {
    final prev = DateTime(_currentDate.year, _currentDate.month - 1);
    onMonthChanged('${prev.year}-${prev.month.toString().padLeft(2, '0')}');
  }

  void _nextMonth() {
    final next = DateTime(_currentDate.year, _currentDate.month + 1);
    final now = DateTime.now();
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      onMonthChanged('${next.year}-${next.month.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMonth = DateFormat('MMMM yyyy').format(_currentDate);
    final now = DateTime.now();
    final isCurrentMonth = _currentDate.year == now.year && _currentDate.month == now.month;

    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    final secondaryColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _previousMonth,
            color: secondaryColor,
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              displayMonth,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isCurrentMonth ? mutedColor : secondaryColor,
            ),
            onPressed: isCurrentMonth ? null : _nextMonth,
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
