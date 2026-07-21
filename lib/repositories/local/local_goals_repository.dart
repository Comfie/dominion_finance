import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/local/database.dart' as db;
import '../../models/goal.dart';
import '../goals_repository.dart';
import '../repository_exception.dart';

/// [GoalsRepository] implementation backed by the local Drift (SQLite)
/// database.
///
/// Mirrors the remote/server semantics observed in dominion-core:
/// - `addFundsToGoal` adds to `currentAmount` and flips `isCompleted` to
///   true once the target is reached (same rule as the server's
///   `PUT /api/goals/[id]` `addFunds` handling).
/// - `progressPercentage` isn't a stored column server-side either; it's
///   derived here as `currentAmount / targetAmount * 100`, clamped to
///   `[0, 100]`.
class LocalGoalsRepository implements GoalsRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  LocalGoalsRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<SavingsGoal>> getGoals({bool? completed}) async {
    try {
      final query = _database.select(_database.goals);
      if (completed != null) {
        query.where((tbl) => tbl.isCompleted.equals(completed));
      }
      query.orderBy([
        (tbl) => OrderingTerm.asc(tbl.isCompleted),
        (tbl) => OrderingTerm.asc(tbl.targetDate),
      ]);
      final rows = await query.get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw const RepositoryException('Failed to load goals');
    }
  }

  @override
  Future<void> createGoal(Map<String, dynamic> data) async {
    try {
      final now = DateTime.now();
      await _database
          .into(_database.goals)
          .insert(
            db.GoalsCompanion.insert(
              id: _uuid.v4(),
              name: data['name'] as String,
              targetAmount: (data['targetAmount'] as num).toDouble(),
              currentAmount: Value(((data['currentAmount'] as num?)?.toDouble()) ?? 0),
              targetDate: Value(
                data['targetDate'] != null ? DateTime.parse(data['targetDate'] as String) : null,
              ),
              category: (data['category'] as String?) ?? GoalCategory.OTHER.name,
              color: (data['color'] as String?) ?? '#8B5CF6',
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw const RepositoryException('Failed to create goal');
    }
  }

  @override
  Future<void> updateGoal(String id, Map<String, dynamic> data) async {
    try {
      final companion = db.GoalsCompanion(
        name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
        targetAmount: data.containsKey('targetAmount')
            ? Value((data['targetAmount'] as num).toDouble())
            : const Value.absent(),
        currentAmount: data.containsKey('currentAmount')
            ? Value((data['currentAmount'] as num).toDouble())
            : const Value.absent(),
        targetDate: data.containsKey('targetDate')
            ? Value(data['targetDate'] != null ? DateTime.parse(data['targetDate'] as String) : null)
            : const Value.absent(),
        category: data.containsKey('category') ? Value(data['category'] as String) : const Value.absent(),
        color: data.containsKey('color') ? Value(data['color'] as String) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );
      final count = await (_database.update(_database.goals)..where((tbl) => tbl.id.equals(id))).write(
        companion,
      );
      if (count == 0) {
        throw const RepositoryException('Failed to update goal');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update goal');
    }
  }

  @override
  Future<void> addFundsToGoal(String id, double amount) async {
    try {
      final goal = await (_database.select(
        _database.goals,
      )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (goal == null) {
        throw const RepositoryException('Failed to add funds to goal');
      }
      final newAmount = goal.currentAmount + amount;
      final count = await (_database.update(_database.goals)..where((tbl) => tbl.id.equals(id))).write(
        db.GoalsCompanion(
          currentAmount: Value(newAmount),
          isCompleted: Value(newAmount >= goal.targetAmount),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (count == 0) {
        throw const RepositoryException('Failed to add funds to goal');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to add funds to goal');
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    try {
      final count = await (_database.delete(_database.goals)..where((tbl) => tbl.id.equals(id))).go();
      if (count == 0) {
        throw const RepositoryException('Failed to delete goal');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete goal');
    }
  }

  SavingsGoal _toModel(db.Goal row) {
    final progress = row.targetAmount > 0 ? (row.currentAmount / row.targetAmount * 100) : 0.0;
    return SavingsGoal(
      id: row.id,
      name: row.name,
      targetAmount: row.targetAmount,
      currentAmount: row.currentAmount,
      targetDate: row.targetDate,
      category: GoalCategory.values.firstWhere(
        (e) => e.name == row.category,
        orElse: () => GoalCategory.OTHER,
      ),
      color: row.color,
      isCompleted: row.isCompleted,
      progressPercentage: progress.clamp(0, 100).toDouble(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
