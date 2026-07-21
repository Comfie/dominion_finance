import 'dart:convert';

import 'package:drift/native.dart';
import 'package:dominion_app/data/local/backup_service.dart';
import 'package:dominion_app/data/local/database.dart';
import 'package:dominion_app/repositories/local/local_expenses_repository.dart';
import 'package:dominion_app/repositories/local/local_goals_repository.dart';
import 'package:dominion_app/repositories/local/local_incomes_repository.dart';
import 'package:dominion_app/repositories/local/local_obligations_repository.dart';
import 'package:dominion_app/repositories/local/local_persons_repository.dart';
import 'package:dominion_app/repositories/local/local_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seeds one row per entity into [db], including a payment that references
/// an obligation and an expense that references a person, so export/import
/// round-trip coverage exercises every table and the id relationships
/// between them.
Future<void> _seedData(AppDatabase db) async {
  final persons = LocalPersonsRepository(db);
  final expenses = LocalExpensesRepository(db);
  final incomes = LocalIncomesRepository(db);
  final obligations = LocalObligationsRepository(db);
  final goals = LocalGoalsRepository(db);
  final settings = LocalSettingsRepository(db);

  await persons.createPerson({'name': 'Alice', 'budgetLimit': 5000.0});
  final personId = (await persons.getPersons()).single.id;

  await expenses.createExpense({
    'name': 'Groceries',
    'amount': 250.5,
    'category': 'GROCERIES',
    'date': DateTime(2026, 7, 15).toIso8601String(),
    'personId': personId,
    'notes': 'Weekly shop',
  });

  await incomes.createIncome({
    'name': 'Salary',
    'amount': 20000.0,
    'source': 'SALARY',
    'date': DateTime(2026, 7, 1).toIso8601String(),
    'isRecurring': true,
  });

  await obligations.createObligation({
    'name': 'Car Loan',
    'provider': 'Bank',
    'category': 'DEBT',
    'amount': 3500.0,
    'totalBalance': 45000.0,
    'interestRate': 11.5,
    'debitOrderDate': 25,
    'personId': personId,
  });
  final obligationId = (await obligations.getObligations()).single.id;

  await obligations.createPayment({
    'obligationId': obligationId,
    'amount': 3500.0,
    'month': '2026-07',
  });

  await goals.createGoal({
    'name': 'Emergency Fund',
    'targetAmount': 10000.0,
    'currentAmount': 2500.0,
    'category': 'EMERGENCY_FUND',
    'color': '#8B5CF6',
  });

  await settings.updateSettings({
    'monthlyIncome': 25000.0,
    'currency': 'USD',
    'payday': 1,
    'monthlyBudget': 18000.0,
    'notifyPayday': false,
  });
}

