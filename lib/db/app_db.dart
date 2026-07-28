import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models.dart';
import '../services/l10n.dart';

/// SQLite local, lưu tại thư mục AppData của Windows.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final String dbPath = p.join(dir.path, 'worksave.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          await _createV1(db);
          await _createV2(db);
          await _createV3(db);
          await _createV4(db);
          await _createV5(db);
        },
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) await _createV2(db);
          if (oldV < 3) await _createV3(db);
          if (oldV < 4) await _createV4(db);
          if (oldV < 5) await _createV5(db);
        },
      ),
    );
    return _db!;
  }

  /// Kiểm tra xem [table] đã có cột tên [column] hay chưa.
  /// Dùng PRAGMA table_info thay vì đoán mò, để các lệnh ALTER TABLE
  /// phía dưới có thể chạy lại nhiều lần mà không báo lỗi
  /// "duplicate column name" nếu migration trước đó từng chạy dở dang.
  Future<bool> _columnExists(Database db, String table, String column) async {
    final List<Map<String, Object?>> columns =
        await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((Map<String, Object?> c) => c['name'] == column);
  }

  /// Thêm cột [column] vào [table] nếu chưa có. An toàn khi gọi lại nhiều lần.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String columnDefinition, // ví dụ: 'TEXT' hoặc 'INTEGER DEFAULT 1'
  ) async {
    if (!await _columnExists(db, table, column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $columnDefinition');
    }
  }

  Future<void> _createV5(Database db) async {
    await _addColumnIfMissing(db, 'schedules', 'time', 'TEXT');
    await _addColumnIfMissing(db, 'schedules', 'remind', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'tasks', 'remind_deadline', 'INTEGER DEFAULT 1');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pomodoro(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        minutes INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV4(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV3(Database db) async {
    await _addColumnIfMissing(db, 'tasks', 'deadline', 'TEXT');
    await _addColumnIfMissing(db, 'schedules', 'task_id', 'INTEGER');
    await _addColumnIfMissing(db, 'schedules', 'confirmed', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'schedules', 'last_notified_at', 'TEXT');
    // Các mục cũ đã báo 1 lần -> coi như đã xác nhận, tránh nhắc lại dồn dập.
    await db.execute('UPDATE schedules SET confirmed = notified');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        notified INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV1(Database db) async {
          await db.execute('''
            CREATE TABLE tasks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT DEFAULT '',
              context TEXT DEFAULT '',
              blocker TEXT DEFAULT '',
              direction TEXT DEFAULT '',
              status TEXT DEFAULT 'todo',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              done_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE work_logs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER,
              content TEXT NOT NULL,
              log_date TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ideas(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE checkpoints(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              doing TEXT NOT NULL,
              next_step TEXT DEFAULT '',
              remember TEXT DEFAULT '',
              created_at TEXT NOT NULL
            )
          ''');
  }

  // ---------- Tasks ----------
  Future<int> insertTask(TaskItem t) async {
    final d = await db;
    return d.insert('tasks', t.toMap()..remove('id'));
  }

  Future<void> updateTask(TaskItem t) async {
    final d = await db;
    t.updatedAt = DateTime.now();
    await d.update('tasks', t.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTask(int id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await d.delete('work_logs', where: 'task_id = ?', whereArgs: [id]);
    await d.delete('schedules', where: 'task_id = ?', whereArgs: [id]);
  }

  Future<List<TaskItem>> getTasks() async {
    final d = await db;
    final rows = await d.query('tasks', orderBy: 'updated_at DESC');
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> getUnfinishedTasks() async {
    final d = await db;
    final rows = await d.query('tasks',
        where: "status != 'done'", orderBy: 'updated_at ASC');
    return rows.map(TaskItem.fromMap).toList();
  }

  // ---------- Work logs ----------
  Future<int> insertLog(WorkLog l) async {
    final d = await db;
    return d.insert('work_logs', l.toMap()..remove('id'));
  }

  Future<void> deleteLog(int id) async {
    final d = await db;
    await d.delete('work_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkLog>> getLogsForTask(int taskId) async {
    final d = await db;
    final rows = await d.query('work_logs',
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'log_date DESC');
    return rows.map(WorkLog.fromMap).toList();
  }

  /// Log trong khoảng [from, to] (bao gồm 2 đầu), from/to dạng yyyy-MM-dd.
  Future<List<WorkLog>> getLogsBetween(String from, String to) async {
    final d = await db;
    final rows = await d.query('work_logs',
        where: 'log_date >= ? AND log_date <= ?',
        whereArgs: [from, to],
        orderBy: 'log_date ASC, created_at ASC');
    return rows.map(WorkLog.fromMap).toList();
  }

  // ---------- Ideas ----------
  Future<int> insertIdea(Idea i) async {
    final d = await db;
    return d.insert('ideas', i.toMap()..remove('id'));
  }

  Future<void> updateIdea(Idea i) async {
    final d = await db;
    await d.update('ideas', i.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [i.id]);
  }

  Future<void> deleteIdea(int id) async {
    final d = await db;
    await d.delete('ideas', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Idea>> getIdeas() async {
    final d = await db;
    final rows = await d.query('ideas', orderBy: 'created_at DESC');
    return rows.map(Idea.fromMap).toList();
  }

  // ---------- Checkpoints ----------
  Future<int> insertCheckpoint(Checkpoint c) async {
    final d = await db;
    return d.insert('checkpoints', c.toMap()..remove('id'));
  }

  Future<void> deleteCheckpoint(int id) async {
    final d = await db;
    await d.delete('checkpoints', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Checkpoint>> getCheckpoints() async {
    final d = await db;
    final rows = await d.query('checkpoints', orderBy: 'created_at DESC');
    return rows.map(Checkpoint.fromMap).toList();
  }

  Future<Checkpoint?> getLatestCheckpoint() async {
    final d = await db;
    final rows =
        await d.query('checkpoints', orderBy: 'created_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Checkpoint.fromMap(rows.first);
  }

  // ---------- Task detail (kèm log) cho prompt AI ----------
  Future<String> buildTaskAiPrompt(TaskItem t) async {
    final logs = t.id == null ? <WorkLog>[] : await getLogsForTask(t.id!);
    final b = StringBuffer();
    b.writeln(
        'Tôi đang xử lý một task trong công việc, dưới đây là toàn bộ thông tin. '
        'Hãy phân tích và gợi ý cho tôi hướng giải quyết cụ thể, từng bước.');
    b.writeln();
    b.writeln('## Task: ${t.title}');
    b.writeln('- Trạng thái: ${statusLabel(t.status)}');
    if (t.deadline != null) {
      b.writeln('- Deadline: ${fmtDateTime(t.deadline!, withTime: t.hasTime)}');
    }
    if (t.description.trim().isNotEmpty) {
      b.writeln('- Mô tả: ${t.description.trim()}');
    }
    if (t.context.trim().isNotEmpty) {
      b.writeln('- Bối cảnh / hệ thống liên quan: ${t.context.trim()}');
    }
    if (t.blocker.trim().isNotEmpty) {
      b.writeln('- Vướng mắc hiện tại: ${t.blocker.trim()}');
    }
    if (t.direction.trim().isNotEmpty) {
      b.writeln('- Hướng giải quyết tôi đang nghĩ tới: ${t.direction.trim()}');
    }
    if (logs.isNotEmpty) {
      b.writeln();
      b.writeln('## Nhật ký đã làm:');
      for (final l in logs.reversed) {
        b.writeln('- [${fmtDate(l.logDate)}] ${l.content.trim()}');
      }
    }
    b.writeln();
    b.writeln('Yêu cầu: gợi ý các bước tiếp theo, rủi ro cần lưu ý, '
        'và nếu thiếu thông tin thì liệt kê câu hỏi tôi cần làm rõ.');
    return b.toString();
  }

  // ---------- Settings (key-value) ----------
  Future<String?> getSetting(String key) async {
    final d = await db;
    final rows =
        await d.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Schedules ----------
  Future<int> insertSchedule(ScheduleItem s) async {
    final d = await db;
    return d.insert('schedules', s.toMap()..remove('id'));
  }

  Future<void> updateSchedule(ScheduleItem s) async {
    final d = await db;
    await d.update('schedules', s.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSchedule(int id) async {
    final d = await db;
    await d.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScheduleItem>> getSchedules() async {
    final d = await db;
    final rows = await d.query('schedules', orderBy: 'date ASC');
    return rows.map(ScheduleItem.fromMap).toList();
  }

  // ---------- Cấu hình nhắc ----------
  static const String defaultDayStart = '08:00';
  static const int defaultLeadMinutes = 10;
  static const int defaultNagMinutes = 10;

  Future<String> get dayStartTime async =>
      (await getSetting('day_start_time'))?.trim().isNotEmpty == true
          ? (await getSetting('day_start_time'))!.trim()
          : defaultDayStart;

  Future<int> get leadMinutes async =>
      int.tryParse(await getSetting('lead_minutes') ?? '') ??
      defaultLeadMinutes;

  Future<int> get nagMinutes async =>
      int.tryParse(await getSetting('nag_minutes') ?? '') ?? defaultNagMinutes;

  /// Các mục cần nhắc NGAY BÂY GIỜ.
  ///
  /// Quy tắc:
  /// - Mốc tới hạn = ngày + giờ đã đặt; không đặt giờ -> giờ "đầu ngày"
  ///   trong cấu hình (mặc định 08:00).
  /// - Bắt đầu nhắc TRƯỚC mốc [leadMinutes] phút (mặc định 10).
  /// - Sau đó nhắc lại mỗi [nagMinutes] phút cho tới khi xác nhận Done.
  /// - Tắt nhắc (remind = 0) hoặc đã xác nhận -> bỏ qua.
  Future<List<DueReminder>> getDueNagging() async {
    final d = await db;
    final now = DateTime.now();
    final dayStart = await dayStartTime;
    final lead = Duration(minutes: await leadMinutes);
    final nag = Duration(minutes: await nagMinutes);

    // Lấy cả mục của ngày mai để còn báo trước qua đêm (vd hẹn 00:05).
    final tomorrow = now.add(const Duration(days: 1));
    final limit =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final rows = await d.query('schedules',
        where: 'date <= ? AND confirmed = 0 AND remind = 1',
        whereArgs: [limit],
        orderBy: 'date ASC');

    final out = <DueReminder>[];
    for (final s in rows.map(ScheduleItem.fromMap)) {
      final due = s.dueAtWith(dayStart);
      final startNagging = due.subtract(lead);
      if (now.isBefore(startNagging)) continue; // chưa tới lúc báo trước
      if (s.lastNotifiedAt != null &&
          now.difference(s.lastNotifiedAt!) < nag) {
        continue; // vừa nhắc xong, chờ hết chu kỳ
      }
      final minutesLeft = due.difference(now).inMinutes;
      out.add(DueReminder(s, due, minutesLeft));
    }
    return out;
  }

  /// Bật / tắt nhắc cho 1 mục lịch.
  Future<void> setScheduleRemind(int id, bool remind) async {
    final d = await db;
    await d.update('schedules',
        {'remind': remind ? 1 : 0, 'last_notified_at': null},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Ghi nhận vừa nhắc xong (để 10 phút sau mới nhắc lại).
  Future<void> touchNotified(int id) async {
    final d = await db;
    await d.update(
        'schedules', {'last_notified_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Xác nhận đã xong -> ngừng nhắc vĩnh viễn.
  Future<void> confirmSchedule(int id, {bool confirmed = true}) async {
    final d = await db;
    await d.update('schedules',
        {'confirmed': confirmed ? 1 : 0, 'last_notified_at': null},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Xác nhận / bỏ xác nhận mục lịch gắn với 1 task (khi task Done / mở lại).
  Future<void> confirmSchedulesForTask(int taskId,
      {bool confirmed = true}) async {
    final d = await db;
    await d.update('schedules',
        {'confirmed': confirmed ? 1 : 0, 'last_notified_at': null},
        where: 'task_id = ?', whereArgs: [taskId]);
  }

  /// Đồng bộ deadline của task sang lịch:
  /// - có deadline -> tạo/cập nhật mục lịch [Deadline] gắn task_id
  /// - bỏ deadline -> xóa mục lịch gắn task_id
  Future<void> syncTaskSchedule(TaskItem t) async {
    if (t.id == null) return;
    final d = await db;
    final existing = await d
        .query('schedules', where: 'task_id = ?', whereArgs: [t.id]);

    if (t.deadline == null) {
      if (existing.isNotEmpty) {
        await d.delete('schedules', where: 'task_id = ?', whereArgs: [t.id]);
      }
      return;
    }

    final dl = t.deadline!;
    final dateStr =
        '${dl.year.toString().padLeft(4, '0')}-${dl.month.toString().padLeft(2, '0')}-${dl.day.toString().padLeft(2, '0')}';
    final timeStr = t.hasTime
        ? '${dl.hour.toString().padLeft(2, '0')}:${dl.minute.toString().padLeft(2, '0')}'
        : null;
    final content = '[Deadline] ${t.title}';
    final isDone = t.status == 'done';

    if (existing.isEmpty) {
      await d.insert('schedules', {
        'date': dateStr,
        'time': timeStr,
        'content': content,
        'task_id': t.id,
        'remind': t.remindDeadline ? 1 : 0,
        'confirmed': isDone ? 1 : 0,
        'last_notified_at': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      final old = ScheduleItem.fromMap(existing.first);
      final changed = old.toMap()['date'] != dateStr || old.time != timeStr;
      await d.update(
          'schedules',
          {
            'date': dateStr,
            'time': timeStr,
            'content': content,
            'remind': t.remindDeadline ? 1 : 0,
            // Đổi deadline hoặc mở lại task -> nhắc lại từ đầu.
            'confirmed':
                isDone ? 1 : (changed ? 0 : (old.confirmed ? 1 : 0)),
            if (changed) 'last_notified_at': null,
          },
          where: 'task_id = ?',
          whereArgs: [t.id]);
    }
  }

  // ---------- Journal (nhật ký suy nghĩ) ----------
  Future<int> insertJournal(JournalEntry j) async {
    final d = await db;
    return d.insert('journal', j.toMap()..remove('id'));
  }

  Future<void> updateJournal(JournalEntry j) async {
    final d = await db;
    await d.update('journal', j.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [j.id]);
  }

  Future<void> deleteJournal(int id) async {
    final d = await db;
    await d.delete('journal', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<JournalEntry>> getJournal() async {
    final d = await db;
    final rows = await d.query('journal', orderBy: 'created_at DESC');
    return rows.map(JournalEntry.fromMap).toList();
  }

  // ---------- Tìm kiếm toàn app ----------
  Future<List<SearchHit>> searchAll(String q) async {
    final d = await db;
    final like = '%$q%';
    final hits = <SearchHit>[];
    String cut(String s, [int n = 100]) {
      final t = s.trim().replaceAll('\n', ' · ');
      return t.length <= n ? t : '${t.substring(0, n)}…';
    }

    final tasks = await d.query('tasks',
        where:
            'title LIKE ? OR description LIKE ? OR context LIKE ? OR blocker LIKE ? OR direction LIKE ?',
        whereArgs: [like, like, like, like, like]);
    for (final r in tasks.map(TaskItem.fromMap)) {
      hits.add(SearchHit(
          'Task',
          r.title,
          cut('${statusLabel(r.status)} · ${r.description} ${r.blocker}'),
          fmtDate(r.updatedAt)));
    }

    final taskRows = await d.query('tasks', columns: ['id', 'title']);
    final titleById = {
      for (final r in taskRows) r['id'] as int: r['title'] as String? ?? ''
    };
    final logs =
        await d.query('work_logs', where: 'content LIKE ?', whereArgs: [like]);
    for (final r in logs.map(WorkLog.fromMap)) {
      hits.add(SearchHit('Log', titleById[r.taskId] ?? '(task đã xóa)',
          cut(r.content), fmtDate(r.logDate)));
    }

    final ideas =
        await d.query('ideas', where: 'content LIKE ?', whereArgs: [like]);
    for (final r in ideas.map(Idea.fromMap)) {
      hits.add(SearchHit(
          'Ý tưởng', cut(r.content, 60), cut(r.content), fmtDate(r.createdAt)));
    }

    final journal =
        await d.query('journal', where: 'content LIKE ?', whereArgs: [like]);
    for (final r in journal.map(JournalEntry.fromMap)) {
      hits.add(SearchHit(
          'Nhật ký', cut(r.content, 60), cut(r.content), fmtDate(r.createdAt)));
    }

    final cps = await d.query('checkpoints',
        where: 'doing LIKE ? OR next_step LIKE ? OR remember LIKE ?',
        whereArgs: [like, like, like]);
    for (final r in cps.map(Checkpoint.fromMap)) {
      hits.add(SearchHit('Save', cut(r.doing, 60),
          cut('${r.nextStep} ${r.remember}'), fmtDate(r.createdAt)));
    }

    final sch =
        await d.query('schedules', where: 'content LIKE ?', whereArgs: [like]);
    for (final r in sch.map(ScheduleItem.fromMap)) {
      hits.add(SearchHit('Lịch', cut(r.content, 60),
          r.confirmed ? 'Đã xác nhận xong' : 'Chưa xong', fmtDate(r.date)));
    }

    return hits;
  }

  // ---------- Pomodoro ----------
  Future<int> insertPomodoro(PomodoroSession s) async {
    final d = await db;
    return d.insert('pomodoro', s.toMap()..remove('id'));
  }

  /// Số phiên + tổng phút focus của hôm nay.
  Future<(int count, int minutes)> pomodoroToday() async {
    final d = await db;
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day).toIso8601String();
    final rows = await d.query('pomodoro',
        where: 'finished_at >= ?', whereArgs: [start]);
    final sessions = rows.map(PomodoroSession.fromMap);
    return (
      sessions.length,
      sessions.fold<int>(0, (a, s) => a + s.minutes),
    );
  }

  /// Tổng phút focus theo từng task (để biết task nào ngốn thời gian).
  Future<Map<int, int>> pomodoroMinutesByTask() async {
    final d = await db;
    final rows = await d.query('pomodoro', where: 'task_id IS NOT NULL');
    final map = <int, int>{};
    for (final s in rows.map(PomodoroSession.fromMap)) {
      map[s.taskId!] = (map[s.taskId!] ?? 0) + s.minutes;
    }
    return map;
  }

  // ---------- Backup / Restore ----------
  static const List<String> _allTables = [
    'tasks', 'work_logs', 'ideas', 'checkpoints',
    'settings', 'schedules', 'journal', 'pomodoro',
  ];

  Future<Map<String, Object?>> dumpAll() async {
    final d = await db;
    final tables = <String, Object?>{};
    for (final t in _allTables) {
      tables[t] = await d.query(t);
    }
    return {
      'app': 'worksave',
      'version': 5,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  /// GHI ĐÈ toàn bộ dữ liệu hiện tại bằng dữ liệu trong file backup.
  Future<void> restoreAll(Map<String, dynamic> data) async {
    if (data['app'] != 'worksave' || data['tables'] is! Map) {
      throw Exception('File không phải backup của WorkSave.');
    }
    final d = await db;
    final tables = data['tables'] as Map;
    await d.transaction((txn) async {
      for (final t in _allTables) {
        await txn.delete(t);
        final rows = tables[t];
        if (rows is List) {
          for (final r in rows) {
            await txn.insert(t, Map<String, Object?>.from(r as Map));
          }
        }
      }
    });
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'doing':
        return L10n.t('status_doing');
      case 'done':
        return L10n.t('status_done');
      default:
        return L10n.t('status_todo');
    }
  }
}

/// dd/MM/yyyy
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// dd/MM/yyyy HH:mm (bỏ giờ nếu withTime = false)
String fmtDateTime(DateTime d, {bool withTime = true}) => withTime
    ? '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
    : fmtDate(d);

/// Một mục tới lúc cần nhắc, kèm mốc hạn và số phút còn lại
/// (âm = đã quá hạn).
class DueReminder {
  final ScheduleItem item;
  final DateTime dueAt;
  final int minutesLeft;
  DueReminder(this.item, this.dueAt, this.minutesLeft);

  bool get isEarly => minutesLeft > 0;
  bool get isOverdue => minutesLeft < 0;
}

/// Một kết quả tìm kiếm toàn app.
class SearchHit {
  final String type; // Task | Log | Ý tưởng | Nhật ký | Save | Lịch
  final String title;
  final String snippet;
  final String date;
  SearchHit(this.type, this.title, this.snippet, this.date);
}
