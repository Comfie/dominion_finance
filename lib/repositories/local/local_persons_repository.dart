import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart' as db;
import '../../models/person.dart';
import '../persons_repository.dart';
import '../repository_exception.dart';

/// [PersonsRepository] implementation backed by the local Drift (SQLite)
/// database. Mirrors [RemotePersonsRepository]'s semantics: `createPerson`
/// generates a local id, and mutations throw [RepositoryException] with
/// messages consistent with the remote implementation on failure.
class LocalPersonsRepository implements PersonsRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  LocalPersonsRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Person>> getPersons() async {
    try {
      final rows = await _database.select(_database.persons).get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw const RepositoryException('Failed to load persons');
    }
  }

  @override
  Future<void> createPerson(Map<String, dynamic> data) async {
    try {
      await _database
          .into(_database.persons)
          .insert(
            db.PersonsCompanion.insert(
              id: _uuid.v4(),
              name: data['name'] as String,
              budgetLimit: Value((data['budgetLimit'] as num?)?.toDouble()),
              createdAt: DateTime.now(),
            ),
          );
    } catch (e) {
      throw const RepositoryException('Failed to create person');
    }
  }

  @override
  Future<void> updatePerson(String id, Map<String, dynamic> data) async {
    try {
      final companion = db.PersonsCompanion(
        name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
        budgetLimit: data.containsKey('budgetLimit')
            ? Value((data['budgetLimit'] as num?)?.toDouble())
            : const Value.absent(),
      );
      final count = await (_database.update(
        _database.persons,
      )..where((tbl) => tbl.id.equals(id))).write(companion);
      if (count == 0) {
        throw const RepositoryException('Failed to update person');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update person');
    }
  }

  @override
  Future<void> deletePerson(String id) async {
    try {
      final count = await (_database.delete(_database.persons)..where((tbl) => tbl.id.equals(id))).go();
      if (count == 0) {
        throw const RepositoryException('Failed to delete person');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete person');
    }
  }

  Person _toModel(db.Person row) {
    return Person(id: row.id, name: row.name, budgetLimit: row.budgetLimit, createdAt: row.createdAt);
  }
}
