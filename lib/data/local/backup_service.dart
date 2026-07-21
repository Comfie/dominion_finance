import 'dart:convert';

import 'package:drift/drift.dart';

import '../../repositories/local/local_settings_repository.dart';
import 'database.dart' as db;

/// The "app" field every backup envelope must carry, used to reject files
/// that aren't Dominion backups.
const _backupAppId = 'dominion';

/// Backup envelope versions this build of [BackupService] knows how to
/// import. Bump (and add a migration branch in [BackupService.importJson])
/// when the envelope shape changes.
const _supportedBackupVersions = {1};

/// Per-entity row counts written by [BackupService.importJson], keyed by
/// the same names used in the envelope's `data` object (plus `settings`,
/// which is 0 or 1 since there's only ever one settings row).
class BackupImportResult {
  final Map<String, int> imported;

  const BackupImportResult(this.imported);

  int get total => imported.values.fold(0, (sum, n) => sum + n);
}

/// Serializes the entire local (Drift/SQLite) database to/from a versioned
/// JSON envelope, so local-mode users have a backup/restore story.
///
/// The row->JSON direction mirrors the `_toModel` helpers in
/// lib/repositories/local/*: every column is included (ids, dates as
/// ISO8601, enum columns as their raw name strings) so the output matches
/// what lib/models/*.fromJson expects - unlike the models' own `toJson()`,
/// which only serializes the fields needed for create/update request
/// bodies and omits id/createdAt/updatedAt.
///
/// The JSON->row direction (import) mirrors the local repositories'
/// `createXxx(Map<String, dynamic> data)` methods, except the row id comes
/// from the backup (not a freshly generated uuid) and rows are upserted
/// with `insertOnConflictUpdate` so restoring is idempotent and
/// non-destructive: importing never wipes existing data, it only inserts
/// new rows and overwrites rows whose id matches.
class BackupService {
  final db.AppDatabase _database;

  BackupService(this._database);

  /// Serializes every table into a single JSON string.
  Future<String> exportJson() async {
    final settings = await _database.select(_database.settingsTable).getSingleOrNull();
    final persons = await _database.select(_database.persons).get();
    final expenses = await _database.select(_database.expenses).get();
    final incomes = await _database.select(_database.incomes).get();
    final obligations = await _database.select(_database.obligations).get();
    final payments = await _database.select(_database.payments).get();
    final goals = await _database.select(_database.goals).get();

    final personNames = {for (final p in persons) p.id: p.name};

    // Mirrors LocalObligationsRepository.getObligations: an obligation
    // counts as paid this month if a payment exists with paidAt in the
    // current calendar month/year.
    final now = DateTime.now();
    final paidObligationIds = payments
        .where((p) => p.paidAt.year == now.year && p.paidAt.month == now.month)
        .map((p) => p.obligationId)
        .toSet();

    final envelope = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'app': _backupAppId,
      'data': {
        'settings': settings != null ? _settingsToJson(settings) : null,
        'persons': persons.map(_personToJson).toList(),
        'expenses': expenses.map((e) => _expenseToJson(e, personNames)).toList(),
        'incomes': incomes.map(_incomeToJson).toList(),
        'obligations': obligations
            .map((o) => _obligationToJson(o, personNames, paidObligationIds))
            .toList(),
        'payments': payments.map(_paymentToJson).toList(),
        'goals': goals.map(_goalToJson).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Validates and imports a backup produced by [exportJson], upserting
  /// every row by id inside a single transaction. Throws an [Exception]
  /// with a user-readable message if the envelope isn't a well-formed
  /// Dominion backup of a supported version.
  Future<BackupImportResult> importJson(String jsonString) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw Exception('Invalid backup file: not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup file: unexpected format.');
    }
    final envelope = decoded;

    if (envelope['app'] != _backupAppId) {
      throw Exception('Invalid backup file: this file was not created by Dominion.');
    }

    final version = envelope['version'];
    if (version is! int || !_supportedBackupVersions.contains(version)) {
      throw Exception('Invalid backup file: unsupported backup version.');
    }

    final rawData = envelope['data'];
    if (rawData is! Map<String, dynamic>) {
      throw Exception('Invalid backup file: missing backup data.');
    }

    final counts = <String, int>{};
    await _database.transaction(() async {
      // Persons first (referenced by expenses/obligations), then
      // obligations before payments (referenced by obligationId).
      counts['persons'] = await _importPersons(_listOf(rawData, 'persons'));
      counts['expenses'] = await _importExpenses(_listOf(rawData, 'expenses'));
      counts['incomes'] = await _importIncomes(_listOf(rawData, 'incomes'));
      counts['obligations'] = await _importObligations(_listOf(rawData, 'obligations'));
      counts['payments'] = await _importPayments(_listOf(rawData, 'payments'));
      counts['goals'] = await _importGoals(_listOf(rawData, 'goals'));
      counts['settings'] = await _importSettings(rawData['settings']);
    });

    return BackupImportResult(counts);
  }

