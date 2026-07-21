import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/local/database.dart' as db;
import '../../models/income.dart';
import '../incomes_repository.dart';
import '../repository_exception.dart';

/// [IncomesRepository] implementation backed by the local Drift (SQLite)
/// database. Mirrors [RemoteIncomesRepository]'s semantics: `getIncomes`
/// filters by calendar month, `createIncome` generates a local id, and
/// mutations throw [RepositoryException] with messages consistent with the
/// remote implementation on failure.
class LocalIncomesRepository implements IncomesRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  LocalIncomesRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Income>> getIncomes({String? month}) async {
    try {
      final query = _database.select(_database.incomes);
      if (month != null) {
        final parts = month.split('-');
        final year = int.parse(parts[0]);
        final monthNum = int.parse(parts[1]);
        final start = DateTime(year, monthNum, 1);
        final end = DateTime(year, monthNum + 1, 1);
        query.where((tbl) => tbl.date.isBiggerOrEqualValue(start) & tbl.date.isSmallerThanValue(end));
      }
      query.orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
      final rows = await query.get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw const RepositoryException('Failed to load incomes');
    }
  }

  @override
  Future<void> createIncome(Map<String, dynamic> data) async {
    try {
      await _database
          .into(_database.incomes)
          .insert(
            db.IncomesCompanion.insert(
              id: _uuid.v4(),
              name: data['name'] as String,
              amount: (data['amount'] as num).toDouble(),
              source: data['source'] as String,
              date: DateTime.parse(data['date'] as String),
              isRecurring: Value((data['isRecurring'] as bool?) ?? false),
              notes: Value(data['notes'] as String?),
              createdAt: DateTime.now(),
            ),
          );
    } catch (e) {
      throw const RepositoryException('Failed to create income');
    }
  }

  @override
  Future<void> updateIncome(String id, Map<String, dynamic> data) async {
    try {
      final companion = db.IncomesCompanion(
        name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
        amount: data.containsKey('amount')
            ? Value((data['amount'] as num).toDouble())
            : const Value.absent(),
        source: data.containsKey('source') ? Value(data['source'] as String) : const Value.absent(),
        date: data.containsKey('date')
            ? Value(DateTime.parse(data['date'] as String))
            : const Value.absent(),
        isRecurring: data.containsKey('isRecurring')
            ? Value(data['isRecurring'] as bool)
            : const Value.absent(),
        notes: data.containsKey('notes') ? Value(data['notes'] as String?) : const Value.absent(),
      );
      final count = await (_database.update(
        _database.incomes,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
      if (count == 0) {
        throw const RepositoryException('Failed to update income');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update income');
    }
  }

  @override
  Future<void> deleteIncome(String id) async {
    try {
      final count = await (_database.delete(_database.incomes)..where((tbl) => tbl.id.equals(id))).go();
      if (count == 0) {
        throw const RepositoryException('Failed to delete income');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete income');
    }
  }

  Income _toModel(db.Income row) {
    return Income(
      id: row.id,
      name: row.name,
      amount: row.amount,
      source: IncomeSource.values.firstWhere(
        (e) => e.name == row.source,
        orElse: () => IncomeSource.OTHER,
      ),
      date: row.date,
      isRecurring: row.isRecurring,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
