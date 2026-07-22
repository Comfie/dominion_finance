# Dashboard Hierarchy Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Dashboard screen and nav bar so visual weight matches information importance — bigger/richer hero, a computed "what should I do next" callout, distinct container treatment per content tier, and a labeled active nav pill — per `docs/superpowers/specs/2026-07-22-dashboard-hierarchy-redesign.md`.

**Architecture:** New pure-logic file (`lib/core/dashboard_insights.dart`) holds date math and the Next Action / Upcoming Bills derivation, unit-tested in isolation. `dashboard_screen.dart` is rewritten to consume it and restructure its widget tree into six visual tiers. `main_scaffold.dart`'s `_NavItem` gets a small, self-contained restyle. No new providers, models, or routes.

**Tech Stack:** Flutter 3 / Dart 3.9, `flutter_riverpod`, `go_router`, `flutter_test`.

## Global Constraints

- No new data models, providers, or settings fields — overspend/savings signals are derived in `dashboard_insights.dart` from data the screen already loads (income, expenses, obligations, goals).
- No changes to any screen other than Dashboard, and no changes to `main_scaffold.dart` beyond the nav item restyle described here.
- No changes to `SpendingByCategoryChart` / `GoalsProgressChart` internals (colors/logic) — **implementation note:** the original spec called for an outer "Spending" section header above the chart, but the chart widget already renders its own "Spending by Category" header inside its own card (confirmed by reading `lib/widgets/charts/spending_by_category_chart.dart`) — adding a second "Spending" header directly above it would be a redundant, duplicate title. Task 3 therefore does **not** add an outer "Spending" header; instead the chart card and the new Upcoming Bills card are placed with a tight 12px gap (vs. the ~28px gap used between other sections) so they read as one grouped section without a duplicate title. This preserves the spec's intent ("chart shouldn't feel disconnected") without touching chart internals or duplicating headers.
- No theme-mode/light-dark switcher work (still deferred per the Phase 1 spec).
- `flutter analyze` must stay clean on every touched file; `flutter test` must continue to pass.
- Do not commit unless explicitly instructed — stage the changes but leave the commit step for the user to trigger, per this repo's global instructions.
- After implementation, static analysis/tests are necessary but not sufficient for visual work — hand off to the user for an on-device/emulator screenshot check before calling this visually complete (per prior redesign-verification feedback).

---

### Task 1: Dashboard insights (pure logic + unit tests)

**Files:**
- Create: `lib/core/dashboard_insights.dart`
- Create: `test/core/dashboard_insights_test.dart`

**Interfaces:**
- Produces:
  - `enum NextActionSeverity { error, warning, success, info }`
  - `class NextAction { final String message; final NextActionSeverity severity; const NextAction(this.message, this.severity); }` (with `==`/`hashCode` for test assertions)
  - `class UpcomingObligation { final Obligation obligation; final int daysUntilDue; const UpcomingObligation(this.obligation, this.daysUntilDue); }`
  - `int daysUntilDebitOrder(int debitOrderDate, DateTime today)`
  - `List<UpcomingObligation> upcomingObligations(List<Obligation> obligations, DateTime today, {int take = 2})`
  - `NextAction computeNextAction({required double freeCashFlow, required double totalIncome, required double totalExpenses, required double totalObligations, required List<Obligation> obligations, required DateTime today, required String currencySymbol})`
- Consumes: `Obligation` from `lib/models/obligation.dart` (fields used: `name`, `amount`, `debitOrderDate`, `isActive`, `isPaidThisMonth`).

- [ ] **Step 1: Write the failing test file**

Create `test/core/dashboard_insights_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/dashboard_insights_test.dart`
Expected: FAIL — `lib/core/dashboard_insights.dart` doesn't exist yet (import error).

- [ ] **Step 3: Write the implementation**

