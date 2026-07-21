import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Platform (share sheet / file picker) glue for exporting/importing
/// backups produced by [BackupService] (backup_service.dart). Kept
/// separate from [BackupService] so the export/import logic itself stays
/// pure Dart and doesn't need platform channels to test.
class BackupIo {
  const BackupIo();

  /// Writes [json] to a temp file named `dominion-backup-YYYY-MM-DD.json`
  /// and opens the platform share sheet for it.
  Future<void> shareBackup(String json) async {
    final now = DateTime.now();
    final fileName =
        'dominion-backup-${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json', name: fileName)]),
    );
  }

  /// Opens a file picker restricted to `.json` files and returns its
  /// contents, or `null` if the user cancelled the picker.
  Future<String?> pickBackupJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    if (picked.bytes != null) {
      return utf8.decode(picked.bytes!);
    }
    final path = picked.path;
    if (path == null) return null;
    return File(path).readAsString();
  }
}
