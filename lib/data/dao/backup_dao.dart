import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../app_database.dart';

/// Xuất / nạp toàn bộ bảng cho tính năng sao lưu.
class BackupDao {
  const BackupDao();

  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final db = await _db;
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in AppDatabase.tables) {
      result[table] = await db.query(table);
    }
    return result;
  }

  /// Xóa sạch rồi nạp lại — chạy trong một transaction để không bị nửa vời.
  Future<void> restoreAll(Map<String, dynamic> tables) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in AppDatabase.tables) {
        await txn.delete(table);
        final rows = tables[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is Map) {
            await txn.insert(table, Map<String, Object?>.from(row));
          }
        }
      }
    });
  }
}
