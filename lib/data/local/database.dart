import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Expenses table, mirroring [Expense] (lib/models/expense.dart).
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get personId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Incomes table, mirroring [Income] (lib/models/income.dart).
class Incomes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get source => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Obligations table, mirroring [Obligation] (lib/models/obligation.dart).
/// `isPaidThisMonth` is not stored - it's derived from the Payments table.
class Obligations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get provider => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  RealColumn get totalBalance => real().nullable()();
  RealColumn get interestRate => real().nullable()();
  IntColumn get debitOrderDate => integer()();
  BoolColumn get isUncompromised => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get personId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Payments table, recording amounts paid against an [Obligation].
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get obligationId => text()();
  RealColumn get amount => real()();
  RealColumn get expectedAmount => real().nullable()();
  TextColumn get adjustmentReason => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get month => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Savings goals table, mirroring [SavingsGoal] (lib/models/goal.dart).
/// `progressPercentage` is not stored - it's derived from current/target amount.
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get category => text()();
  TextColumn get color => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Persons table, mirroring [Person] (lib/models/person.dart).
class Persons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get budgetLimit => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Settings table, mirroring [Settings] (lib/models/settings.dart). Expected
/// to hold a single row per local database, analogous to the one row per
/// user on the server.
class SettingsTable extends Table {
  TextColumn get id => text()();
  RealColumn get monthlyIncome => real().withDefault(const Constant(0))();
  IntColumn get payday => integer().withDefault(const Constant(25))();
  TextColumn get currency => text().withDefault(const Constant('ZAR'))();
  RealColumn get monthlyBudget => real().nullable()();
  BoolColumn get notifyBudgetAlerts => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyUpcomingBills => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyPayday => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyGoalProgress => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local (SQLite, via Drift) persistence for the app. A future local-first
/// migration can back the repository interfaces in lib/repositories/ with
/// this database instead of the remote HTTP API.
@DriftDatabase(
  tables: [Expenses, Incomes, Obligations, Payments, Goals, Persons, SettingsTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _defaultExecutor());

  static QueryExecutor _defaultExecutor() {
    return driftDatabase(name: 'dominion_app');
  }

  @override
  int get schemaVersion => 1;
}
