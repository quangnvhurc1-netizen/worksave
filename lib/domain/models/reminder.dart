import 'package:meta/meta.dart';

import '../enums.dart';
import 'schedule_item.dart';

/// Một mục đến lúc cần bắn thông báo, kèm ngữ cảnh thời gian đã tính sẵn.
@immutable
class DueReminder {
  final ScheduleItem item;
  final DateTime dueAt;
  final Duration remaining;

  const DueReminder({
    required this.item,
    required this.dueAt,
    required this.remaining,
  });

  ReminderStage get stage {
    final minutes = remaining.inMinutes;
    if (minutes > 0) return ReminderStage.early;
    if (minutes < 0) return ReminderStage.overdue;
    return ReminderStage.due;
  }

  int get minutesEarly => remaining.inMinutes;
  int get minutesLate => -remaining.inMinutes;
}
