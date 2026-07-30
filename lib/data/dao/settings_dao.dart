import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../app_database.dart';

/// Kho key-value của bảng `settings`.
///
/// Bảng này nhỏ (vài chục dòng) nhưng bị đọc rất dày: mỗi nhịp nhắc 30 giây
/// trước đây tốn khoảng 9 truy vấn chỉ để lấy cấu hình. Nên toàn bộ bảng được
/// nạp một lần vào bộ nhớ; ghi thì cập nhật luôn bộ nhớ đệm.
class SettingsDao {
  const SettingsDao();

  /// Static vì mọi nơi đều dùng `const SettingsDao()` — đệm phải sống chung
  /// cho tất cả instance mới có tác dụng.
  static Map<String, String?>? _cache;

  Future<Database> get _db => AppDatabase.instance.database;

  /// Xoá đệm khi dữ liệu bị thay đổi ngoài luồng ghi thường (khôi phục backup).
  static void invalidateCache() => _cache = null;

  Future<Map<String, String?>> _entries() async {
    final cached = _cache;
    if (cached != null) return cached;

    final rows = await (await _db).query('settings');
    return _cache = {
      for (final row in rows) row['key'] as String: row['value'] as String?,
    };
  }

  Future<String?> read(String key) async => (await _entries())[key];

  Future<void> write(String key, String value) async {
    await (await _db).insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final cached = _cache;
    if (cached != null) cached[key] = value;
  }
}