void main() {
  late AppDatabase database;
  late BackupService backupService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('BackupService round-trip', () {
    test('export then import into a fresh database restores every entity', () async {
      await _seedData(database);
      final json = await backupService.exportJson();

      final freshDatabase = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDatabase.close);
      final freshBackupService = BackupService(freshDatabase);

      final result = await freshBackupService.importJson(json);

      expect(result.imported['persons'], 1);
      expect(result.imported['expenses'], 1);
      expect(result.imported['incomes'], 1);
      expect(result.imported['obligations'], 1);
      expect(result.imported['payments'], 1);
      expect(result.imported['goals'], 1);
      expect(result.imported['settings'], 1);
      expect(result.total, 7);

      // Spot-check field fidelity: names, amounts, dates, enum names, and
      // the person<->expense/obligation and obligation<->payment
      // relationships all survive the round-trip.
      final persons = await LocalPersonsRepository(freshDatabase).getPersons();
      expect(persons.single.name, 'Alice');
      expect(persons.single.budgetLimit, 5000.0);

      final expenses = await LocalExpensesRepository(freshDatabase).getExpenses();
      expect(expenses.single.name, 'Groceries');
      expect(expenses.single.amount, 250.5);
      expect(expenses.single.category.name, 'GROCERIES');
      expect(expenses.single.date, DateTime(2026, 7, 15));
      expect(expenses.single.notes, 'Weekly shop');
      expect(expenses.single.personName, 'Alice', reason: 'personId link to Alice survives import');

      final incomes = await LocalIncomesRepository(freshDatabase).getIncomes();
      expect(incomes.single.name, 'Salary');
      expect(incomes.single.source.name, 'SALARY');
      expect(incomes.single.isRecurring, isTrue);
      expect(incomes.single.date, DateTime(2026, 7, 1));

      final obligations = await LocalObligationsRepository(freshDatabase).getObligations();
      expect(obligations.single.name, 'Car Loan');
      expect(obligations.single.category.name, 'DEBT');
      expect(obligations.single.totalBalance, 45000.0);
      expect(obligations.single.interestRate, 11.5);
      expect(obligations.single.personName, 'Alice');
      expect(
        obligations.single.isPaidThisMonth,
        isTrue,
        reason: 'the seeded payment defaults to paidAt = now, which survives the round-trip',
      );

      final freshGoals = await LocalGoalsRepository(freshDatabase).getGoals();
      expect(freshGoals.single.name, 'Emergency Fund');
      expect(freshGoals.single.currentAmount, 2500.0);
      expect(freshGoals.single.targetAmount, 10000.0);
      expect(freshGoals.single.progressPercentage, 25.0);
      expect(freshGoals.single.category.name, 'EMERGENCY_FUND');

      final restoredSettings = await LocalSettingsRepository(freshDatabase).getSettings();
      expect(restoredSettings.monthlyIncome, 25000.0);
      expect(restoredSettings.currency, 'USD');
      expect(restoredSettings.payday, 1);
      expect(restoredSettings.monthlyBudget, 18000.0);
      expect(restoredSettings.notifyPayday, isFalse);
      // Untouched notification toggles keep their defaults.
      expect(restoredSettings.notifyBudgetAlerts, isTrue);

      // The single-settings-row invariant must not be broken by import.
      final settingsRows = await freshDatabase.select(freshDatabase.settingsTable).get();
      expect(settingsRows, hasLength(1));

      final paymentRows = await freshDatabase.select(freshDatabase.payments).get();
      expect(paymentRows, hasLength(1));
      expect(paymentRows.single.obligationId, obligations.single.id);
      expect(paymentRows.single.amount, 3500.0);
      expect(paymentRows.single.month, '2026-07');
    });
  });

  group('BackupService idempotence', () {
    test('importing the same backup twice does not duplicate rows', () async {
      await _seedData(database);
      final json = await backupService.exportJson();

      final freshDatabase = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDatabase.close);
      final freshBackupService = BackupService(freshDatabase);

      final first = await freshBackupService.importJson(json);
      final second = await freshBackupService.importJson(json);

      expect(first.imported, second.imported);

      expect(await freshDatabase.select(freshDatabase.persons).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.expenses).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.incomes).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.obligations).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.payments).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.goals).get(), hasLength(1));
      expect(await freshDatabase.select(freshDatabase.settingsTable).get(), hasLength(1));
    });
  });

  group('BackupService invalid input', () {
    test('malformed JSON throws a user-readable error', () async {
      await expectLater(
        backupService.importJson('this is not json'),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('not valid JSON')),
        ),
      );
    });

    test('wrong "app" id throws a user-readable error', () async {
      final json = jsonEncode({'version': 1, 'app': 'some-other-app', 'data': <String, dynamic>{}});
      await expectLater(
        backupService.importJson(json),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not created by Dominion'),
          ),
        ),
      );
    });

    test('unsupported "version" throws a user-readable error', () async {
      final json = jsonEncode({'version': 999, 'app': 'dominion', 'data': <String, dynamic>{}});
      await expectLater(
        backupService.importJson(json),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('unsupported backup version'),
          ),
        ),
      );
    });

    test('missing "data" throws a user-readable error', () async {
      final json = jsonEncode({'version': 1, 'app': 'dominion'});
      await expectLater(
        backupService.importJson(json),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('missing backup data')),
        ),
      );
    });
  });
}
