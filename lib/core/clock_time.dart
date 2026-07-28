import 'package:meta/meta.dart';

/// Giờ-phút trong ngày, độc lập với Flutter (domain không phụ thuộc UI).
@immutable
class ClockTime implements Comparable<ClockTime> {
  final int hour;
  final int minute;

  const ClockTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  static const ClockTime midnight = ClockTime(0, 0);

  /// Parse 'HH:mm'. Trả về null nếu chuỗi không hợp lệ.
  static ClockTime? tryParse(String? raw) {
    if (raw == null) return null;
    final parts = raw.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return ClockTime(h, m);
  }

  static ClockTime fromDateTime(DateTime d) => ClockTime(d.hour, d.minute);

  /// Ghép với một ngày để ra mốc thời gian tuyệt đối.
  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ClockTime other) => hour != other.hour
      ? hour.compareTo(other.hour)
      : minute.compareTo(other.minute);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}
