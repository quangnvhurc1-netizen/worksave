/// Các kiểu liệt kê của miền nghiệp vụ. Mỗi enum tự biết cách map với DB
/// và với khóa dịch, nên UI/DAO không cần biết chuỗi thô.

enum TaskStatus {
  todo('todo', 'status_todo'),
  doing('doing', 'status_doing'),
  done('done', 'status_done');

  const TaskStatus(this.dbValue, this.l10nKey);
  final String dbValue;
  final String l10nKey;

  static TaskStatus fromDb(String? raw) => TaskStatus.values.firstWhere(
        (e) => e.dbValue == raw,
        orElse: () => TaskStatus.todo,
      );

  bool get isDone => this == TaskStatus.done;

  /// Vòng trạng thái khi bấm vào icon: chưa làm -> đang làm -> xong -> chưa làm.
  TaskStatus get next => switch (this) {
        TaskStatus.todo => TaskStatus.doing,
        TaskStatus.doing => TaskStatus.done,
        TaskStatus.done => TaskStatus.todo,
      };
}

enum PomodoroPhase {
  focus('phase_focus'),
  shortBreak('phase_short'),
  longBreak('phase_long');

  const PomodoroPhase(this.l10nKey);
  final String l10nKey;

  bool get isFocus => this == PomodoroPhase.focus;
}

/// Trạng thái của một lời nhắc so với mốc tới hạn.
enum ReminderStage { early, due, overdue }

enum SearchHitKind {
  task('Task'),
  workLog('Log'),
  idea('tab_ideas'),
  journal('tab_journal'),
  checkpoint('tab_saves'),
  schedule('tab_schedule');

  const SearchHitKind(this.label);

  /// Nhãn hiển thị: với 4 loại cuối là khóa dịch, 2 loại đầu là chữ cố định.
  final String label;
  bool get isL10nKey => label.startsWith('tab_');
}

enum AppLanguage {
  vi('vi'),
  en('en');

  const AppLanguage(this.code);
  final String code;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((e) => e.code == code,
          orElse: () => AppLanguage.vi);
}

enum QuickCaptureTarget { journal, idea }

/// Các tab của app. Thứ tự hiển thị do người dùng cấu hình, nhưng id thì cố định.
enum AppTab {
  tasks('tasks'),
  pomodoro('pomodoro'),
  saves('saves'),
  ideas('ideas'),
  journal('journal'),
  schedule('schedule'),
  report('report');

  const AppTab(this.id);
  final String id;

  String get l10nKey => 'tab_$id';

  static AppTab? tryFromId(String id) {
    for (final tab in AppTab.values) {
      if (tab.id == id) return tab;
    }
    return null;
  }
}
