import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/deadline.dart';
import '../../domain/models/task.dart';
import '../app_database.dart';

/// Truy cập bảng `tasks`. Chỉ SQL + ánh xạ, không có logic nghiệp vụ.
class TaskDao {
  const TaskDao();

  Future<Database> get _db => AppDatabase.instance.database;

  static Map<String, Object?> toRow(Task t) => {
        'title': t.title,
        'description': t.description,
        'context': t.context,
        'blocker': t.blocker,
        'direction': t.direction,
        'status': t.status.dbValue,
        'deadline_date': t.deadline?.dbDate,
        'deadline_time': t.deadline?.dbTime,
        'remind_deadline': t.remindDeadline ? 1 : 0,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toIso8601String(),
        'done_at': t.doneAt?.toIso8601String(),
      };

  static Task fromRow(Map<String, Object?> row) => Task(
        id: row['id'] as int?,
        title: row['title'] as String? ?? '',
        description: row['description'] as String? ?? '',
        context: row['context'] as String? ?? '',
        blocker: row['blocker'] as String? ?? '',
        direction: row['direction'] as String? ?? '',
        status: TaskStatus.fromDb(row['status'] as String?),
        deadline: Deadline.fromDb(
            row['deadline_date'] as String?, row['deadline_time'] as String?),
        remindDeadline: (row['remind_deadline'] as int? ?? 1) == 1,
        createdAt: parseIsoDate(row['created_at'] as String),
        updatedAt: parseIsoDate(row['updated_at'] as String),
        doneAt: row['done_at'] == null
            ? null
            : parseIsoDate(row['done_at'] as String),
      );

  Future<int> insert(Task task) async =>
      (await _db).insert('tasks', toRow(task));

  Future<void> update(Task task) async {
    if (task.id == null) return;
    await (await _db)
        .update('tasks', toRow(task), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> delete(int id) async =>
      (await _db).delete('tasks', where: 'id = ?', whereArgs: [id]);

  Future<List<Task>> findAll() async {
    final rows = await (await _db).query('tasks', orderBy: 'updated_at DESC');
    return rows.map(fromRow).toList();
  }

  Future<List<Task>> findUnfinished() async {
    final rows = await (await _db).query('tasks',
        where: 'status != ?',
        whereArgs: [TaskStatus.done.dbValue],
        orderBy: 'updated_at ASC');
    return rows.map(fromRow).toList();
  }

  Future<Task?> findById(int id) async {
    final rows =
        await (await _db).query('tasks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  Future<Map<int, String>> titlesById() async {
    final rows = await (await _db).query('tasks', columns: ['id', 'title']);
    return {
      for (final row in rows) row['id'] as int: row['title'] as String? ?? '',
    };
  }

  Future<List<Task>> search(String like) async {
    final rows = await (await _db).query('tasks',
        where: 'title LIKE ? OR description LIKE ? OR context LIKE ? '
            'OR blocker LIKE ? OR direction LIKE ?',
        whereArgs: List.filled(5, like));
    return rows.map(fromRow).toList();
  }
}
