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
}
