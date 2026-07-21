import 'package:drift/native.dart';
import 'package:dominion_app/data/local/database.dart';
import 'package:dominion_app/repositories/local/local_expenses_repository.dart';
import 'package:dominion_app/repositories/local/local_goals_repository.dart';
import 'package:dominion_app/repositories/local/local_obligations_repository.dart';
import 'package:dominion_app/repositories/local/local_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('LocalExpensesRepository', () {
    test('create/list(month filter)/update/delete round-trip', () async {
      final repository = LocalExpensesRepository(database);

      await repository.createExpense({
        'name': 'Groceries',
        'amount': 250.5,
        'category': 'GROCERIES',
        'date': DateTime(2026, 7, 15).toIso8601String(),
        'notes': 'Weekly shop',
      });
      await repository.createExpense({
        'name': 'Rent',
        'amount': 8000,
        'category': 'HOUSING',
        'date': DateTime(2026, 6, 1).toIso8601String(),
      });

      final all = await repository.getExpenses();
      expect(all, hasLength(2));

      final julyOnly = await repository.getExpenses(month: '2026-07');
      expect(julyOnly, hasLength(1));
      expect(julyOnly.single.name, 'Groceries');
      expect(julyOnly.single.amount, 250.5);
      expect(julyOnly.single.notes, 'Weekly shop');

      final id = julyOnly.single.id;
      await repository.updateExpense(id, {'amount': 300.0, 'name': 'Groceries (updated)'});
      final afterUpdate = await repository.getExpenses(month: '2026-07');
      expect(afterUpdate.single.amount, 300.0);
      expect(afterUpdate.single.name, 'Groceries (updated)');

      await repository.deleteExpense(id);
      final afterDelete = await repository.getExpenses();
      expect(afterDelete, hasLength(1));
      expect(afterDelete.single.name, 'Rent');
    });
  });

  group('LocalObligationsRepository', () {
    test('create + createPayment reflects isPaidThisMonth', () async {
      final repository = LocalObligationsRepository(database);

      await repository.createObligation({
        'name': 'Car Loan',
        'provider': 'Bank',
        'category': 'DEBT',
        'amount': 3500.0,
        'debitOrderDate': 25,
      });

      final beforePayment = await repository.getObligations();
      expect(beforePayment, hasLength(1));
      expect(beforePayment.single.isPaidThisMonth, isFalse);

      final obligationId = beforePayment.single.id;
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await repository.createPayment({'obligationId': obligationId, 'amount': 3500.0, 'month': month});

      final afterPayment = await repository.getObligations();
      expect(afterPayment.single.isPaidThisMonth, isTrue);
    });

    test('createPayment throws for an unknown obligation', () async {
      final repository = LocalObligationsRepository(database);

      expect(
        () => repository.createPayment({'obligationId': 'missing', 'amount': 100.0, 'month': '2026-07'}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LocalGoalsRepository', () {
    test('create + addFundsToGoal round-trip', () async {
      final repository = LocalGoalsRepository(database);

      await repository.createGoal({
        'name': 'Emergency Fund',
        'targetAmount': 1000.0,
        'category': 'EMERGENCY_FUND',
      });

      final goals = await repository.getGoals();
      expect(goals, hasLength(1));
      expect(goals.single.currentAmount, 0);
      expect(goals.single.isCompleted, isFalse);
      expect(goals.single.progressPercentage, 0);

      final id = goals.single.id;
      await repository.addFundsToGoal(id, 400.0);
      var updated = (await repository.getGoals()).single;
      expect(updated.currentAmount, 400.0);
      expect(updated.isCompleted, isFalse);
      expect(updated.progressPercentage, 40.0);

      await repository.addFundsToGoal(id, 600.0);
      updated = (await repository.getGoals()).single;
      expect(updated.currentAmount, 1000.0);
      expect(updated.isCompleted, isTrue);
      expect(updated.progressPercentage, 100.0);
    });
  });

  group('LocalSettingsRepository', () {
    test('default-creation then update round-trip', () async {
      final repository = LocalSettingsRepository(database);

      final defaults = await repository.getSettings();
      expect(defaults.monthlyIncome, 0);
      expect(defaults.payday, 25);
      expect(defaults.currency, 'ZAR');
      expect(defaults.notifyBudgetAlerts, isTrue);
      expect(defaults.notifyUpcomingBills, isTrue);
      expect(defaults.notifyPayday, isTrue);
      expect(defaults.notifyGoalProgress, isTrue);

      // Calling getSettings again must return the same row, not create a
      // second one.
      final again = await repository.getSettings();
      expect(again.id, defaults.id);

      final updated = await repository.updateSettings({
        'monthlyIncome': 25000.0,
        'currency': 'USD',
        'notifyPayday': false,
      });
      expect(updated.id, defaults.id);
      expect(updated.monthlyIncome, 25000.0);
      expect(updated.currency, 'USD');
      expect(updated.notifyPayday, isFalse);
      // Untouched fields are preserved.
      expect(updated.payday, 25);
      expect(updated.notifyBudgetAlerts, isTrue);

      final reloaded = await repository.getSettings();
      expect(reloaded.monthlyIncome, 25000.0);
      expect(reloaded.currency, 'USD');
    });

    test('heals duplicate rows left by concurrent first reads', () async {
      final repository = LocalSettingsRepository(database);

      // Reproduce the historical check-then-insert race: multiple "single"
      // rows in the table, which used to make every read/write throw
      // (getSingleOrNull -> StateError) and the settings screen go static.
      await database.into(database.settingsTable).insert(SettingsTableCompanion.insert(id: 'row-1'));
      await database.into(database.settingsTable).insert(SettingsTableCompanion.insert(id: 'row-2'));
      await database.into(database.settingsTable).insert(SettingsTableCompanion.insert(id: 'row-3'));

      final settings = await repository.getSettings();
      expect(settings.id, 'row-1', reason: 'keeps the oldest row');

      final remaining = await database.select(database.settingsTable).get();
      expect(remaining, hasLength(1));

      final updated = await repository.updateSettings({'monthlyIncome': 12345.0});
      expect(updated.monthlyIncome, 12345.0);
      expect(updated.id, 'row-1');
    });

    test('concurrent first reads create exactly one row', () async {
      final repository = LocalSettingsRepository(database);

      final results = await Future.wait([
        repository.getSettings(),
        repository.getSettings(),
        repository.getSettings(),
      ]);

      expect(results.map((s) => s.id).toSet(), hasLength(1));
      final rows = await database.select(database.settingsTable).get();
      expect(rows, hasLength(1));
    });
  });
}
