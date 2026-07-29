import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/attendance.dart';
import '../app_database.dart';

/// Truy cập ba bảng của tính năng chấm công.
class AttendanceDao {
  const AttendanceDao();

  Future<Database> get _db => AppDatabase.instance.database;

  // ---- Lịch lặp ----
  static AttendanceRule _ruleFromRow(Map<String, Object?> row) => AttendanceRule(
        id: row['id'] as int?,
        kind: AttendanceKind.fromDb(row['kind'] as String?),
        time: ClockTime.tryParse(row['time'] as String?) ??
            const ClockTime(8, 0),
        weekdays: (row['weekdays'] as String? ?? '')
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .toSet(),
        enabled: (row['enabled'] as int? ?? 0) == 1,
      );

  Future<List<AttendanceRule>> rules() async {
    final rows = await (await _db).query('attendance_rules', orderBy: 'time ASC');
    return rows.map(_ruleFromRow).toList();
  }

  Future<void> upsertRule(AttendanceRule rule) async {
    await (await _db).insert(
      'attendance_rules',
      {
        'kind': rule.kind.dbValue,
        'time': rule.time.format(),
        'weekdays': (rule.weekdays.toList()..sort()).join(','),
        'enabled': rule.enabled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Ngoại lệ theo ngày ----
  static AttendanceOverride _overrideFromRow(Map<String, Object?> row) =>
      AttendanceOverride(
        id: row['id'] as int?,
        date: parseIsoDate(row['date'] as String),
        kind: AttendanceKind.fromDb(row['kind'] as String?),
        time: ClockTime.tryParse(row['time'] as String?),
        note: row['note'] as String? ?? '',
      );

  Future<List<AttendanceOverride>> overridesOn(DateTime date) async {
    final rows = await (await _db).query('attendance_overrides',
        where: 'date = ?', whereArgs: [date.toIsoDate()]);
    return rows.map(_overrideFromRow).toList();
  }

  Future<List<AttendanceOverride>> overridesFrom(DateTime from) async {
    final rows = await (await _db).query('attendance_overrides',
        where: 'date >= ?', whereArgs: [from.toIsoDate()], orderBy: 'date ASC');
    return rows.map(_overrideFromRow).toList();
  }

  Future<void> upsertOverride(AttendanceOverride item) async {
    await (await _db).insert(
      'attendance_overrides',
      {
        'date': item.date.toIsoDate(),
        'kind': item.kind.dbValue,
        'time': item.time?.format(),
        'note': item.note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteOverride(int id) async =>
      (await _db).delete('attendance_overrides', where: 'id = ?', whereArgs: [id]);

  // ---- Trạng thái theo ngày ----
  Future<Map<String, Object?>?> stateOf(DateTime date, AttendanceKind kind) async {
    final rows = await (await _db).query('attendance_state',
        where: 'date = ? AND kind = ?',
        whereArgs: [date.toIsoDate(), kind.dbValue]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _writeState(
      DateTime date, AttendanceKind kind, Map<String, Object?> values) async {
    final db = await _db;
    final existing = await stateOf(date, kind);
    if (existing == null) {
      await db.insert('attendance_state', {
        'date': date.toIsoDate(),
        'kind': kind.dbValue,
        ...values,
      });
    } else {
      await db.update('attendance_state', values,
          where: 'date = ? AND kind = ?',
          whereArgs: [date.toIsoDate(), kind.dbValue]);
    }
  }

  Future<void> markNotified(DateTime date, AttendanceKind kind) => _writeState(
      date, kind, {'last_notified_at': DateTime.now().toIso8601String()});

  Future<void> clearNotified(DateTime date, AttendanceKind kind) =>
      _writeState(date, kind, {'last_notified_at': null});

  Future<void> setConfirmed(
    DateTime date,
    AttendanceKind kind, {
    required bool confirmed,
  }) =>
      _writeState(date, kind, {
        'confirmed_at': confirmed ? DateTime.now().toIso8601String() : null,
        'last_notified_at': null,
      });
}