Create `lib/core/dashboard_insights.dart`:

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/dashboard_insights_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS (existing suite + 11 new tests)

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze lib/core/dashboard_insights.dart test/core/dashboard_insights_test.dart`
Expected: No issues found.

- [ ] **Step 7: Stage the changes (do not commit)**

```bash
git add lib/core/dashboard_insights.dart test/core/dashboard_insights_test.dart
git status
```

---

### Task 2: Nav bar — labeled active pill

**Files:**
- Modify: `lib/widgets/main_scaffold.dart`

**Interfaces:**
- Consumes: nothing new (existing `GoRouter`/`context.go` calls unchanged).
- Produces: `_NavItem` gains a required `label` parameter; no public API changes (private widget).

- [ ] **Step 1: Add labels to each `_NavItem` call site**

In `lib/widgets/main_scaffold.dart`, replace the `Row` of `_NavItem`s:

```dart
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  isSelected: _getCurrentIndex(context) == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  isSelected: _getCurrentIndex(context) == 1,
                  onTap: () => _onTap(context, 1),
                ),
                _NavItem(
                  icon: Icons.payments_rounded,
                  isSelected: _getCurrentIndex(context) == 2,
                  onTap: () => _onTap(context, 2),
                ),
                _NavItem(
                  icon: Icons.savings_rounded,
                  isSelected: _getCurrentIndex(context) == 3,
                  onTap: () => _onTap(context, 3),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  isSelected: _getCurrentIndex(context) == 4,
                  onTap: () => _onTap(context, 4),
                ),
              ],
            ),
```

with:

```dart
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                  isSelected: _getCurrentIndex(context) == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Expenses',
                  isSelected: _getCurrentIndex(context) == 1,
                  onTap: () => _onTap(context, 1),
                ),
                _NavItem(
                  icon: Icons.payments_rounded,
                  label: 'Bills',
                  isSelected: _getCurrentIndex(context) == 2,
                  onTap: () => _onTap(context, 2),
                ),
                _NavItem(
                  icon: Icons.savings_rounded,
                  label: 'Goals',
                  isSelected: _getCurrentIndex(context) == 3,
                  onTap: () => _onTap(context, 3),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _getCurrentIndex(context) == 4,
                  onTap: () => _onTap(context, 4),
                ),
              ],
            ),
```

- [ ] **Step 2: Rewrite `_NavItem` to render a labeled pill when selected**

Replace the existing `_NavItem` class:

```dart
class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedColor = Theme.of(context).textTheme.bodySmall?.color ?? colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? colorScheme.onPrimary : unselectedColor,
          size: 24,
        ),
      ),
    );
  }
}
```

with:

```dart
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedColor = Theme.of(context).textTheme.bodySmall?.color ?? colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: isSelected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colorScheme.onPrimary, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              )
            : Icon(icon, color: unselectedColor, size: 24),
      ),
    );
  }
}
```

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze lib/widgets/main_scaffold.dart`
Expected: No issues found.

- [ ] **Step 4: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS (no existing test covers `main_scaffold.dart` — this step confirms nothing else broke)

- [ ] **Step 5: Stage the changes (do not commit)**

```bash
git add lib/widgets/main_scaffold.dart
git status
```

---

### Task 3: Dashboard screen restructure

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (full-file rewrite — the six tiers are interdependent parts of one `build()` method sharing local variables, so this is one deliverable rather than split into per-tier tasks)

**Interfaces:**
- Consumes: `computeNextAction`, `upcomingObligations`, `NextAction`, `NextActionSeverity`, `UpcomingObligation` from Task 1's `lib/core/dashboard_insights.dart`.
- Produces: no new public API — same screen, same route, same provider reads.

- [ ] **Step 1: Replace the full file content**

