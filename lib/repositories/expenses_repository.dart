import '../models/expense.dart';

/// Abstract data access for expenses. Implementations are responsible for
/// fetching/persisting expenses and translating failures into
/// [RepositoryException]s.
abstract class ExpensesRepository {
  Future<List<Expense>> getExpenses({String? month});

  Future<void> createExpense(Map<String, dynamic> data);

  Future<void> updateExpense(String id, Map<String, dynamic> data);

  Future<void> deleteExpense(String id);
}
