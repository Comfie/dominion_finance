import '../../core/api_client.dart';
import '../../models/obligation.dart';
import '../obligations_repository.dart';
import '../repository_exception.dart';

/// [ObligationsRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteObligationsRepository implements ObligationsRepository {
  final ApiClient _apiClient;

  RemoteObligationsRepository(this._apiClient);

  @override
  Future<List<Obligation>> getObligations({bool? isActive}) async {
    try {
      final response = await _apiClient.getObligations(isActive: isActive);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => Obligation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const RepositoryException('Failed to load obligations');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load obligations');
    }
  }

  @override
  Future<void> createObligation(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createObligation(data);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to create obligation');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to create obligation');
    }
  }

  @override
  Future<void> updateObligation(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateObligation(id, data);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.deleteObligation(id);
      if (response.statusCode != 204) {
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
      // The .NET API defaults a missing paidAt to UtcNow, but the Next.js API
      // requires it; send it explicitly so the payload works against both.
      final payload = {
        'paidAt': DateTime.now().toUtc().toIso8601String(),
        ...data,
      };
      final response = await _apiClient.createPayment(payload);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to record payment');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to record payment');
    }
  }
}