Replace all of `lib/screens/dashboard/dashboard_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/dashboard_insights.dart';
import '../../core/storage_mode.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/incomes_provider.dart';
import '../../providers/obligations_provider.dart';
import '../../providers/goals_provider.dart';
import '../../widgets/ai_gate_dialog.dart';
import '../../widgets/charts/spending_by_category_chart.dart';
import '../../widgets/charts/goals_progress_chart.dart';
import '../../widgets/forms/scan_receipt_modal.dart';
import '../../widgets/scooped_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
      ref.read(expensesProvider.notifier).loadExpenses();
      ref.read(incomesProvider.notifier).loadIncomes();
      ref.read(obligationsProvider.notifier).loadObligations();
      ref.read(goalsProvider.notifier).loadGoals();
    });
  }

  /// Calculate total spending by category
  Map<String, double> _calculateCategoryTotals(List<Expense> expenses) {
    final Map<String, double> totals = {};
    for (final expense in expenses) {
      final category = expense.category.name;
      totals[category] = (totals[category] ?? 0) + expense.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settingsState = ref.watch(settingsProvider);
    final expensesState = ref.watch(expensesProvider);
    final incomesState = ref.watch(incomesProvider);
    final obligationsState = ref.watch(obligationsProvider);
    final goalsState = ref.watch(goalsProvider);
    final isLocalMode = ref.watch(storageModeProvider) == StorageMode.local;

    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final currencySymbol = settingsState.settings?.currencySymbol ?? 'R';

    // Calculate financial metrics
    final monthlyIncome = settingsState.settings?.monthlyIncome ?? 0;
    final additionalIncome = incomesState.incomes.fold<double>(0, (sum, income) => sum + income.amount);
    final totalIncome = monthlyIncome + additionalIncome;

    final totalExpenses = expensesState.totalExpenses;
    final totalObligations = obligationsState.obligations
        .where((o) => o.isActive)
        .fold<double>(0, (sum, o) => sum + o.amount);

    final freeCashFlow = totalIncome - totalExpenses - totalObligations;
    final totalGoalsSaved = goalsState.goals.fold<double>(0, (sum, g) => sum + g.currentAmount);

    final isLoading = expensesState.isLoading ||
                      incomesState.isLoading ||
                      obligationsState.isLoading ||
                      goalsState.isLoading;

    final now = DateTime.now();
    final nextAction = computeNextAction(
      freeCashFlow: freeCashFlow,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalObligations: totalObligations,
      obligations: obligationsState.obligations,
      today: now,
      currencySymbol: currencySymbol,
    );
    final upcomingBills = upcomingObligations(obligationsState.obligations, now);
    final recentExpenses = expensesState.expenses.take(5).toList();

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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScoopedHeader(
                background: colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                            ),
                            Text(
                              authState.user?.name ?? 'there',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: colorScheme.surface,
                          child: Text(
                            (authState.user?.name ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _HeroFigure(
                      amount: freeCashFlow,
                      totalIncome: totalIncome,
                      totalExpenses: totalExpenses,
                      currencySymbol: currencySymbol,
                      textColor: colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _NextActionCallout(action: nextAction),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add_rounded,
                          label: 'Add Expense',
                          onTap: () => context.go('/expenses'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Scan Receipt',
                          onTap: () {
                            if (isLocalMode) {
                              showAiGateDialog(
                                context,
                                ref,
                                message: 'Requires an account — receipt '
                                    'data is processed via our servers '
                                    'and never stored.',
                              );
                              return;
                            }
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const ScanReceiptModal(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.insights_rounded,
                          label: 'Insights',
                          onTap: () {
                            if (isLocalMode) {
                              showAiGateDialog(
                                context,
                                ref,
                                message: 'Requires an account — spending '
                                    'insights are generated via our '
                                    'servers and never stored.',
                              );
                              return;
                            }
                            context.go('/insights');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _AtAGlanceStrip(
                    currencySymbol: currencySymbol,
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    totalObligations: totalObligations,
                    totalGoals: totalGoalsSaved,
                  ),
                  const SizedBox(height: 28),
                  // Spending section: chart + upcoming bills grouped with a
                  // tight gap (no outer header — the chart already renders
                  // its own "Spending by Category" title; see this plan's
                  // Global Constraints note).
                  if (!isLoading && expensesState.expenses.isNotEmpty) ...[
                    SpendingByCategoryChart(
                      categoryTotals: _calculateCategoryTotals(expensesState.expenses),
                      currencySymbol: currencySymbol,
                    ),
                    if (upcomingBills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _UpcomingBillsCard(upcoming: upcomingBills, currencySymbol: currencySymbol),
                    ],
                    const SizedBox(height: 16),
                  ] else if (!isLoading && upcomingBills.isNotEmpty) ...[
                    _UpcomingBillsCard(upcoming: upcomingBills, currencySymbol: currencySymbol),
                    const SizedBox(height: 16),
                  ],
                  if (!isLoading && goalsState.goals.isNotEmpty) ...[
                    GoalsProgressChart(
                      goals: goalsState.goals,
                      currencySymbol: currencySymbol,
                    ),
                    const SizedBox(height: 28),
                  ],
                  _SectionHeader(
                    title: 'Recent Expenses',
                    onViewAll: expensesState.expenses.isNotEmpty
                        ? () => context.go('/expenses')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (expensesState.expenses.isEmpty)
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
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No expenses yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your first expense to get started',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < recentExpenses.length; i++) ...[
                          _ExpenseItem(
                            expense: recentExpenses[i],
                            currencySymbol: currencySymbol,
                          ),
                          if (i != recentExpenses.length - 1)
                            Divider(
                              height: 1,
                              color: Theme.of(context).dividerTheme.color,
                            ),
                        ],
                      ],
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final double amount;
  final double totalIncome;
  final double totalExpenses;
  final String currencySymbol;
  final Color textColor;

  const _HeroFigure({
    required this.amount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.currencySymbol,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Left to spend this month',
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$currencySymbol ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: textColor,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.arrow_upward_rounded, color: textColor.withOpacity(0.7), size: 14),
            const SizedBox(width: 4),
            Text(
              'Income $currencySymbol ${totalIncome.toStringAsFixed(2)}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(width: 16),
            Icon(Icons.arrow_downward_rounded, color: textColor.withOpacity(0.7), size: 14),
            const SizedBox(width: 4),
            Text(
              'Expenses $currencySymbol ${totalExpenses.toStringAsFixed(2)}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _NextActionCallout extends StatelessWidget {
  final NextAction action;

  const _NextActionCallout({required this.action});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final Color tint;
    final IconData icon;
    switch (action.severity) {
      case NextActionSeverity.error:
        tint = colorScheme.error;
        icon = Icons.error_outline_rounded;
        break;
      case NextActionSeverity.warning:
        tint = appColors.warning;
        icon = Icons.event_rounded;
        break;
      case NextActionSeverity.success:
        tint = appColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case NextActionSeverity.info:
        tint = appColors.info;
        icon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.onPrimary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AtAGlanceStrip extends StatelessWidget {
  final String currencySymbol;
  final double totalIncome;
  final double totalExpenses;
  final double totalObligations;
  final double totalGoals;

  const _AtAGlanceStrip({
    required this.currencySymbol,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalObligations,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final items = [
      (label: 'Income', amount: totalIncome, icon: Icons.arrow_upward_rounded, color: appColors.success),
      (label: 'Expenses', amount: totalExpenses, icon: Icons.arrow_downward_rounded, color: appColors.info),
      (label: 'Obligations', amount: totalObligations, icon: Icons.account_balance_wallet_rounded, color: appColors.warning),
      (label: 'Goals', amount: totalGoals, icon: Icons.savings_rounded, color: appColors.info),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                color: Theme.of(context).dividerTheme.color,
                thickness: 1,
                width: 1,
                indent: 8,
                endIndent: 8,
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].icon, color: items[i].color, size: 16),
                  const SizedBox(height: 6),
                  Text(
                    items[i].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currencySymbol ${items[i].amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingBillsCard extends StatelessWidget {
  final List<UpcomingObligation> upcoming;
  final String currencySymbol;

  const _UpcomingBillsCard({required this.upcoming, required this.currencySymbol});

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
          Text(
            'Upcoming Bills',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          for (var i = 0; i < upcoming.length; i++) ...[
            _UpcomingBillRow(upcoming: upcoming[i], currencySymbol: currencySymbol),
            if (i != upcoming.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerTheme.color),
          ],
        ],
      ),
    );
  }
}

class _UpcomingBillRow extends StatelessWidget {
  final UpcomingObligation upcoming;
  final String currencySymbol;

  const _UpcomingBillRow({required this.upcoming, required this.currencySymbol});

  String _dueLabel(int days) {
    if (days <= 0) return 'due today';
    if (days == 1) return 'due in 1 day';
    return 'due in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final obligation = upcoming.obligation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obligation.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _dueLabel(upcoming.daysUntilDue),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$currencySymbol ${obligation.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  final Expense expense;
  final String currencySymbol;

  const _ExpenseItem({
    required this.expense,
    required this.currencySymbol,
  });

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.GROCERIES:
        return Icons.shopping_cart_rounded;
      case Category.TRANSPORT:
        return Icons.directions_car_rounded;
      case Category.DINING:
        return Icons.restaurant_rounded;
      case Category.ENTERTAINMENT:
        return Icons.movie_rounded;
      case Category.UTILITIES:
        return Icons.bolt_rounded;
      case Category.SHOPPING:
        return Icons.shopping_bag_rounded;
      case Category.HOUSING:
        return Icons.home_rounded;
      case Category.INSURANCE:
        return Icons.security_rounded;
      case Category.LIVING:
        return Icons.favorite_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  /// Category chip tint, cycled from the theme's token palette rather than
  /// ad hoc Material colors.
  Color _getCategoryColor(BuildContext context, Category category) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      appColors.warning,
      appColors.success,
    ];
    return palette[category.index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(context, expense.category).withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getCategoryIcon(expense.category),
              color: _getCategoryColor(context, expense.category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  expense.category.displayName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '-$currencySymbol ${expense.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).extension<AppColors>()!.infoText,
                ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/screens/dashboard/dashboard_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS (no existing test targets `dashboard_screen.dart` directly, so this step confirms no regression elsewhere — e.g. provider contracts used by the screen are unchanged)

- [ ] **Step 4: Stage the changes (do not commit)**

```bash
git add lib/screens/dashboard/dashboard_screen.dart
git status
```

- [ ] **Step 5: Hand off for visual verification**

Static analysis and unit tests don't catch layout/contrast problems (this bit the Phase 1 pass — see its spec's "Lesson from the first review pass"). Tell the user the dashboard is ready and ask them to run it on their emulator/device and share a screenshot before this is considered visually complete. Do not launch the emulator yourself.

---

## Self-review notes

- **Spec coverage:** hero (44px + breakdown) → Task 3 `_HeroFigure`; Next Action callout + precedence → Task 1 `computeNextAction` + Task 3 `_NextActionCallout`; Upcoming Bills → Task 1 `upcomingObligations` + Task 3 `_UpcomingBillsCard`; Quick Actions circular restyle → Task 3 `_ActionButton`; unified at-a-glance card → Task 3 `_AtAGlanceStrip`; Spending section grouping → Task 3 (with the documented header-duplication deviation); Recent Expenses demotion → Task 3 `_ExpenseItem`/divider list; typography scale → Task 3 `_SectionHeader` + hero sizes; nav bar labeled pill → Task 2. No spec section is uncovered.
- **Type consistency:** `NextAction`, `NextActionSeverity`, `UpcomingObligation` are defined once in Task 1 and referenced with the same names/shapes in Task 3 — no renames across tasks.
- **Placeholder scan:** none — every step has complete, runnable code.
