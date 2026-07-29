import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/attendance.dart';
import '../../domain/models/settings.dart';
import '../dao/attendance_dao.dart';
import 'settings_repository.dart';

/// Nghiệp vụ nhắc chấm công.
///
/// Luật ưu tiên cho một ngày: nếu có ngoại lệ (OT / nghỉ) thì ngoại lệ thắng;
/// không có thì dùng lịch lặp hằng tuần. Ngoại lệ không đặt giờ = hôm đó
/// không nhắc.
class AttendanceRepository {
  const AttendanceRepository({
    AttendanceDao dao = const AttendanceDao(),
    SettingsRepository settings = const SettingsRepository(),
  })  : _dao = dao,
        _settings = settings;

  final AttendanceDao _dao;
  final SettingsRepository _settings;

  Future<List<AttendanceRule>> rules() => _dao.rules();
  Future<void> saveRule(AttendanceRule rule) => _dao.upsertRule(rule);

  Future<List<AttendanceOverride>> upcomingOverrides() =>
      _dao.overridesFrom(DateTime.now().dateOnly);

  Future<void> saveOverride(AttendanceOverride item) =>
      _dao.upsertOverride(item);

  Future<void> deleteOverride(int id) => _dao.deleteOverride(id);

  Future<void> setConfirmed(
    DateTime date,
    AttendanceKind kind, {
    required bool confirmed,
  }) =>
      _dao.setConfirmed(date, kind, confirmed: confirmed);

  /// Các mốc chấm công của một ngày, đã áp dụng ngoại lệ và trạng thái.
  Future<List<AttendanceSlot>> slotsOn(DateTime date) async {
    final day = date.dateOnly;
    final rules = await _dao.rules();
    final overrides = await _dao.overridesOn(day);

    final slots = <AttendanceSlot>[];
    for (final kind in AttendanceKind.values) {
      final override =
          overrides.where((o) => o.kind == kind).firstOrNull;
      final ClockTime? time;
      final bool isOverride;

      if (override != null) {
        if (override.skipsReminder) continue; // hôm đó chủ động không nhắc
        time = override.time;
        isOverride = true;
      } else {
        final rule = rules.where((r) => r.kind == kind).firstOrNull;
        if (rule == null || !rule.appliesTo(day)) continue;
        time = rule.time;
        isOverride = false;
      }
      if (time == null) continue;

      final state = await _dao.stateOf(day, kind);
      slots.add(AttendanceSlot(
        kind: kind,
        dueAt: time.onDate(day),
        confirmed: state?['confirmed_at'] != null,
        isOverride: isOverride,
        note: override?.note ?? '',
      ));
    }
    slots.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return slots;
  }

  /// Mốc nào cần bắn thông báo ngay lúc [now]: đã tới ngưỡng báo trước,
  /// chưa xác nhận, và đã qua chu kỳ nhắc lại.
  Future<List<AttendanceSlot>> dueReminders({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final ReminderSettings settings = await _settings.reminderSettings();
    final slots = await slotsOn(at);

    final due = <AttendanceSlot>[];
    for (final slot in slots) {
      if (slot.confirmed) continue;
      if (at.isBefore(slot.dueAt.subtract(settings.leadTime))) continue;

      final state = await _dao.stateOf(at.dateOnly, slot.kind);
      final raw = state?['last_notified_at'] as String?;
      if (raw != null &&
          at.difference(parseIsoDate(raw)) < settings.nagInterval) {
        continue;
      }
      due.add(slot);
    }
    return due;
  }

  Future<void> markNotified(DateTime date, AttendanceKind kind) =>
      _dao.markNotified(date.dateOnly, kind);

  /// Lần nhắc kế tiếp của một lịch lặp: mốc tới hạn gần nhất trong 14 ngày
  /// tới, đã trừ thời gian báo trước. Null nghĩa là sẽ không bao giờ nhắc
  /// (đang tắt, hoặc không chọn thứ nào).
  Future<DateTime?> nextReminderFor(AttendanceRule rule) async {
    if (!rule.enabled || rule.weekdays.isEmpty) return null;
    final settings = await _settings.reminderSettings();
    final now = DateTime.now();

    for (var offset = 0; offset <= 14; offset++) {
      final day = now.add(Duration(days: offset)).dateOnly;
      if (!rule.weekdays.contains(day.weekday)) continue;

      // Ngoại lệ của ngày đó thắng lịch lặp.
      final overrides = await _dao.overridesOn(day);
      final override =
          overrides.where((o) => o.kind == rule.kind).firstOrNull;
      if (override != null && override.skipsReminder) continue;

      final dueAt = (override?.time ?? rule.time).onDate(day);
      final firesAt = dueAt.subtract(settings.leadTime);

      if (offset == 0) {
        // Hôm nay: mốc chưa xác nhận thì vẫn tính, kể cả đã qua giờ — nó
        // đang được nhắc lặp lại chứ không phải đã xong.
        final state = await _dao.stateOf(day, rule.kind);
        if (state?['confirmed_at'] == null) return firesAt;
        continue;
      }
      if (firesAt.isAfter(now)) return firesAt;
    }
    return null;
  }

  /// Đổi giờ của một mốc thì bỏ dấu "vừa nhắc" của hôm nay, để mốc mới được
  /// nhắc ngay thay vì phải đợi hết chu kỳ của giờ cũ.
  Future<void> saveRuleAndResetToday(AttendanceRule rule) async {
    await _dao.upsertRule(rule);
    await _dao.clearNotified(DateTime.now().dateOnly, rule.kind);
  }
}
