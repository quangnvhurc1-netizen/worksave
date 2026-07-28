import 'package:meta/meta.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';

/// Hạn chót: một ngày, có thể kèm giờ cụ thể.
///
/// Tách [time] thành trường riêng thay vì suy từ `hour == 0`, nên deadline
/// đúng 00:00 vẫn là "có giờ" chứ không bị hiểu nhầm thành cả ngày.
@immutable
class Deadline {
  final DateTime date;
  final ClockTime? time;

  Deadline({required DateTime date, this.time}) : date = date.dateOnly;

  bool get isAllDay => time == null;

  /// Mốc tuyệt đối; việc cả ngày dùng [fallback] (giờ đầu ngày trong cấu hình).
  DateTime dueAt(ClockTime fallback) => (time ?? fallback).onDate(date);

  Deadline copyWith({DateTime? date, ClockTime? time, bool clearTime = false}) =>
      Deadline(
        date: date ?? this.date,
        time: clearTime ? null : (time ?? this.time),
      );

  static Deadline? fromDb(String? date, String? time) {
    if (date == null || date.isEmpty) return null;
    return Deadline(date: parseIsoDate(date), time: ClockTime.tryParse(time));
  }

  String get dbDate => date.toIsoDate();
  String? get dbTime => time?.format();

  @override
  bool operator ==(Object other) =>
      other is Deadline && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);
}
