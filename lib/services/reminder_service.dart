import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import '../core/clock_time.dart';
import '../core/date_x.dart';
import '../data/repositories/repositories.dart';
import '../domain/enums.dart';
import '../domain/models/attendance.dart';
import '../domain/models/reminder.dart';
import 'duration_text.dart';
import 'l10n.dart';
import 'notification_center.dart';
import 'nudge_service.dart';

/// Vòng lặp nhắc lịch kiểu báo thức, tách hẳn khỏi widget.
///
/// Nhiệm vụ: cứ [_tickInterval] một lần thì hỏi repository xem có gì đến hạn,
/// bắn thông báo hệ thống, ghi nhận đã nhắc, rồi phát ra danh sách cho UI
/// hiển thị thêm nếu muốn.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const Duration _tickInterval = Duration(seconds: 30);

  static const NudgeService _nudges = NudgeService();

  Timer? _timer;

  /// Nhật ký chạy, để màn hình Chẩn đoán biết vòng lặp có sống không.
  /// Trước đây lỗi bị nuốt nên hỏng là im hẳn, không có manh mối nào.
  DateTime? lastRunAt;
  DateTime? lastFiredAt;
  int lastFiredCount = 0;
  String? lastError;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    unawaited(_nudges.prime().then((_) => _nudges.refreshIfStale()));
    unawaited(_check());
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(_check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final settings = await Repos.settings.reminderSettings();
      final scheduleCount =
          await _checkSchedules(settings.nagInterval.inMinutes);
      final attendanceCount =
          await _checkAttendance(settings.nagInterval.inMinutes);

      lastRunAt = DateTime.now();
      lastError = null;
      final fired = scheduleCount + attendanceCount;
      if (fired > 0) {
        lastFiredAt = lastRunAt;
        lastFiredCount = fired;
      }
    } on Object catch (error, stack) {
      // Ghi lại thay vì để lỗi biến mất — một tick hỏng không được làm câm
      // toàn bộ tính năng nhắc.
      lastRunAt = DateTime.now();
      lastError = '$error';
      assert(() {
        debugPrint('ReminderService tick failed: $error\n$stack');
        return true;
      }());
    }
  }

  /// Bắn thử đúng thông báo chấm công thật (cùng câu nhắc, cùng kênh) để
  /// kiểm tra toàn tuyến mà không phải ngồi đợi tới giờ.
  Future<String?> sendAttendancePreview(
      AttendanceKind kind, NudgeService nudges) async {
    try {
      final settings = await Repos.settings.reminderSettings();
      final line = nudges.attendanceLine(kind, -1);
      LocalNotification(
        title: L10n.t('attendance_notif_title'),
        body: '$line\n${L10n.t(kind.l10nKey)}\n'
            '${L10n.t2('notif_repeat', {'n': '${settings.nagInterval.inMinutes}'})}',
      ).show();
      return null;
    } on Object catch (error) {
      return '$error';
    }
  }

  /// Bắn một thông báo thử để kiểm tra kênh thông báo của Windows.
  Future<String?> sendTestNotification() async {
    try {
      LocalNotification(
        title: L10n.t('diag_test_title'),
        body: L10n.t('diag_test_body'),
      ).show();
      return null;
    } on Object catch (error) {
      return '$error';
    }
  }

  Future<int> _checkSchedules(int nagMinutes) async {
    final due = await Repos.schedules.dueReminders();
    if (due.isEmpty) return 0;

    for (final reminder in due) {
      _notify(reminder, nagMinutes);
      NotificationCenter.instance.push(
        kind: NotificationKind.schedule,
        title: reminder.item.content,
        body: L10n.t2('notif_due_at', {'t': formatTime(reminder.dueAt)}),
        targetTab: AppTab.schedule,
      );
      final id = reminder.item.id;
      if (id != null) await Repos.schedules.markNotified(id);
    }
    return due.length;
  }

  Future<int> _checkAttendance(int nagMinutes) async {
    final due = await Repos.attendance.dueReminders();
    for (final slot in due) {
      await _notifyAttendance(slot, nagMinutes);
      NotificationCenter.instance.push(
        kind: NotificationKind.attendance,
        title: L10n.t(slot.kind.l10nKey),
        body: L10n.t2('notif_due_at', {'t': formatTime(slot.dueAt)}),
        targetTab: AppTab.attendance,
      );
      await Repos.attendance.markNotified(slot.dueAt, slot.kind);
    }
    return due.length;
  }

  Future<void> _notifyAttendance(AttendanceSlot slot, int nagMinutes) async {
    final minutesLeft = slot.dueAt.difference(DateTime.now()).inMinutes;
    final line = _nudges.attendanceLine(slot.kind, minutesLeft);
    final time = ClockTime.fromDateTime(slot.dueAt).format();
    final repeat = L10n.t2('notif_repeat', {'n': '$nagMinutes'});

    LocalNotification(
      title: L10n.t('attendance_notif_title'),
      body: '$line\n$time — ${L10n.t(slot.kind.l10nKey)}\n$repeat',
    ).show();
  }

  void _notify(DueReminder reminder, int nagMinutes) {
    final item = reminder.item;
    final headline = switch (reminder.stage) {
      ReminderStage.early => L10n.t2(
          'notif_early', {'d': formatHumanDuration(reminder.timeLeft)}),
      ReminderStage.due => L10n.t('notif_now'),
      ReminderStage.overdue => L10n.t2(
          'notif_overdue', {'d': formatHumanDuration(reminder.overdueBy)}),
    };

    LocalNotification(
      title: item.isFromTask
          ? L10n.t('notif_title_deadline')
          : L10n.t('notif_title_schedule'),
      body: '$headline\n'
          '${formatTime(reminder.dueAt)} — ${item.content}\n'
          '${L10n.t2('notif_repeat', {'n': '$nagMinutes'})}',
    ).show();
  }

  void dispose() => stop();
}
