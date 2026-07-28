/// Tiện ích ngày tháng dùng chung. Không phụ thuộc Flutter.
extension DateTimeX on DateTime {
  /// Bỏ phần giờ, giữ lại ngày.
  DateTime get dateOnly => DateTime(year, month, day);

  /// 'yyyy-MM-dd' — định dạng lưu DB (sắp xếp được bằng so sánh chuỗi).
  String toIsoDate() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Thứ 2 của tuần chứa ngày này.
  DateTime get mondayOfWeek =>
      subtract(Duration(days: weekday - DateTime.monday)).dateOnly;
}

/// 'dd/MM/yyyy'
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// 'HH:mm'
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// 'dd/MM/yyyy HH:mm'
String formatDateTime(DateTime d) => '${formatDate(d)} ${formatTime(d)}';

DateTime parseIsoDate(String value) => DateTime.parse(value);
