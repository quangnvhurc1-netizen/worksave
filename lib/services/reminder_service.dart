import 'dart:async';

import 'package:local_notifier/local_notifier.dart';

import '../core/date_x.dart';
import '../data/repositories/repositories.dart';
import '../domain/enums.dart';
import '../core/clock_time.dart';
import '../domain/models/attendance.dart';
import '../domain/models/reminder.dart';
import 'l10n.dart';

/// Vòng lặp nhắc lịch kiểu báo thức, tách hẳn khỏi widget.
///
/// Nhiệm vụ: cứ [_tickInterval] một lần thì hỏi repository xem có gì đến hạn,
/// bắn thông báo hệ thống, ghi nhận đã nhắc, rồi phát ra danh sách cho UI
/// hiển thị thêm nếu muốn.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const Duration _tickInterval = Duration(seconds: 30);

  final StreamController<List<DueReminder>> _controller =
      StreamController<List<DueReminder>>.broadcast();
  Timer? _timer;

  /// UI lắng nghe để hiện snackbar; không bắt buộc phải nghe.
  Stream<List<DueReminder>> get onRemindersFired => _controller.stream;

  void start() {
    if (_timer != null) return;
    unawaited(_check());
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(_check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    final settings = await Repos.settings.reminderSettings();
    await _checkSchedules(settings.nagInterval.inMinutes);
    await _checkAttendance(settings.nagInterval.inMinutes);
  }

  Future<void> _checkSchedules(int nagMinutes) async {
    final due = await Repos.schedules.dueReminders();
    if (due.isEmpty) return;

    for (final reminder in due) {
      _notify(reminder, nagMinutes);
      final id = reminder.item.id;
      if (id != null) await Repos.schedules.markNotified(id);
    }
    if (!_controller.isClosed) _controller.add(due);
  }

  Future<void> _checkAttendance(int nagMinutes) async {
    final due = await Repos.attendance.dueReminders();
    for (final slot in due) {
      _notifyAttendance(slot, nagMinutes);
      await Repos.attendance.markNotified(slot.dueAt, slot.kind);
    }
  }

  void _notifyAttendance(AttendanceSlot slot, int nagMinutes) {
    final minutesLeft = slot.dueAt.difference(DateTime.now()).inMinutes;
    final String headline;
    if (minutesLeft > 0) {
      headline = L10n.t2('notif_early', {'n': '$minutesLeft'});
    } else if (minutesLeft < 0) {
      headline = L10n.t2('notif_overdue', {'n': '${-minutesLeft}'});
    } else {
      headline = L10n.t('notif_now');
    }

    final time = ClockTime.fromDateTime(slot.dueAt).format();
    final what = L10n.t(slot.kind.l10nKey);
    final repeat = L10n.t2('notif_repeat', {'n': '$nagMinutes'});

    LocalNotification(
      title: L10n.t('attendance_notif_title'),
      body: '$headline\n$time — $what\n$repeat',
    ).show();
  }

  void _notify(DueReminder reminder, int nagMinutes) {
    final item = reminder.item;
    final headline = switch (reminder.stage) {
      ReminderStage.early =>
        L10n.t2('notif_early', {'n': '${reminder.minutesEarly}'}),
      ReminderStage.due => L10n.t('notif_now'),
      ReminderStage.overdue =>
        L10n.t2('notif_overdue', {'n': '${reminder.minutesLate}'}),
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

  void dispose() {
    stop();
    _controller.close();
  }
}
