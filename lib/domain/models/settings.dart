import 'package:meta/meta.dart';

import '../../core/clock_time.dart';

/// Cấu hình cách nhắc lịch.
@immutable
class ReminderSettings {
  final ClockTime dayStart;
  final Duration leadTime;
  final Duration nagInterval;

  const ReminderSettings({
    required this.dayStart,
    required this.leadTime,
    required this.nagInterval,
  });

  static const ReminderSettings defaults = ReminderSettings(
    dayStart: ClockTime(8, 0),
    leadTime: Duration(minutes: 10),
    nagInterval: Duration(minutes: 10),
  );

  ReminderSettings copyWith({
    ClockTime? dayStart,
    Duration? leadTime,
    Duration? nagInterval,
  }) =>
      ReminderSettings(
        dayStart: dayStart ?? this.dayStart,
        leadTime: leadTime ?? this.leadTime,
        nagInterval: nagInterval ?? this.nagInterval,
      );
}

/// Cấu hình đồng hồ Pomodoro.
@immutable
class PomodoroSettings {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;

  const PomodoroSettings({
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.cyclesBeforeLongBreak,
  });

  static const PomodoroSettings defaults = PomodoroSettings(
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    cyclesBeforeLongBreak: 4,
  );

  PomodoroSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
  }) =>
      PomodoroSettings(
        focusMinutes: focusMinutes ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        cyclesBeforeLongBreak:
            cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      );
}
