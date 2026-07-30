import 'l10n.dart';

/// Diễn đạt khoảng thời gian theo cách người đọc hiểu ngay: "20 phút",
/// "3 giờ 20 phút", "2 ngày 4 giờ" — thay vì quy hết về phút.
///
/// Bỏ qua dấu, nên gọi được cho cả "còn bao lâu" và "trễ bao lâu".
String formatHumanDuration(Duration duration) {
  final total = duration.abs();

  if (total.inMinutes < 1) return L10n.t('dur_under_minute');

  if (total.inHours < 1) {
    return L10n.t2('dur_minutes', {'n': '${total.inMinutes}'});
  }

  if (total.inDays < 1) {
    final hours = L10n.t2('dur_hours', {'n': '${total.inHours}'});
    final minutes = total.inMinutes % 60;
    return minutes == 0
        ? hours
        : '$hours ${L10n.t2('dur_minutes', {'n': '$minutes'})}';
  }

  final days = L10n.t2('dur_days', {'n': '${total.inDays}'});
  final hours = total.inHours % 24;
  return hours == 0
      ? days
      : '$days ${L10n.t2('dur_hours', {'n': '$hours'})}';
}
