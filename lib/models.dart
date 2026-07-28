/// Các model dữ liệu của WorkSave.

class TaskItem {
  final int? id;
  String title;
  String description; // Mô tả task
  String context; // Bối cảnh / hệ thống liên quan
  String blocker; // Vướng mắc
  String direction; // Hướng giải quyết dự kiến
  String status; // todo | doing | done
  DateTime? deadline; // hạn chót (có thể kèm giờ) -> tự đẩy sang lịch
  bool remindDeadline; // bật/tắt nhắc cho deadline này
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? doneAt;

  TaskItem({
    this.id,
    required this.title,
    this.description = '',
    this.context = '',
    this.blocker = '',
    this.direction = '',
    this.status = 'todo',
    this.deadline,
    this.remindDeadline = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.doneAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Deadline có đặt giờ cụ thể hay chỉ là cả ngày.
  bool get hasTime =>
      deadline != null && !(deadline!.hour == 0 && deadline!.minute == 0);

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'context': context,
        'blocker': blocker,
        'direction': direction,
        'status': status,
        'deadline': deadline?.toIso8601String(),
        'remind_deadline': remindDeadline ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'done_at': doneAt?.toIso8601String(),
      };

  static TaskItem fromMap(Map<String, Object?> m) => TaskItem(
        id: m['id'] as int?,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        context: m['context'] as String? ?? '',
        blocker: m['blocker'] as String? ?? '',
        direction: m['direction'] as String? ?? '',
        status: m['status'] as String? ?? 'todo',
        deadline: m['deadline'] == null
            ? null
            : DateTime.parse(m['deadline'] as String),
        remindDeadline: (m['remind_deadline'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        doneAt: m['done_at'] == null
            ? null
            : DateTime.parse(m['done_at'] as String),
      );
}

/// Nhật ký làm việc trong ngày (nguồn dữ liệu cho báo cáo tuần).
class WorkLog {
  final int? id;
  final int? taskId;
  String content;
  DateTime logDate; // ngày làm việc (chỉ lấy phần ngày)
  final DateTime createdAt;

  WorkLog({
    this.id,
    this.taskId,
    required this.content,
    DateTime? logDate,
    DateTime? createdAt,
  })  : logDate = logDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'content': content,
        'log_date': _dateOnly(logDate),
        'created_at': createdAt.toIso8601String(),
      };

  static WorkLog fromMap(Map<String, Object?> m) => WorkLog(
        id: m['id'] as int?,
        taskId: m['task_id'] as int?,
        content: m['content'] as String? ?? '',
        logDate: DateTime.parse(m['log_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Một phiên Pomodoro đã hoàn thành (chỉ ghi phiên FOCUS).
class PomodoroSession {
  final int? id;
  final int? taskId;
  final int minutes;
  final DateTime startedAt;
  final DateTime finishedAt;

  PomodoroSession({
    this.id,
    this.taskId,
    required this.minutes,
    required this.startedAt,
    required this.finishedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'minutes': minutes,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt.toIso8601String(),
      };

  static PomodoroSession fromMap(Map<String, Object?> m) => PomodoroSession(
        id: m['id'] as int?,
        taskId: m['task_id'] as int?,
        minutes: m['minutes'] as int? ?? 0,
        startedAt: DateTime.parse(m['started_at'] as String),
        finishedAt: DateTime.parse(m['finished_at'] as String),
      );
}

/// Nhật ký suy nghĩ tự do (khác work log gắn task: đây là "đang nghĩ gì").
class JournalEntry {
  final int? id;
  String content;
  final DateTime createdAt;

  JournalEntry({this.id, required this.content, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  static JournalEntry fromMap(Map<String, Object?> m) => JournalEntry(
        id: m['id'] as int?,
        content: m['content'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class Idea {
  final int? id;
  String content;
  final DateTime createdAt;

  Idea({this.id, required this.content, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  static Idea fromMap(Map<String, Object?> m) => Idea(
        id: m['id'] as int?,
        content: m['content'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Ghi chú lịch. Noti kiểu báo thức: nhắc 10 phút/lần tới khi confirmed.
/// [time] = 'HH:mm' nếu có giờ cụ thể, null = cả ngày (nhắc từ đầu ngày).
class ScheduleItem {
  final int? id;
  DateTime date; // ngày cần làm
  String? time; // 'HH:mm' hoặc null
  String content;
  int? taskId; // != null nếu là deadline tự đẩy từ task
  bool remind; // bật/tắt nhắc
  bool confirmed; // đã xác nhận xong -> ngừng nhắc
  DateTime? lastNotifiedAt; // lần nhắc gần nhất
  final DateTime createdAt;

  ScheduleItem({
    this.id,
    required this.date,
    this.time,
    required this.content,
    this.taskId,
    this.remind = true,
    this.confirmed = false,
    this.lastNotifiedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFromTask => taskId != null;

  /// Thời điểm tới hạn. Không đặt giờ -> dùng [dayStart] ('HH:mm') của
  /// cấu hình "giờ nhắc đầu ngày".
  DateTime dueAtWith(String dayStart) {
    final src = time ?? dayStart;
    final p = src.split(':');
    return DateTime(date.year, date.month, date.day,
        int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String get displayTime => time == null ? '' : '$time ';

  Map<String, Object?> toMap() => {
        'id': id,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'time': time,
        'content': content,
        'task_id': taskId,
        'remind': remind ? 1 : 0,
        'confirmed': confirmed ? 1 : 0,
        'last_notified_at': lastNotifiedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  static ScheduleItem fromMap(Map<String, Object?> m) => ScheduleItem(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        time: m['time'] as String?,
        content: m['content'] as String? ?? '',
        taskId: m['task_id'] as int?,
        remind: (m['remind'] as int? ?? 1) == 1,
        confirmed: (m['confirmed'] as int? ?? 0) == 1,
        lastNotifiedAt: m['last_notified_at'] == null
            ? null
            : DateTime.parse(m['last_notified_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// "Save game" - trạng thái làm việc tại một thời điểm.
class Checkpoint {
  final int? id;
  String doing; // Đang làm dở việc gì
  String nextStep; // Thứ 2 mở lên thì làm gì tiếp
  String remember; // Cần nhớ / lưu ý (mật khẩu tạm, đường dẫn file, ai đang chờ...)
  final DateTime createdAt;

  Checkpoint({
    this.id,
    required this.doing,
    this.nextStep = '',
    this.remember = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'doing': doing,
        'next_step': nextStep,
        'remember': remember,
        'created_at': createdAt.toIso8601String(),
      };

  static Checkpoint fromMap(Map<String, Object?> m) => Checkpoint(
        id: m['id'] as int?,
        doing: m['doing'] as String? ?? '',
        nextStep: m['next_step'] as String? ?? '',
        remember: m['remember'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
