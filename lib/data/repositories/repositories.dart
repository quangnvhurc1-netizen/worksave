/// Điểm truy cập duy nhất tới tầng dữ liệu, để UI chỉ cần import một file
/// và có thể thay bằng bản giả khi viết test.
library;

import 'backup_repository.dart';
import 'note_repository.dart';
import 'pomodoro_repository.dart';
import 'schedule_repository.dart';
import 'search_repository.dart';
import 'settings_repository.dart';
import 'task_repository.dart';

export 'backup_repository.dart';
export 'note_repository.dart';
export 'pomodoro_repository.dart';
export 'schedule_repository.dart';
export 'search_repository.dart';
export 'settings_repository.dart';
export 'task_repository.dart';

class Repos {
  const Repos._();

  static TaskRepository tasks = const TaskRepository();
  static ScheduleRepository schedules = const ScheduleRepository();
  static NoteRepository notes = const NoteRepository();
  static PomodoroRepository pomodoro = const PomodoroRepository();
  static SettingsRepository settings = const SettingsRepository();
  static SearchRepository search = const SearchRepository();
  static BackupRepository backup = const BackupRepository();
}
