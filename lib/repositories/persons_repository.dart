import '../models/person.dart';

/// Abstract data access for persons. Implementations are responsible for
/// fetching/persisting persons and translating failures into
/// [RepositoryException]s.
abstract class PersonsRepository {
  Future<List<Person>> getPersons();

  Future<void> createPerson(Map<String, dynamic> data);

  Future<void> updatePerson(String id, Map<String, dynamic> data);

  Future<void> deletePerson(String id);
}
