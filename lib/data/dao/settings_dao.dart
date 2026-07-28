import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../app_database.dart';

/// Kho key-value của bảng `settings`.
class SettingsDao {
  const SettingsDao();

  Future<Database> get _db => AppDatabase.instance.database;

  Future<String?> read(String key) async {
    final rows =
        await (await _db).query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> write(String key, String value) async {
    await (await _db).insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
