import 'package:flutter/material.dart';

/// Date range filter widget for filtering lists by date
/// Follows SKILL.md guidelines for proper widget composition
class DateRangeFilter extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onClear;
  final Function(DateTimeRange) onSelect;

  const DateRangeFilter({
    super.key,
    this.dateRange,
    required this.onClear,
    required this.onSelect,
  });

  // Two sequential showDatePicker calls instead of showDateRangePicker: the
  // range picker forces a full-screen dialog in portrait with no year-grid
  // shortcut (month-by-month paging only), while showDatePicker is a compact
  // dialog whose header can be tapped to jump straight to a year grid.
  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 365));

    final start = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      initialDate: dateRange?.start ?? now,
      helpText: 'Start date',
    );
    if (start == null || !context.mounted) return;

    final end = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: lastDate,
      initialDate: dateRange?.end.isBefore(start) ?? false ? start : (dateRange?.end ?? start),
      helpText: 'End date',
    );
    if (end == null) return;

    onSelect(DateTimeRange(start: start, end: end));
  }

  String _formatDateRange(DateTimeRange range) {
    final start = '${range.start.day}/${range.start.month}/${range.start.year}';
    final end = '${range.end.day}/${range.end.month}/${range.end.year}';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = dateRange != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _selectDateRange(context),
          icon: Icon(isActive ? Icons.event_available_rounded : Icons.calendar_month_rounded),
          tooltip: isActive ? _formatDateRange(dateRange!) : 'Select date range',
          style: IconButton.styleFrom(
            backgroundColor: isActive ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surface,
            foregroundColor: isActive ? colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            tooltip: 'Clear date filter',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.error.withValues(alpha: 0.1),
              foregroundColor: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
