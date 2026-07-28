/// Toàn bộ khóa của bảng `settings` — gom một chỗ để không rải chuỗi rời rạc.
abstract final class SettingKeys {
  static const String language = 'language';
  static const String tabOrder = 'tab_order';

  // Nhắc lịch
  static const String dayStartTime = 'day_start_time';
  static const String leadMinutes = 'lead_minutes';
  static const String nagMinutes = 'nag_minutes';

  // Review cuối ngày
  static const String reviewTime = 'review_time';
  static const String reviewDate = 'review_date';

  // Pomodoro
  static const String pomodoroFocus = 'pomo_focus';
  static const String pomodoroShortBreak = 'pomo_short';
  static const String pomodoroLongBreak = 'pomo_long';
  static const String pomodoroCycles = 'pomo_cycles';

  // Gemini
  static const String geminiApiKey = 'gemini_api_key';
  static const String geminiModel = 'gemini_model';
  static const String fridaySummaryDate = 'friday_summary_date';
  static const String fridaySummaryText = 'friday_summary_text';
}
