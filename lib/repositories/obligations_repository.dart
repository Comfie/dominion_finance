import '../models/obligation.dart';

/// Abstract data access for obligations, including payment recording.
/// Implementations are responsible for fetching/persisting obligations and
/// translating failures into [RepositoryException]s.
abstract class ObligationsRepository {
  Future<List<Obligation>> getObligations({bool? isActive});

  Future<void> createObligation(Map<String, dynamic> data);

  Future<void> updateObligation(String id, Map<String, dynamic> data);

  Future<void> deleteObligation(String id);

  Future<void> createPayment(Map<String, dynamic> data);
}
