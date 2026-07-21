import '../../core/api_client.dart';
import '../../models/goal.dart';
import '../goals_repository.dart';
import '../repository_exception.dart';

/// [GoalsRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteGoalsRepository implements GoalsRepository {
  final ApiClient _apiClient;

  RemoteGoalsRepository(this._apiClient);

  @override
  Future<List<SavingsGoal>> getGoals({bool? completed}) async {
    try {
      final response = await _apiClient.getGoals(completed: completed);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const RepositoryException('Failed to load goals');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load goals');
    }
  }

  @override
  Future<void> createGoal(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createGoal(data);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to create goal');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to create goal');
    }
  }

  @override
  Future<void> updateGoal(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateGoal(id, data);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.addFundsToGoal(id, amount);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.deleteGoal(id);
      if (response.statusCode != 204) {
        throw const RepositoryException('Failed to delete goal');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete goal');
    }
  }
}
