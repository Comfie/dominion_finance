import 'package:drift/drift.dart';

import '../../data/local/database.dart' as db;
import '../../models/settings.dart';
import '../repository_exception.dart';
import '../settings_repository.dart';

/// [SettingsRepository] implementation backed by the local Drift (SQLite)
/// database.
///
/// Mirrors the remote/server's single-row-per-user semantics (see
/// `GET /api/settings` in dominion-core): `getSettings` returns the single
/// local row if present, otherwise creates and returns one with the same
/// defaults the server uses (monthlyIncome 0, payday 25, currency 'ZAR',
/// all notification toggles on). `updateSettings` upserts the row.
class LocalSettingsRepository implements SettingsRepository {
  /// Fixed primary key for the single settings row. Combined with an
  /// insert-or-ignore, this makes concurrent first-reads race-safe: two
  /// callers both inserting defaults collide on the key instead of creating
  /// duplicate rows (which would make getSingleOrNull throw forever after).
  static const String settingsRowId = 'local-settings';

  final db.AppDatabase _database;

  LocalSettingsRepository(this._database);

  /// Returns the single settings row, creating it with defaults if missing
  /// and collapsing duplicates left behind by the historical check-then-insert
  /// race (keeps the oldest row so any user-edited values survive).
  Future<db.SettingsTableData> _ensureSingleRow() async {
    return _database.transaction(() async {
      final rows = await _database.select(_database.settingsTable).get();
      if (rows.length == 1) return rows.single;

      if (rows.isEmpty) {
        await _database
            .into(_database.settingsTable)
            .insert(db.SettingsTableCompanion.insert(id: settingsRowId), mode: InsertMode.insertOrIgnore);
        return (_database.select(_database.settingsTable)..where((tbl) => tbl.id.equals(settingsRowId))).getSingle();
      }

      final keep = rows.first;
      await (_database.delete(_database.settingsTable)..where((tbl) => tbl.id.isNotValue(keep.id))).go();
      return keep;
    });
  }

  @override
  Future<Settings> getSettings() async {
    try {
      return _toModel(await _ensureSingleRow());
    } catch (e) {
      throw const RepositoryException('Failed to load settings');
    }
  }

  @override
  Future<Settings> updateSettings(Map<String, dynamic> data) async {
    try {
      final existing = await _ensureSingleRow();

      final companion = db.SettingsTableCompanion(
        monthlyIncome: data.containsKey('monthlyIncome')
            ? Value((data['monthlyIncome'] as num).toDouble())
            : const Value.absent(),
        payday: data.containsKey('payday') ? Value(data['payday'] as int) : const Value.absent(),
        currency: data.containsKey('currency') ? Value(data['currency'] as String) : const Value.absent(),
        monthlyBudget: data.containsKey('monthlyBudget')
            ? Value((data['monthlyBudget'] as num?)?.toDouble())
            : const Value.absent(),
        notifyBudgetAlerts: data.containsKey('notifyBudgetAlerts')
            ? Value(data['notifyBudgetAlerts'] as bool)
            : const Value.absent(),
        notifyUpcomingBills: data.containsKey('notifyUpcomingBills')
            ? Value(data['notifyUpcomingBills'] as bool)
            : const Value.absent(),
        notifyPayday: data.containsKey('notifyPayday')
            ? Value(data['notifyPayday'] as bool)
            : const Value.absent(),
        notifyGoalProgress: data.containsKey('notifyGoalProgress')
            ? Value(data['notifyGoalProgress'] as bool)
            : const Value.absent(),
      );

      final count = await (_database.update(
        _database.settingsTable,
      )..where((tbl) => tbl.id.equals(existing.id))).write(companion);
      if (count == 0) {
        throw const RepositoryException('Failed to update settings');
      }

      final updated = await (_database.select(
        _database.settingsTable,
      )..where((tbl) => tbl.id.equals(existing.id))).getSingle();
      return _toModel(updated);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update settings');
    }
  }

  Settings _toModel(db.SettingsTableData row) {
    return Settings(
      id: row.id,
      monthlyIncome: row.monthlyIncome,
      payday: row.payday,
      currency: row.currency,
      monthlyBudget: row.monthlyBudget,
      notifyBudgetAlerts: row.notifyBudgetAlerts,
      notifyUpcomingBills: row.notifyUpcomingBills,
      notifyPayday: row.notifyPayday,
      notifyGoalProgress: row.notifyGoalProgress,
    );
  }
}
