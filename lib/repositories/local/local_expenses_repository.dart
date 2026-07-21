import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/local/database.dart' as db;
import '../../models/expense.dart';
import '../expenses_repository.dart';
import '../repository_exception.dart';

/// [ExpensesRepository] implementation backed by the local Drift (SQLite)
/// database. Mirrors [RemoteExpensesRepository]'s semantics: `getExpenses`
/// resolves `personName` from the linked person and filters by calendar
/// month, `createExpense` generates a local id, and mutations throw
/// [RepositoryException] with messages consistent with the remote
/// implementation on failure.
class LocalExpensesRepository implements ExpensesRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  LocalExpensesRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Expense>> getExpenses({String? month}) async {
    try {
      final query = _database.select(_database.expenses);
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

      final persons = await _database.select(_database.persons).get();
      final personNames = {for (final p in persons) p.id: p.name};

      return rows.map((row) => _toModel(row, personNames[row.personId])).toList();
    } catch (e) {
      throw const RepositoryException('Failed to load expenses');
    }
  }

  @override
  Future<void> createExpense(Map<String, dynamic> data) async {
    try {
      await _database
          .into(_database.expenses)
          .insert(
            db.ExpensesCompanion.insert(
              id: _uuid.v4(),
              name: data['name'] as String,
              amount: (data['amount'] as num).toDouble(),
              category: data['category'] as String,
              date: DateTime.parse(data['date'] as String),
              personId: Value(data['personId'] as String?),
              notes: Value(data['notes'] as String?),
              createdAt: DateTime.now(),
            ),
          );
    } catch (e) {
      throw const RepositoryException('Failed to create expense');
    }
  }

  @override
  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    try {
      final companion = db.ExpensesCompanion(
        name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
        amount: data.containsKey('amount')
            ? Value((data['amount'] as num).toDouble())
            : const Value.absent(),
        category: data.containsKey('category') ? Value(data['category'] as String) : const Value.absent(),
        date: data.containsKey('date')
            ? Value(DateTime.parse(data['date'] as String))
            : const Value.absent(),
        personId: data.containsKey('personId') ? Value(data['personId'] as String?) : const Value.absent(),
        notes: data.containsKey('notes') ? Value(data['notes'] as String?) : const Value.absent(),
      );
      final count = await (_database.update(
        _database.expenses,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
      if (count == 0) {
        throw const RepositoryException('Failed to update expense');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update expense');
    }
  }

  @override
  Future<void> deleteExpense(String id) async {
    try {
      final count = await (_database.delete(_database.expenses)..where((tbl) => tbl.id.equals(id))).go();
      if (count == 0) {
        throw const RepositoryException('Failed to delete expense');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete expense');
    }
  }

  Expense _toModel(db.Expense row, String? personName) {
    return Expense(
      id: row.id,
      name: row.name,
      amount: row.amount,
      category: Category.values.firstWhere((e) => e.name == row.category, orElse: () => Category.OTHER),
      date: row.date,
      personId: row.personId,
      personName: personName,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
