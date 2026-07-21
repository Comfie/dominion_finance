import '../../core/api_client.dart';
import '../ai_repository.dart';
import '../repository_exception.dart';

/// [AiRepository] implementation backed by the remote HTTP API via
/// [ApiClient].
class RemoteAiRepository implements AiRepository {
  final ApiClient _apiClient;

  RemoteAiRepository(this._apiClient);

  @override
  Future<ScannedReceipt> scanReceipt(String imageBase64, String mimeType) async {
    try {
      final response = await _apiClient.scanReceipt(imageBase64, mimeType);
      if (response.statusCode == 200) {
        return ScannedReceipt.fromJson(response.data as Map<String, dynamic>);
      }
      throw const RepositoryException('Failed to scan receipt');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw const RepositoryException('Failed to scan receipt');
    }
  }
}
