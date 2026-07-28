import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../core/date_x.dart';
import '../data/repositories/repositories.dart';

/// Kết quả một thao tác sao lưu / khôi phục, để UI quyết định hiển thị gì.
sealed class BackupResult {
  const BackupResult();
}

class BackupCancelled extends BackupResult {
  const BackupCancelled();
}

class BackupSucceeded extends BackupResult {
  const BackupSucceeded(this.path);
  final String path;
}

class BackupFailed extends BackupResult {
  const BackupFailed(this.error);
  final Object error;
}

/// Đọc-ghi file backup. Không đụng tới BuildContext — UI tự hiển thị kết quả.
class BackupService {
  const BackupService();

  static const XTypeGroup _jsonGroup =
      XTypeGroup(label: 'WorkSave backup', extensions: ['json']);

  Future<BackupResult> exportToFile() async {
    final now = DateTime.now();
    final location = await getSaveLocation(
      suggestedName: 'worksave-backup-${now.toIsoDate()}.json',
      acceptedTypeGroups: const [_jsonGroup],
    );
    if (location == null) return const BackupCancelled();

    try {
      final data = await Repos.backup.export();
      await File(location.path)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      return BackupSucceeded(location.path);
    } catch (error) {
      return BackupFailed(error);
    }
  }

  /// Chọn file và trả về đường dẫn; việc xác nhận ghi đè do UI đảm nhiệm.
  Future<XFile?> pickBackupFile() =>
      openFile(acceptedTypeGroups: const [_jsonGroup]);

  Future<BackupResult> importFrom(XFile file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const BackupFailed(FormatException('Invalid backup file'));
      }
      await Repos.backup.import(decoded);
      return BackupSucceeded(file.path);
    } catch (error) {
      return BackupFailed(error);
    }
  }
}
