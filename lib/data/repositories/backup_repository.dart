import '../app_database.dart';
import '../dao/backup_dao.dart';

/// Đóng gói / khôi phục toàn bộ dữ liệu dưới dạng map JSON-able.
/// Phần đọc-ghi file nằm ở tầng service, không nằm ở đây.
class BackupRepository {
  const BackupRepository({BackupDao dao = const BackupDao()}) : _dao = dao;
  final BackupDao _dao;

  static const String _appMarker = 'worksave';

  Future<Map<String, Object?>> export() async => {
        'app': _appMarker,
        'version': AppDatabase.schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'tables': await _dao.dumpAll(),
      };

  /// Ném [FormatException] nếu file không phải backup của app này.
  Future<void> import(Map<String, dynamic> data) async {
    if (data['app'] != _appMarker || data['tables'] is! Map) {
      throw const FormatException('Not a WorkSave backup file');
    }
    await _dao.restoreAll(Map<String, dynamic>.from(data['tables'] as Map));
  }
}
