import '../../core/api_client.dart';
import '../../models/person.dart';
import '../persons_repository.dart';
import '../repository_exception.dart';

/// [PersonsRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemotePersonsRepository implements PersonsRepository {
  final ApiClient _apiClient;

  RemotePersonsRepository(this._apiClient);

  @override
  Future<List<Person>> getPersons() async {
    try {
      final response = await _apiClient.getPersons();
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => Person.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const RepositoryException('Failed to load persons');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load persons');
    }
  }

  @override
  Future<void> createPerson(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createPerson(data);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to create person');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to create person');
    }
  }

  @override
  Future<void> updatePerson(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updatePerson(id, data);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.deletePerson(id);
      if (response.statusCode != 204) {
        throw const RepositoryException('Failed to delete person');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete person');
    }
  }
}
