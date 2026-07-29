import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chỉ lo mở kết nối và chạy migration. Không chứa câu truy vấn nghiệp vụ nào
/// — những thứ đó nằm ở các DAO.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int schemaVersion = 7;

  /// Tên mọi bảng, dùng cho sao lưu / khôi phục.
  static const List<String> tables = [
    'tasks',
    'work_logs',
    'ideas',
    'checkpoints',
    'settings',
    'schedules',
    'journal',
    'pomodoro',
    'attendance_rules',
    'attendance_overrides',
    'attendance_state',
  ];

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);

    return databaseFactory.openDatabase(
      p.join(dir.path, 'worksave.db'),
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) async {
          for (var v = 1; v <= schemaVersion; v++) {
            await _migrateTo(db, v);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var v = oldVersion + 1; v <= newVersion; v++) {
            await _migrateTo(db, v);
          }
        },
      ),
    );
  }

  Future<void> _migrateTo(Database db, int version) async {
    switch (version) {
      case 1:
        await _createInitial(db);
      case 2:
        await _addSettingsAndSchedules(db);
      case 3:
        await _addDeadlineAndConfirm(db);
      case 4:
        await _addJournal(db);
      case 5:
        await _addTimeAndPomodoro(db);
      case 6:
        await _splitDeadlineIntoDateAndTime(db);
      case 7:
        await _addAttendance(db);
    }
  }

  /// Nhắc chấm công: lịch lặp hằng tuần, ngoại lệ theo ngày (OT / nghỉ),
  /// và trạng thái đã nhắc / đã xác nhận của từng ngày.
  Future<void> _addAttendance(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL UNIQUE,
        time TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        enabled INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_overrides(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        time TEXT,
        note TEXT DEFAULT '',
        UNIQUE(date, kind)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_state(
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        last_notified_at TEXT,
        confirmed_at TEXT,
        PRIMARY KEY(date, kind)
      )
    ''');

    // Giờ gợi ý sẵn nhưng TẮT, để app không tự bắn thông báo sai giờ.
    await db.insert('attendance_rules', {
      'kind': 'in',
      'time': '07:30',
      'weekdays': '1,2,3,4,5',
      'enabled': 0,
    });
    await db.insert('attendance_rules', {
      'kind': 'out',
      'time': '17:00',
      'weekdays': '1,2,3,4,5',
      'enabled': 0,
    });
  }

  Future<void> _createInitial(Database db) async {
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

  Future<void> _addSettingsAndSchedules(Database db) async {
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

  Future<void> _addDeadlineAndConfirm(Database db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN deadline TEXT');
    await db.execute('ALTER TABLE schedules ADD COLUMN task_id INTEGER');
    await db.execute(
        'ALTER TABLE schedules ADD COLUMN confirmed INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE schedules ADD COLUMN last_notified_at TEXT');
    await db.execute('UPDATE schedules SET confirmed = notified');
  }

  Future<void> _addJournal(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addTimeAndPomodoro(Database db) async {
    await db.execute('ALTER TABLE schedules ADD COLUMN time TEXT');
    await db
        .execute('ALTER TABLE schedules ADD COLUMN remind INTEGER DEFAULT 1');
    await db.execute(
        'ALTER TABLE tasks ADD COLUMN remind_deadline INTEGER DEFAULT 1');
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

  /// Tách `deadline` (ISO datetime) thành `deadline_date` + `deadline_time`.
  /// Trước đây "có giờ hay không" được suy ra từ `hour == 0 && minute == 0`,
  /// nên deadline đúng 00:00 bị hiểu nhầm là cả ngày.
  Future<void> _splitDeadlineIntoDateAndTime(Database db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN deadline_date TEXT');
    await db.execute('ALTER TABLE tasks ADD COLUMN deadline_time TEXT');

    final rows = await db.query('tasks',
        columns: ['id', 'deadline'], where: 'deadline IS NOT NULL');
    for (final row in rows) {
      final raw = row['deadline'] as String?;
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      final isAllDay = parsed.hour == 0 && parsed.minute == 0;
      await db.update(
        'tasks',
        {
          'deadline_date':
              '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}',
          'deadline_time': isAllDay
              ? null
              : '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}',
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}
