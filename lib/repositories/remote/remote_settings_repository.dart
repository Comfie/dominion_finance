import '../../core/api_client.dart';
import '../../models/settings.dart';
import '../repository_exception.dart';
import '../settings_repository.dart';

/// [SettingsRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteSettingsRepository implements SettingsRepository {
  final ApiClient _apiClient;

  RemoteSettingsRepository(this._apiClient);

  @override
  Future<Settings> getSettings() async {
    try {
      final response = await _apiClient.getSettings();
      if (response.statusCode == 200) {
        return Settings.fromJson(response.data as Map<String, dynamic>);
      }
      throw const RepositoryException('Failed to load settings');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to load settings');
    }
  }

  @override
  Future<Settings> updateSettings(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateSettings(data);
      if (response.statusCode == 200) {
        return Settings.fromJson(response.data as Map<String, dynamic>);
      }
      throw const RepositoryException('Failed to update settings');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to update settings');
    }
  }
}
