import 'dart:async';

import 'package:local_notifier/local_notifier.dart';

import '../core/date_x.dart';
import '../data/repositories/repositories.dart';
import '../domain/enums.dart';
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
    final due = await Repos.schedules.dueReminders();
    if (due.isEmpty) return;

    final settings = await Repos.settings.reminderSettings();
    for (final reminder in due) {
      _notify(reminder, settings.nagInterval.inMinutes);
      final id = reminder.item.id;
      if (id != null) await Repos.schedules.markNotified(id);
    }
    if (!_controller.isClosed) _controller.add(due);
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
