import 'package:flutter/material.dart';
import '../core/theme.dart';

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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onSelect(picked);
    }
  }

  String _formatDateRange(DateTimeRange range) {
    final start = '${range.start.day}/${range.start.month}/${range.start.year}';
    final end = '${range.end.day}/${range.end.month}/${range.end.year}';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _selectDateRange(context),
              icon: const Icon(Icons.date_range),
              label: Text(
                dateRange != null
                    ? _formatDateRange(dateRange!)
                    : 'Select date range',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          if (dateRange != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.error.withOpacity(0.1),
                foregroundColor: AppTheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
