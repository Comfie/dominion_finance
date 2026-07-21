import '../../core/api_client.dart';
import '../../models/expense.dart';
import '../expenses_repository.dart';
import '../repository_exception.dart';

/// [ExpensesRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteExpensesRepository implements ExpensesRepository {
  final ApiClient _apiClient;

  RemoteExpensesRepository(this._apiClient);

  @override
  Future<List<Expense>> getExpenses({String? month}) async {
    try {
      final response = await _apiClient.getExpenses(month: month);
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const RepositoryException('Failed to load expenses');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load expenses');
    }
  }

  @override
  Future<void> createExpense(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createExpense(data);
      if (response.statusCode != 201) {
        throw const RepositoryException('Failed to create expense');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to create expense');
    }
  }

  @override
  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateExpense(id, data);
      if (response.statusCode != 200) {
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
      final response = await _apiClient.deleteExpense(id);
      if (response.statusCode != 204) {
        throw const RepositoryException('Failed to delete expense');
      }
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to delete expense');
    }
  }
}
