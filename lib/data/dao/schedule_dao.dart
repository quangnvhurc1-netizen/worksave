import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../domain/models/schedule_item.dart';
import '../app_database.dart';

/// Truy cập bảng `schedules`.
class ScheduleDao {
  const ScheduleDao();

  Future<Database> get _db => AppDatabase.instance.database;

  static Map<String, Object?> toRow(ScheduleItem s) => {
        'date': s.date.toIsoDate(),
        'time': s.time?.format(),
        'content': s.content,
        'task_id': s.taskId,
        'remind': s.remind ? 1 : 0,
        'confirmed': s.confirmed ? 1 : 0,
        'last_notified_at': s.lastNotifiedAt?.toIso8601String(),
        'created_at': s.createdAt.toIso8601String(),
      };

  static ScheduleItem fromRow(Map<String, Object?> row) => ScheduleItem(
        id: row['id'] as int?,
        date: parseIsoDate(row['date'] as String),
        time: ClockTime.tryParse(row['time'] as String?),
        content: row['content'] as String? ?? '',
        taskId: row['task_id'] as int?,
        remind: (row['remind'] as int? ?? 1) == 1,
        confirmed: (row['confirmed'] as int? ?? 0) == 1,
        lastNotifiedAt: row['last_notified_at'] == null
            ? null
            : parseIsoDate(row['last_notified_at'] as String),
        createdAt: parseIsoDate(row['created_at'] as String),
      );

  Future<int> insert(ScheduleItem item) async =>
      (await _db).insert('schedules', toRow(item));

  Future<void> update(ScheduleItem item) async {
    if (item.id == null) return;
    await (await _db).update('schedules', toRow(item),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> delete(int id) async =>
      (await _db).delete('schedules', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteByTask(int taskId) async =>
      (await _db).delete('schedules', where: 'task_id = ?', whereArgs: [taskId]);

  Future<List<ScheduleItem>> findAll() async {
    final rows = await (await _db).query('schedules', orderBy: 'date ASC');
    return rows.map(fromRow).toList();
  }

  Future<ScheduleItem?> findByTask(int taskId) async {
    final rows = await (await _db)
        .query('schedules', where: 'task_id = ?', whereArgs: [taskId]);
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  /// Các mục còn bật nhắc, chưa xác nhận, thuộc ngày <= [maxDate].
  Future<List<ScheduleItem>> findPendingUpTo(DateTime maxDate) async {
    final rows = await (await _db).query('schedules',
        where: 'date <= ? AND confirmed = 0 AND remind = 1',
        whereArgs: [maxDate.toIsoDate()],
        orderBy: 'date ASC');
    return rows.map(fromRow).toList();
  }

  Future<void> setFields(int id, Map<String, Object?> values) async =>
      (await _db).update('schedules', values, where: 'id = ?', whereArgs: [id]);

  Future<void> setFieldsByTask(int taskId, Map<String, Object?> values) async =>
      (await _db)
          .update('schedules', values, where: 'task_id = ?', whereArgs: [taskId]);

  Future<List<ScheduleItem>> search(String like) async {
    final rows = await (await _db)
        .query('schedules', where: 'content LIKE ?', whereArgs: [like]);
    return rows.map(fromRow).toList();
  }
}
