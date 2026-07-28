import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/date_x.dart';
import '../../domain/models/notes.dart';
import '../app_database.dart';

/// Nhật ký làm việc gắn task (bảng `work_logs`).
class WorkLogDao {
  const WorkLogDao();
  Future<Database> get _db => AppDatabase.instance.database;

  static Map<String, Object?> toRow(WorkLog l) => {
        'task_id': l.taskId,
        'content': l.content,
        'log_date': l.logDate.toIsoDate(),
        'created_at': l.createdAt.toIso8601String(),
      };

  static WorkLog fromRow(Map<String, Object?> row) => WorkLog(
        id: row['id'] as int?,
        taskId: row['task_id'] as int?,
        content: row['content'] as String? ?? '',
        logDate: parseIsoDate(row['log_date'] as String),
        createdAt: parseIsoDate(row['created_at'] as String),
      );

  Future<int> insert(WorkLog log) async =>
      (await _db).insert('work_logs', toRow(log));

  Future<void> delete(int id) async =>
      (await _db).delete('work_logs', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteByTask(int taskId) async =>
      (await _db).delete('work_logs', where: 'task_id = ?', whereArgs: [taskId]);

  Future<List<WorkLog>> findByTask(int taskId) async {
    final rows = await (await _db).query('work_logs',
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'log_date DESC');
    return rows.map(fromRow).toList();
  }

  Future<List<WorkLog>> findBetween(DateTime from, DateTime to) async {
    final rows = await (await _db).query('work_logs',
        where: 'log_date >= ? AND log_date <= ?',
        whereArgs: [from.toIsoDate(), to.toIsoDate()],
        orderBy: 'log_date ASC, created_at ASC');
    return rows.map(fromRow).toList();
  }

  Future<List<WorkLog>> search(String like) async {
    final rows = await (await _db)
        .query('work_logs', where: 'content LIKE ?', whereArgs: [like]);
    return rows.map(fromRow).toList();
  }
}

/// Ý tưởng (bảng `ideas`).
class IdeaDao {
  const IdeaDao();
  Future<Database> get _db => AppDatabase.instance.database;

  static Idea fromRow(Map<String, Object?> row) => Idea(
        id: row['id'] as int?,
        content: row['content'] as String? ?? '',
        createdAt: parseIsoDate(row['created_at'] as String),
      );

  Future<int> insert(Idea idea) async => (await _db).insert('ideas', {
        'content': idea.content,
        'created_at': idea.createdAt.toIso8601String(),
      });

  Future<void> update(Idea idea) async {
    if (idea.id == null) return;
    await (await _db).update('ideas', {'content': idea.content},
        where: 'id = ?', whereArgs: [idea.id]);
  }

  Future<void> delete(int id) async =>
      (await _db).delete('ideas', where: 'id = ?', whereArgs: [id]);

  Future<List<Idea>> findAll() async {
    final rows = await (await _db).query('ideas', orderBy: 'created_at DESC');
    return rows.map(fromRow).toList();
  }

  Future<List<Idea>> search(String like) async {
    final rows =
        await (await _db).query('ideas', where: 'content LIKE ?', whereArgs: [like]);
    return rows.map(fromRow).toList();
  }
}

/// Nhật ký suy nghĩ (bảng `journal`).
class JournalDao {
  const JournalDao();
  Future<Database> get _db => AppDatabase.instance.database;

  static JournalEntry fromRow(Map<String, Object?> row) => JournalEntry(
        id: row['id'] as int?,
        content: row['content'] as String? ?? '',
        createdAt: parseIsoDate(row['created_at'] as String),
      );

  Future<int> insert(JournalEntry entry) async => (await _db).insert('journal', {
        'content': entry.content,
        'created_at': entry.createdAt.toIso8601String(),
      });

  Future<void> update(JournalEntry entry) async {
    if (entry.id == null) return;
    await (await _db).update('journal', {'content': entry.content},
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> delete(int id) async =>
      (await _db).delete('journal', where: 'id = ?', whereArgs: [id]);

  Future<List<JournalEntry>> findAll() async {
    final rows = await (await _db).query('journal', orderBy: 'created_at DESC');
    return rows.map(fromRow).toList();
  }

  Future<List<JournalEntry>> search(String like) async {
    final rows = await (await _db)
        .query('journal', where: 'content LIKE ?', whereArgs: [like]);
    return rows.map(fromRow).toList();
  }
}

/// Save trạng thái (bảng `checkpoints`).
class CheckpointDao {
  const CheckpointDao();
  Future<Database> get _db => AppDatabase.instance.database;

  static Checkpoint fromRow(Map<String, Object?> row) => Checkpoint(
        id: row['id'] as int?,
        doing: row['doing'] as String? ?? '',
        nextStep: row['next_step'] as String? ?? '',
        remember: row['remember'] as String? ?? '',
        createdAt: parseIsoDate(row['created_at'] as String),
      );

  Future<int> insert(Checkpoint c) async => (await _db).insert('checkpoints', {
        'doing': c.doing,
        'next_step': c.nextStep,
        'remember': c.remember,
        'created_at': c.createdAt.toIso8601String(),
      });

  Future<void> delete(int id) async =>
      (await _db).delete('checkpoints', where: 'id = ?', whereArgs: [id]);

  Future<List<Checkpoint>> findAll() async {
    final rows =
        await (await _db).query('checkpoints', orderBy: 'created_at DESC');
    return rows.map(fromRow).toList();
  }

  Future<Checkpoint?> findLatest() async {
    final rows = await (await _db)
        .query('checkpoints', orderBy: 'created_at DESC', limit: 1);
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  Future<List<Checkpoint>> search(String like) async {
    final rows = await (await _db).query('checkpoints',
        where: 'doing LIKE ? OR next_step LIKE ? OR remember LIKE ?',
        whereArgs: List.filled(3, like));
    return rows.map(fromRow).toList();
  }
}

/// Phiên Pomodoro (bảng `pomodoro`).
class PomodoroDao {
  const PomodoroDao();
  Future<Database> get _db => AppDatabase.instance.database;

  static PomodoroSession fromRow(Map<String, Object?> row) => PomodoroSession(
        id: row['id'] as int?,
        taskId: row['task_id'] as int?,
        minutes: row['minutes'] as int? ?? 0,
        startedAt: parseIsoDate(row['started_at'] as String),
        finishedAt: parseIsoDate(row['finished_at'] as String),
      );

  Future<int> insert(PomodoroSession s) async => (await _db).insert('pomodoro', {
        'task_id': s.taskId,
        'minutes': s.minutes,
        'started_at': s.startedAt.toIso8601String(),
        'finished_at': s.finishedAt.toIso8601String(),
      });

  Future<List<PomodoroSession>> findFinishedSince(DateTime since) async {
    final rows = await (await _db).query('pomodoro',
        where: 'finished_at >= ?', whereArgs: [since.toIso8601String()]);
    return rows.map(fromRow).toList();
  }

  Future<List<PomodoroSession>> findWithTask() async {
    final rows =
        await (await _db).query('pomodoro', where: 'task_id IS NOT NULL');
    return rows.map(fromRow).toList();
  }
}
