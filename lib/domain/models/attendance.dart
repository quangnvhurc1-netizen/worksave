import 'package:meta/meta.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../enums.dart';

/// Lịch nhắc chấm công lặp hằng tuần (ví dụ 07:30 vào, 17:00 ra, T2–T6).
@immutable
class AttendanceRule {
  final int? id;
  final AttendanceKind kind;
  final ClockTime time;

  /// Các thứ áp dụng, theo quy ước [DateTime.monday] = 1 … [DateTime.sunday] = 7.
  final Set<int> weekdays;
  final bool enabled;

  const AttendanceRule({
    this.id,
    required this.kind,
    required this.time,
    required this.weekdays,
    this.enabled = false,
  });

  static const Set<int> workWeek = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  bool appliesTo(DateTime date) => enabled && weekdays.contains(date.weekday);

  AttendanceRule copyWith({
    ClockTime? time,
    Set<int>? weekdays,
    bool? enabled,
  }) =>
      AttendanceRule(
        id: id,
        kind: kind,
        time: time ?? this.time,
        weekdays: weekdays ?? this.weekdays,
        enabled: enabled ?? this.enabled,
      );
}

/// Ngoại lệ cho một ngày cụ thể — dùng cho hôm OT hoặc hôm nghỉ.
///
/// [time] null nghĩa là "hôm đó không nhắc" (nghỉ phép, đi công tác).
@immutable
class AttendanceOverride {
  final int? id;
  final DateTime date;
  final AttendanceKind kind;
  final ClockTime? time;
  final String note;

  AttendanceOverride({
    this.id,
    required DateTime date,
    required this.kind,
    this.time,
    this.note = '',
  }) : date = date.dateOnly;

  bool get skipsReminder => time == null;
}

/// Một lần nhắc chấm công đã tính xong giờ và trạng thái cho ngày đang xét.
@immutable
class AttendanceSlot {
  final AttendanceKind kind;
  final DateTime dueAt;
  final bool confirmed;
  final bool isOverride;
  final String note;

  const AttendanceSlot({
    required this.kind,
    required this.dueAt,
    required this.confirmed,
    required this.isOverride,
    this.note = '',
  });
}
