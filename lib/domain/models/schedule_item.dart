import 'package:meta/meta.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';

/// Một mục trên lịch. Có thể do người dùng nhập tay, hoặc sinh ra từ
/// deadline của một task (khi đó [taskId] khác null).
@immutable
class ScheduleItem {
  final int? id;
  final DateTime date;
  final ClockTime? time;
  final String content;
  final int? taskId;
  final bool remind;
  final bool confirmed;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;

  ScheduleItem({
    this.id,
    required DateTime date,
    this.time,
    required this.content,
    this.taskId,
    this.remind = true,
    this.confirmed = false,
    this.lastNotifiedAt,
    DateTime? createdAt,
  })  : date = date.dateOnly,
        createdAt = createdAt ?? DateTime.now();

  bool get isFromTask => taskId != null;
  bool get isAllDay => time == null;

  /// Giờ thực tế sẽ nhắc: giờ đã đặt, hoặc giờ đầu ngày trong cấu hình.
  ClockTime effectiveTime(ClockTime dayStart) => time ?? dayStart;

  DateTime dueAt(ClockTime dayStart) => effectiveTime(dayStart).onDate(date);

  ScheduleItem copyWith({
    DateTime? date,
    ClockTime? time,
    bool clearTime = false,
    String? content,
    bool? remind,
    bool? confirmed,
    DateTime? lastNotifiedAt,
    bool clearLastNotified = false,
  }) =>
      ScheduleItem(
        id: id,
        date: date ?? this.date,
        time: clearTime ? null : (time ?? this.time),
        content: content ?? this.content,
        taskId: taskId,
        remind: remind ?? this.remind,
        confirmed: confirmed ?? this.confirmed,
        lastNotifiedAt:
            clearLastNotified ? null : (lastNotifiedAt ?? this.lastNotifiedAt),
        createdAt: createdAt,
      );
}
