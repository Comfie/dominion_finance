import '../models/goal.dart';

/// Abstract data access for savings goals. Implementations are responsible
/// for fetching/persisting goals and translating failures into
/// [RepositoryException]s.
abstract class GoalsRepository {
  Future<List<SavingsGoal>> getGoals({bool? completed});

  Future<void> createGoal(Map<String, dynamic> data);

  Future<void> updateGoal(String id, Map<String, dynamic> data);

  Future<void> addFundsToGoal(String id, double amount);

  Future<void> deleteGoal(String id);
}
