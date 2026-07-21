import '../models/settings.dart';

/// Abstract data access for the user's settings. Implementations are
/// responsible for fetching/persisting settings and translating failures
/// into [RepositoryException]s.
abstract class SettingsRepository {
  Future<Settings> getSettings();

  Future<Settings> updateSettings(Map<String, dynamic> data);
}
