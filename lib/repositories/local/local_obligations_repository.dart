import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/local/database.dart' as db;
import '../../models/obligation.dart';
import '../obligations_repository.dart';
import '../repository_exception.dart';

/// [ObligationsRepository] implementation backed by the local Drift
/// (SQLite) database.
///
/// Mirrors the remote/server semantics observed in dominion-core:
/// - `getObligations` orders by `debitOrderDate` ascending and resolves
///   `personName` from the linked person.
/// - `isPaidThisMonth` is not a stored column (the server doesn't persist
///   it either); it's derived the same way the web app derives it
///   client-side - true if a payment exists for the obligation with
///   `paidAt` in the current calendar month/year.
/// - `createPayment` verifies the obligation exists (mirroring the
///   server's 404 "Obligation not found" check) before inserting the
///   payment. If the caller doesn't supply `paidAt` (the app's
///   `recordPayment` helper currently doesn't), it defaults to now.
class LocalObligationsRepository implements ObligationsRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  LocalObligationsRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Obligation>> getObligations({bool? isActive}) async {
    try {
      final query = _database.select(_database.obligations);
      if (isActive != null) {
        query.where((tbl) => tbl.isActive.equals(isActive));
      }
      query.orderBy([(tbl) => OrderingTerm.asc(tbl.debitOrderDate)]);
      final rows = await query.get();

      final persons = await _database.select(_database.persons).get();
      final personNames = {for (final p in persons) p.id: p.name};

      final payments = await _database.select(_database.payments).get();
      final now = DateTime.now();
      final paidObligationIds = payments
          .where((p) => p.paidAt.year == now.year && p.paidAt.month == now.month)
          .map((p) => p.obligationId)
          .toSet();

      return rows
          .map((row) => _toModel(row, personNames[row.personId], paidObligationIds.contains(row.id)))
          .toList();
    } catch (e) {
      throw const RepositoryException('Failed to load obligations');
    }
  }

  @override
  Future<void> createObligation(Map<String, dynamic> data) async {
    try {
      final now = DateTime.now();
      await _database
          .into(_database.obligations)
          .insert(
            db.ObligationsCompanion.insert(
              id: _uuid.v4(),
              name: data['name'] as String,
              provider: data['provider'] as String,
              category: data['category'] as String,
              amount: (data['amount'] as num).toDouble(),
              totalBalance: Value((data['totalBalance'] as num?)?.toDouble()),
              interestRate: Value((data['interestRate'] as num?)?.toDouble()),
              debitOrderDate: data['debitOrderDate'] as int,
              isUncompromised: Value((data['isUncompromised'] as bool?) ?? true),
              isActive: Value((data['isActive'] as bool?) ?? true),
              personId: Value(data['personId'] as String?),
              notes: Value(data['notes'] as String?),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw const RepositoryException('Failed to create obligation');
    }
  }

  @override
  Future<void> updateObligation(String id, Map<String, dynamic> data) async {
    try {
      final companion = db.ObligationsCompanion(
        name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
        provider: data.containsKey('provider') ? Value(data['provider'] as String) : const Value.absent(),
        category: data.containsKey('category') ? Value(data['category'] as String) : const Value.absent(),
        amount: data.containsKey('amount')
            ? Value((data['amount'] as num).toDouble())
            : const Value.absent(),
        totalBalance: data.containsKey('totalBalance')
            ? Value((data['totalBalance'] as num?)?.toDouble())
            : const Value.absent(),
        interestRate: data.containsKey('interestRate')
            ? Value((data['interestRate'] as num?)?.toDouble())
            : const Value.absent(),
        debitOrderDate: data.containsKey('debitOrderDate')
            ? Value(data['debitOrderDate'] as int)
            : const Value.absent(),
        isUncompromised: data.containsKey('isUncompromised')
            ? Value(data['isUncompromised'] as bool)
            : const Value.absent(),
        isActive: data.containsKey('isActive')
            ? Value(data['isActive'] as bool)
            : const Value.absent(),
        personId: data.containsKey('personId') ? Value(data['personId'] as String?) : const Value.absent(),
        notes: data.containsKey('notes') ? Value(data['notes'] as String?) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );
      final count = await (_database.update(
        _database.obligations,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
      if (count == 0) {
        throw const RepositoryException('Failed to update obligation');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update obligation');
    }
  }

  @override
  Future<void> deleteObligation(String id) async {
    try {
      final count = await (_database.delete(
        _database.obligations,
      )..where((tbl) => tbl.id.equals(id))).go();
      if (count == 0) {
        throw const RepositoryException('Failed to delete obligation');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete obligation');
    }
  }

  @override
  Future<void> createPayment(Map<String, dynamic> data) async {
    try {
      final obligationId = data['obligationId'] as String;
      final obligation = await (_database.select(
        _database.obligations,
      )..where((tbl) => tbl.id.equals(obligationId))).getSingleOrNull();
      if (obligation == null) {
        throw const RepositoryException('Failed to record payment');
      }

      await _database
          .into(_database.payments)
          .insert(
            db.PaymentsCompanion.insert(
              id: _uuid.v4(),
              obligationId: obligationId,
              amount: (data['amount'] as num).toDouble(),
              expectedAmount: Value((data['expectedAmount'] as num?)?.toDouble()),
              adjustmentReason: Value(data['adjustmentReason'] as String?),
              paidAt: data['paidAt'] != null ? DateTime.parse(data['paidAt'] as String) : DateTime.now(),
              month: data['month'] as String,
              notes: Value(data['notes'] as String?),
              createdAt: DateTime.now(),
            ),
          );
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to record payment');
    }
  }

  Obligation _toModel(db.Obligation row, String? personName, bool isPaidThisMonth) {
    return Obligation(
      id: row.id,
      name: row.name,
      provider: row.provider,
      category: Category.values.firstWhere((e) => e.name == row.category, orElse: () => Category.OTHER),
      amount: row.amount,
      totalBalance: row.totalBalance,
      interestRate: row.interestRate,
      debitOrderDate: row.debitOrderDate,
      isUncompromised: row.isUncompromised,
      isActive: row.isActive,
      personId: row.personId,
      personName: personName,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isPaidThisMonth: isPaidThisMonth,
    );
  }
}
