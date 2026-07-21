import '../models/income.dart';

/// Abstract data access for incomes. Implementations are responsible for
/// fetching/persisting incomes and translating failures into
/// [RepositoryException]s.
abstract class IncomesRepository {
  Future<List<Income>> getIncomes({String? month});

  Future<void> createIncome(Map<String, dynamic> data);

  Future<void> updateIncome(String id, Map<String, dynamic> data);

  Future<void> deleteIncome(String id);
}
