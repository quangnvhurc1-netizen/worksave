import 'package:meta/meta.dart';

/// Nhật ký làm việc gắn với một task — nguồn dữ liệu cho báo cáo tuần.
@immutable
class WorkLog {
  final int? id;
  final int? taskId;
  final String content;
  final DateTime logDate;
  final DateTime createdAt;

  WorkLog({
    this.id,
    this.taskId,
    required this.content,
    DateTime? logDate,
    DateTime? createdAt,
  })  : logDate = logDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();
}

/// Ghi chú ý tưởng rời.
@immutable
class Idea {
  final int? id;
  final String content;
  final DateTime createdAt;

  Idea({this.id, required this.content, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Idea copyWith({String? content}) =>
      Idea(id: id, content: content ?? this.content, createdAt: createdAt);
}

/// Nhật ký suy nghĩ tự do ("đang nghĩ gì"), khác WorkLog ("đã làm gì").
@immutable
class JournalEntry {
  final int? id;
  final String content;
  final DateTime createdAt;

  JournalEntry({this.id, required this.content, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  JournalEntry copyWith({String? content}) => JournalEntry(
      id: id, content: content ?? this.content, createdAt: createdAt);
}

/// "Save game": trạng thái làm việc tại một thời điểm.
@immutable
class Checkpoint {
  final int? id;
  final String doing;
  final String nextStep;
  final String remember;
  final DateTime createdAt;

  Checkpoint({
    this.id,
    required this.doing,
    this.nextStep = '',
    this.remember = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Một phiên Pomodoro đã hoàn thành (chỉ ghi phiên focus).
@immutable
class PomodoroSession {
  final int? id;
  final int? taskId;
  final int minutes;
  final DateTime startedAt;
  final DateTime finishedAt;

  const PomodoroSession({
    this.id,
    this.taskId,
    required this.minutes,
    required this.startedAt,
    required this.finishedAt,
  });
}
