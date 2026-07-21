/// Result of an AI receipt scan: best-effort extracted fields for the user
/// to review before creating an expense from them.
class ScannedReceipt {
  final String? name;
  final double? amount;
  final String? category;

  ScannedReceipt({this.name, this.amount, this.category});

  factory ScannedReceipt.fromJson(Map<String, dynamic> json) {
    return ScannedReceipt(
      name: json['name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      category: json['category'] as String?,
    );
  }
}

/// Abstract data access for AI-powered features. These always require the
/// remote API and an account - there is no on-device implementation, so
/// callers must gate access to this repository behind [StorageMode.cloud]
/// (see `storage_mode.dart`).
abstract class AiRepository {
  Future<ScannedReceipt> scanReceipt(String imageBase64, String mimeType);
}
