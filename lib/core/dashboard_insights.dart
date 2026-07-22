import '../models/obligation.dart';

/// How urgent/positive the dashboard's single "what should I do next"
/// message is — drives both icon and color in the UI layer.
enum NextActionSeverity { error, warning, success, info }

class NextAction {
  final String message;
  final NextActionSeverity severity;

  const NextAction(this.message, this.severity);

  @override
  bool operator ==(Object other) =>
      other is NextAction &&
      other.message == message &&
      other.severity == severity;

  @override
  int get hashCode => Object.hash(message, severity);
}

class UpcomingObligation {
  final Obligation obligation;
  final int daysUntilDue;

  const UpcomingObligation(this.obligation, this.daysUntilDue);
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Days from [today] until the next occurrence of [debitOrderDate] (a
/// day-of-month, 1-31). Walks forward month by month, skipping any month
/// where [debitOrderDate] exceeds that month's day count (e.g. 31 in a
/// 30-day month), until it finds an occurrence on or after [today].
int daysUntilDebitOrder(int debitOrderDate, DateTime today) {
  final todayDate = DateTime(today.year, today.month, today.day);
  var year = today.year;
  var month = today.month;
  for (var i = 0; i < 3; i++) {
    if (debitOrderDate <= _daysInMonth(year, month)) {
      final due = DateTime(year, month, debitOrderDate);
      final diff = due.difference(todayDate).inDays;
      if (diff >= 0) return diff;
    }
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }
  return 999;
}

/// The soonest-due unpaid, active obligations, sorted ascending by days
/// until due, capped at [take].
List<UpcomingObligation> upcomingObligations(
  List<Obligation> obligations,
  DateTime today, {
  int take = 2,
}) {
  final result = obligations
      .where((o) => o.isActive && !o.isPaidThisMonth)
      .map((o) => UpcomingObligation(o, daysUntilDebitOrder(o.debitOrderDate, today)))
      .toList()
    ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
  return result.take(take).toList();
}

/// Computes the single most relevant "next action" message for the
/// dashboard, using only data the screen already loads. Precedence (first
/// match wins), per docs/superpowers/specs/2026-07-22-dashboard-hierarchy-
/// redesign.md:
/// 1. Negative free cash flow (overspent this month)
/// 2. An unpaid, active obligation due within 3 days
/// 3. Spend pace ahead of month-elapsed pace by more than 10 points
/// 4. Healthy savings rate (>= 20% of income left over)
/// 5. Neutral fallback prompt
NextAction computeNextAction({
  required double freeCashFlow,
  required double totalIncome,
  required double totalExpenses,
  required double totalObligations,
  required List<Obligation> obligations,
  required DateTime today,
  required String currencySymbol,
}) {
  if (freeCashFlow < 0) {
    return const NextAction(
      "You've spent more than you've earned this month",
      NextActionSeverity.error,
    );
  }

  final soonest = upcomingObligations(obligations, today, take: 1);
  if (soonest.isNotEmpty && soonest.first.daysUntilDue <= 3) {
    final upcoming = soonest.first;
    final days = upcoming.daysUntilDue;
    final dueLabel = days <= 0 ? 'today' : (days == 1 ? 'in 1 day' : 'in $days days');
    return NextAction(
      '${upcoming.obligation.name} — $currencySymbol'
      '${upcoming.obligation.amount.toStringAsFixed(2)} due $dueLabel',
      NextActionSeverity.warning,
    );
  }

  final discretionaryBudget = totalIncome - totalObligations;
  if (discretionaryBudget > 0) {
    final spendFraction = totalExpenses / discretionaryBudget;
    final elapsedFraction = today.day / _daysInMonth(today.year, today.month);
    if (spendFraction - elapsedFraction > 0.10) {
      return const NextAction(
        "You're spending faster than usual this month",
        NextActionSeverity.warning,
      );
    }
  }

  if (totalIncome > 0 && freeCashFlow / totalIncome >= 0.2) {
    final pct = (freeCashFlow / totalIncome * 100).round();
    return NextAction(
      "You're on track — saving $pct% this month",
      NextActionSeverity.success,
    );
  }

  return const NextAction(
    "Add today's expenses to keep your tracking up to date",
    NextActionSeverity.info,
  );
}