  // --- Envelope helpers -----------------------------------------------

  /// Reads `data[key]` as a list of JSON objects, treating an absent key as
  /// an empty (not present) collection. Throws if the key is present but
  /// isn't a list of objects.
  List<Map<String, dynamic>> _listOf(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return const [];
    if (value is! List) {
      throw Exception('Invalid backup file: "$key" must be a list.');
    }
    return value.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw Exception('Invalid backup file: malformed entry in "$key".');
      }
      return entry;
    }).toList();
  }

  // --- Row -> JSON (export) --------------------------------------------

  Map<String, dynamic> _settingsToJson(db.SettingsTableData row) {
    return {
      'id': row.id,
      'monthlyIncome': row.monthlyIncome,
      'payday': row.payday,
      'currency': row.currency,
      'monthlyBudget': row.monthlyBudget,
      'notifyBudgetAlerts': row.notifyBudgetAlerts,
      'notifyUpcomingBills': row.notifyUpcomingBills,
      'notifyPayday': row.notifyPayday,
      'notifyGoalProgress': row.notifyGoalProgress,
    };
  }

  Map<String, dynamic> _personToJson(db.Person row) {
    return {
      'id': row.id,
      'name': row.name,
      'budgetLimit': row.budgetLimit,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _expenseToJson(db.Expense row, Map<String, String> personNames) {
    return {
      'id': row.id,
      'name': row.name,
      'amount': row.amount,
      'category': row.category,
      'date': row.date.toIso8601String(),
      'personId': row.personId,
      'personName': personNames[row.personId],
      'notes': row.notes,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _incomeToJson(db.Income row) {
    return {
      'id': row.id,
      'name': row.name,
      'amount': row.amount,
      'source': row.source,
      'date': row.date.toIso8601String(),
      'isRecurring': row.isRecurring,
      'notes': row.notes,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _obligationToJson(
    db.Obligation row,
    Map<String, String> personNames,
    Set<String> paidObligationIds,
  ) {
    return {
      'id': row.id,
      'name': row.name,
      'provider': row.provider,
      'category': row.category,
      'amount': row.amount,
      'totalBalance': row.totalBalance,
      'interestRate': row.interestRate,
      'debitOrderDate': row.debitOrderDate,
      'isUncompromised': row.isUncompromised,
      'isActive': row.isActive,
      'personId': row.personId,
      'personName': personNames[row.personId],
      'notes': row.notes,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'isPaidThisMonth': paidObligationIds.contains(row.id),
    };
  }

  Map<String, dynamic> _paymentToJson(db.Payment row) {
    return {
      'id': row.id,
      'obligationId': row.obligationId,
      'amount': row.amount,
      'expectedAmount': row.expectedAmount,
      'adjustmentReason': row.adjustmentReason,
      'paidAt': row.paidAt.toIso8601String(),
      'month': row.month,
      'notes': row.notes,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _goalToJson(db.Goal row) {
    final progress = row.targetAmount > 0 ? (row.currentAmount / row.targetAmount * 100) : 0.0;
    return {
      'id': row.id,
      'name': row.name,
      'targetAmount': row.targetAmount,
      'currentAmount': row.currentAmount,
      'targetDate': row.targetDate?.toIso8601String(),
      'category': row.category,
      'color': row.color,
      'isCompleted': row.isCompleted,
      'progressPercentage': progress.clamp(0, 100).toDouble(),
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  // --- JSON -> row (import) --------------------------------------------

  Future<int> _importPersons(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.persons)
            .insertOnConflictUpdate(
              db.PersonsCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                budgetLimit: Value((item['budgetLimit'] as num?)?.toDouble()),
                createdAt: DateTime.parse(item['createdAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed person entry.');
      }
    }
    return count;
  }

  Future<int> _importExpenses(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.expenses)
            .insertOnConflictUpdate(
              db.ExpensesCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                amount: (item['amount'] as num).toDouble(),
                category: item['category'] as String,
                date: DateTime.parse(item['date'] as String),
                personId: Value(item['personId'] as String?),
                notes: Value(item['notes'] as String?),
                createdAt: DateTime.parse(item['createdAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed expense entry.');
      }
    }
    return count;
  }

  Future<int> _importIncomes(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.incomes)
            .insertOnConflictUpdate(
              db.IncomesCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                amount: (item['amount'] as num).toDouble(),
                source: item['source'] as String,
                date: DateTime.parse(item['date'] as String),
                isRecurring: Value((item['isRecurring'] as bool?) ?? false),
                notes: Value(item['notes'] as String?),
                createdAt: DateTime.parse(item['createdAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed income entry.');
      }
    }
    return count;
  }

  Future<int> _importObligations(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.obligations)
            .insertOnConflictUpdate(
              db.ObligationsCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                provider: item['provider'] as String,
                category: item['category'] as String,
                amount: (item['amount'] as num).toDouble(),
                totalBalance: Value((item['totalBalance'] as num?)?.toDouble()),
                interestRate: Value((item['interestRate'] as num?)?.toDouble()),
                debitOrderDate: item['debitOrderDate'] as int,
                isUncompromised: Value((item['isUncompromised'] as bool?) ?? true),
                isActive: Value((item['isActive'] as bool?) ?? true),
                personId: Value(item['personId'] as String?),
                notes: Value(item['notes'] as String?),
                createdAt: DateTime.parse(item['createdAt'] as String),
                updatedAt: DateTime.parse(item['updatedAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed obligation entry.');
      }
    }
    return count;
  }

  Future<int> _importPayments(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.payments)
            .insertOnConflictUpdate(
              db.PaymentsCompanion.insert(
                id: item['id'] as String,
                obligationId: item['obligationId'] as String,
                amount: (item['amount'] as num).toDouble(),
                expectedAmount: Value((item['expectedAmount'] as num?)?.toDouble()),
                adjustmentReason: Value(item['adjustmentReason'] as String?),
                paidAt: DateTime.parse(item['paidAt'] as String),
                month: item['month'] as String,
                notes: Value(item['notes'] as String?),
                createdAt: DateTime.parse(item['createdAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed payment entry.');
      }
    }
    return count;
  }

  Future<int> _importGoals(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      try {
        await _database
            .into(_database.goals)
            .insertOnConflictUpdate(
              db.GoalsCompanion.insert(
                id: item['id'] as String,
                name: item['name'] as String,
                targetAmount: (item['targetAmount'] as num).toDouble(),
                currentAmount: Value((item['currentAmount'] as num?)?.toDouble() ?? 0),
                targetDate: Value(
                  item['targetDate'] != null ? DateTime.parse(item['targetDate'] as String) : null,
                ),
                category: item['category'] as String,
                color: item['color'] as String,
                isCompleted: Value((item['isCompleted'] as bool?) ?? false),
                createdAt: DateTime.parse(item['createdAt'] as String),
                updatedAt: DateTime.parse(item['updatedAt'] as String),
              ),
            );
        count++;
      } catch (_) {
        throw Exception('Invalid backup file: malformed goal entry.');
      }
    }
    return count;
  }

  /// Applies the imported settings onto the existing single settings row
  /// (see [LocalSettingsRepository]'s single-row invariant) instead of
  /// inserting a second row. Returns 1 if settings were imported, 0 if the
  /// backup didn't include a settings object.
  Future<int> _importSettings(dynamic settingsJson) async {
    if (settingsJson == null) return 0;
    if (settingsJson is! Map<String, dynamic>) {
      throw Exception('Invalid backup file: malformed settings entry.');
    }
    try {
      final rows = await _database.select(_database.settingsTable).get();
      final rowId = rows.isNotEmpty ? rows.first.id : LocalSettingsRepository.settingsRowId;
      if (rows.isEmpty) {
        await _database
            .into(_database.settingsTable)
            .insert(db.SettingsTableCompanion.insert(id: rowId), mode: InsertMode.insertOrIgnore);
      }

      final companion = db.SettingsTableCompanion(
        monthlyIncome: Value((settingsJson['monthlyIncome'] as num).toDouble()),
        payday: Value(settingsJson['payday'] as int),
        currency: Value(settingsJson['currency'] as String),
        monthlyBudget: Value((settingsJson['monthlyBudget'] as num?)?.toDouble()),
        notifyBudgetAlerts: Value(settingsJson['notifyBudgetAlerts'] as bool),
        notifyUpcomingBills: Value(settingsJson['notifyUpcomingBills'] as bool),
        notifyPayday: Value(settingsJson['notifyPayday'] as bool),
        notifyGoalProgress: Value(settingsJson['notifyGoalProgress'] as bool),
      );
      await (_database.update(
        _database.settingsTable,
      )..where((tbl) => tbl.id.equals(rowId))).write(companion);
      return 1;
    } catch (_) {
      throw Exception('Invalid backup file: malformed settings entry.');
    }
  }
}
