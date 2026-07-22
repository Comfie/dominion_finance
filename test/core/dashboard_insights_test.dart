import 'package:flutter_test/flutter_test.dart';
import 'package:dominion_app/core/constants.dart';
import 'package:dominion_app/core/dashboard_insights.dart';
import 'package:dominion_app/models/obligation.dart';

Obligation _obligation({
  required int debitOrderDate,
  bool isActive = true,
  bool isPaidThisMonth = false,
  double amount = 500,
  String name = 'Rent',
}) {
  final now = DateTime(2026, 1, 1);
  return Obligation(
    id: 'o1',
    name: name,
    provider: 'Test Bank',
    category: Category.HOUSING,
    amount: amount,
    debitOrderDate: debitOrderDate,
    isUncompromised: false,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    isPaidThisMonth: isPaidThisMonth,
  );
}

void main() {
  group('daysUntilDebitOrder', () {
    test('returns days remaining later this month', () {
      final today = DateTime(2026, 3, 15);
      expect(daysUntilDebitOrder(20, today), 5);
    });

    test('rolls over to next month when the day has already passed', () {
      final today = DateTime(2026, 3, 15);
      expect(daysUntilDebitOrder(10, today), 26);
    });

    test('returns 0 for today', () {
      final today = DateTime(2026, 3, 15);
      expect(daysUntilDebitOrder(15, today), 0);
    });

    test('skips a month where the day-of-month does not exist', () {
      // April has 30 days, so the 31st rolls to May 31.
      final today = DateTime(2026, 4, 29);
      final expected = DateTime(2026, 5, 31).difference(DateTime(2026, 4, 29)).inDays;
      expect(daysUntilDebitOrder(31, today), expected);
    });
  });

  group('upcomingObligations', () {
    test('filters out inactive and already-paid obligations', () {
      final today = DateTime(2026, 3, 1);
      final obligations = [
        _obligation(debitOrderDate: 5, isActive: false),
        _obligation(debitOrderDate: 6, isPaidThisMonth: true),
        _obligation(debitOrderDate: 10, name: 'Insurance'),
      ];
      final result = upcomingObligations(obligations, today);
      expect(result.length, 1);
      expect(result.first.obligation.name, 'Insurance');
    });

    test('sorts ascending by days until due and caps at take', () {
      final today = DateTime(2026, 3, 1);
      final obligations = [
        _obligation(debitOrderDate: 20, name: 'Later'),
        _obligation(debitOrderDate: 3, name: 'Soonest'),
        _obligation(debitOrderDate: 10, name: 'Middle'),
      ];
      final result = upcomingObligations(obligations, today, take: 2);
      expect(result.length, 2);
      expect(result[0].obligation.name, 'Soonest');
      expect(result[1].obligation.name, 'Middle');
    });
  });

  group('computeNextAction', () {
    test('flags overspending when free cash flow is negative', () {
      final action = computeNextAction(
        freeCashFlow: -100,
        totalIncome: 1000,
        totalExpenses: 1100,
        totalObligations: 0,
        obligations: const [],
        today: DateTime(2026, 3, 10),
        currencySymbol: 'R',
      );
      expect(action.severity, NextActionSeverity.error);
    });

    test('flags a bill due within 3 days ahead of the spend-pace check', () {
      final obligations = [_obligation(debitOrderDate: 12, name: 'Rent', amount: 500)];
      final action = computeNextAction(
        freeCashFlow: 200,
        totalIncome: 1000,
        totalExpenses: 800,
        totalObligations: 300,
        obligations: obligations,
        today: DateTime(2026, 3, 10),
        currencySymbol: 'R',
      );
      expect(action.severity, NextActionSeverity.warning);
      expect(action.message, contains('Rent'));
    });

    test('flags spending pace ahead of the month when no bill is imminent', () {
      final action = computeNextAction(
        freeCashFlow: 100,
        totalIncome: 1000,
        totalExpenses: 700,
        totalObligations: 200,
        obligations: const [],
        today: DateTime(2026, 4, 5), // day 5 of 30 -> ~17% elapsed
        currencySymbol: 'R',
      );
      // spend fraction = 700/(1000-200) = 0.875; elapsed = 5/30 = 0.167 -> diff 0.71
      expect(action.severity, NextActionSeverity.warning);
    });

    test('reports healthy savings when nothing else is urgent', () {
      final action = computeNextAction(
        freeCashFlow: 500,
        totalIncome: 1000,
        totalExpenses: 300,
        totalObligations: 200,
        obligations: const [],
        today: DateTime(2026, 4, 20), // day 20 of 30 -> ~67% elapsed
        currencySymbol: 'R',
      );
      // spend fraction = 300/(1000-200) = 0.375; elapsed = 20/30 = 0.667 -> no pace flag
      // freeCashFlow/totalIncome = 0.5 >= 0.2 -> success
      expect(action.severity, NextActionSeverity.success);
    });

    test('does not divide by zero when obligations consume the entire income', () {
      final action = computeNextAction(
        freeCashFlow: 0,
        totalIncome: 500,
        totalExpenses: 0,
        totalObligations: 500,
        obligations: const [],
        today: DateTime(2026, 4, 15),
        currencySymbol: 'R',
      );
      // discretionary budget <= 0 -> spend-pace check skipped; savings ratio 0/500 < 0.2 -> fallback
      expect(action.severity, NextActionSeverity.info);
    });

    test('falls back to a neutral prompt when nothing else applies', () {
      final action = computeNextAction(
        freeCashFlow: 50,
        totalIncome: 1000,
        totalExpenses: 450,
        totalObligations: 500,
        obligations: const [],
        today: DateTime(2026, 4, 25), // day 25 of 30 -> ~83% elapsed
        currencySymbol: 'R',
      );
      // spend fraction = 450/(1000-500) = 0.9; elapsed = 25/30 = 0.833 -> diff 0.067, no flag
      // freeCashFlow/totalIncome = 0.05 < 0.2 -> fallback
      expect(action.severity, NextActionSeverity.info);
    });
  });
}
