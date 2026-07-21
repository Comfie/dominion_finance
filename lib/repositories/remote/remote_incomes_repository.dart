import '../../core/api_client.dart';
import '../../models/income.dart';
import '../incomes_repository.dart';
import '../repository_exception.dart';

/// [IncomesRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteIncomesRepository implements IncomesRepository {
  final ApiClient _apiClient;

  RemoteIncomesRepository(this._apiClient);

  @override
  Future<List<Income>> getIncomes({String? month}) async {
    try {
      final response = await _apiClient.getIncomes(month: month);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => Income.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const RepositoryException('Failed to load incomes');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load incomes');
    }
  }

  @override
  Future<void> createIncome(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createIncome(data);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to create income');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to create income');
    }
  }

  @override
  Future<void> updateIncome(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateIncome(id, data);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.deleteIncome(id);
      if (response.statusCode != 204) {
        throw const RepositoryException('Failed to delete income');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete income');
    }
  }
}
