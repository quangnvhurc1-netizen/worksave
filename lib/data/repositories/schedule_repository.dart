import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/schedule_item.dart';
import '../dao/schedule_dao.dart';
import 'settings_repository.dart';

/// Nghiệp vụ quanh lịch và luật nhắc kiểu báo thức.
class ScheduleRepository {
  const ScheduleRepository({
    ScheduleDao dao = const ScheduleDao(),
    SettingsRepository settings = const SettingsRepository(),
  })  : _dao = dao,
        _settings = settings;

  final ScheduleDao _dao;
  final SettingsRepository _settings;

  Future<List<ScheduleItem>> all() => _dao.findAll();

  Future<void> add(ScheduleItem item) => _dao.insert(item);
  Future<void> update(ScheduleItem item) => _dao.update(item);
  Future<void> delete(int id) => _dao.delete(id);

  Future<List<ScheduleItem>> onDate(DateTime date, ClockTime dayStart) async {
    final all = await _dao.findAll();
    return all.where((s) => s.date.isSameDay(date)).toList()
      ..sort((a, b) => a.dueAt(dayStart).compareTo(b.dueAt(dayStart)));
  }

  /// Xác nhận xong / bỏ xác nhận một mục.
  Future<void> setConfirmed(int id, {required bool confirmed}) => _dao
      .setFields(id, {'confirmed': confirmed ? 1 : 0, 'last_notified_at': null});

  /// Bật / tắt nhắc cho một mục.
  Future<void> setRemind(int id, {required bool remind}) =>
      _dao.setFields(id, {'remind': remind ? 1 : 0, 'last_notified_at': null});

  /// Đồng bộ trạng thái xác nhận cho mục sinh từ task (khi task Done/mở lại).
  Future<void> setConfirmedForTask(int taskId, {required bool confirmed}) =>
      _dao.setFieldsByTask(
          taskId, {'confirmed': confirmed ? 1 : 0, 'last_notified_at': null});

  Future<void> markNotified(int id) => _dao
      .setFields(id, {'last_notified_at': DateTime.now().toIso8601String()});

  /// Những mục cần bắn thông báo ngay lúc [now].
  ///
  /// Luật: bắt đầu nhắc trước mốc [ReminderSettings.leadTime], sau đó lặp lại
  /// mỗi [ReminderSettings.nagInterval] cho tới khi được xác nhận xong.
  Future<List<DueReminder>> dueReminders({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settings = await _settings.reminderSettings();

    // Lấy cả ngày mai để còn báo trước qua nửa đêm (vd mục hẹn 00:05).
    final pending =
        await _dao.findPendingUpTo(at.add(const Duration(days: 1)));

    final result = <DueReminder>[];
    for (final item in pending) {
      final dueAt = item.dueAt(settings.dayStart);
      if (at.isBefore(dueAt.subtract(settings.leadTime))) continue;

      final last = item.lastNotifiedAt;
      if (last != null && at.difference(last) < settings.nagInterval) continue;

      result.add(DueReminder(
        item: item,
        dueAt: dueAt,
        remaining: dueAt.difference(at),
      ));
    }
    return result;
  }
}
