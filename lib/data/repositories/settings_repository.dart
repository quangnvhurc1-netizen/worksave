import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../core/setting_keys.dart';
import '../../domain/enums.dart';
import '../../domain/models/settings.dart';
import '../dao/settings_dao.dart';

/// Đọc/ghi cấu hình với kiểu dữ liệu đàng hoàng thay vì chuỗi thô.
class SettingsRepository {
  const SettingsRepository({SettingsDao dao = const SettingsDao()})
      : _dao = dao;
  final SettingsDao _dao;

  Future<String?> _read(String key) => _dao.read(key);
  Future<void> _write(String key, String value) => _dao.write(key, value);

  // ---- Nhắc lịch ----
  Future<ReminderSettings> reminderSettings() async {
    const fallback = ReminderSettings.defaults;
    return ReminderSettings(
      dayStart: ClockTime.tryParse(await _read(SettingKeys.dayStartTime)) ??
          fallback.dayStart,
      leadTime: Duration(
          minutes: int.tryParse(await _read(SettingKeys.leadMinutes) ?? '') ??
              fallback.leadTime.inMinutes),
      nagInterval: Duration(
          minutes: int.tryParse(await _read(SettingKeys.nagMinutes) ?? '') ??
              fallback.nagInterval.inMinutes),
    );
  }

  Future<void> saveReminderSettings(ReminderSettings s) async {
    await _write(SettingKeys.dayStartTime, s.dayStart.format());
    await _write(SettingKeys.leadMinutes, '${s.leadTime.inMinutes}');
    await _write(SettingKeys.nagMinutes, '${s.nagInterval.inMinutes}');
  }

  // ---- Pomodoro ----
  Future<PomodoroSettings> pomodoroSettings() async {
    const fallback = PomodoroSettings.defaults;
    Future<int> readInt(String key, int def) async =>
        int.tryParse(await _read(key) ?? '') ?? def;
    return PomodoroSettings(
      focusMinutes:
          await readInt(SettingKeys.pomodoroFocus, fallback.focusMinutes),
      shortBreakMinutes: await readInt(
          SettingKeys.pomodoroShortBreak, fallback.shortBreakMinutes),
      longBreakMinutes: await readInt(
          SettingKeys.pomodoroLongBreak, fallback.longBreakMinutes),
      cyclesBeforeLongBreak: await readInt(
          SettingKeys.pomodoroCycles, fallback.cyclesBeforeLongBreak),
    );
  }

  Future<void> savePomodoroSettings(PomodoroSettings s) async {
    await _write(SettingKeys.pomodoroFocus, '${s.focusMinutes}');
    await _write(SettingKeys.pomodoroShortBreak, '${s.shortBreakMinutes}');
    await _write(SettingKeys.pomodoroLongBreak, '${s.longBreakMinutes}');
    await _write(SettingKeys.pomodoroCycles, '${s.cyclesBeforeLongBreak}');
  }

  // ---- Review cuối ngày ----
  Future<ClockTime> reviewTime() async =>
      ClockTime.tryParse(await _read(SettingKeys.reviewTime)) ??
      const ClockTime(16, 30);

  Future<void> saveReviewTime(ClockTime time) =>
      _write(SettingKeys.reviewTime, time.format());

  Future<bool> isReviewDoneToday() async =>
      await _read(SettingKeys.reviewDate) == DateTime.now().toIsoDate();

  Future<void> markReviewDoneToday() =>
      _write(SettingKeys.reviewDate, DateTime.now().toIsoDate());

  // ---- Ngôn ngữ & tab ----
  Future<AppLanguage> language() async =>
      AppLanguage.fromCode(await _read(SettingKeys.language));

  Future<void> saveLanguage(AppLanguage lang) =>
      _write(SettingKeys.language, lang.code);

  Future<List<AppTab>> tabOrder() async {
    final raw = await _read(SettingKeys.tabOrder);
    if (raw == null || raw.trim().isEmpty) return AppTab.values;
    final saved = raw
        .split(',')
        .map((id) => AppTab.tryFromId(id.trim()))
        .whereType<AppTab>()
        .toList();
    // Bổ sung tab mới xuất hiện sau lần lưu trước.
    for (final tab in AppTab.values) {
      if (!saved.contains(tab)) saved.add(tab);
    }
    return saved;
  }

  Future<void> saveTabOrder(List<AppTab> tabs) =>
      _write(SettingKeys.tabOrder, tabs.map((t) => t.id).join(','));

  // ---- Gemini ----
  Future<String?> geminiApiKey() => _read(SettingKeys.geminiApiKey);
  Future<void> saveGeminiApiKey(String key) =>
      _write(SettingKeys.geminiApiKey, key.trim());

  Future<String> geminiModel() async {
    final saved = (await _read(SettingKeys.geminiModel))?.trim();
    return (saved == null || saved.isEmpty) ? defaultGeminiModel : saved;
  }

  Future<void> saveGeminiModel(String model) =>
      _write(SettingKeys.geminiModel, model.trim());

  Future<({String date, String text})?> cachedFridaySummary() async {
    final date = await _read(SettingKeys.fridaySummaryDate);
    final text = await _read(SettingKeys.fridaySummaryText);
    if (date == null || text == null || text.trim().isEmpty) return null;
    return (date: date, text: text);
  }

  Future<void> saveFridaySummary(String text) async {
    await _write(SettingKeys.fridaySummaryDate, DateTime.now().toIsoDate());
    await _write(SettingKeys.fridaySummaryText, text);
  }

  Future<bool> isFridaySummaryGeneratedToday() async =>
      await _read(SettingKeys.fridaySummaryDate) == DateTime.now().toIsoDate();

  static const String defaultGeminiModel = 'gemini-2.5-flash';
  static const String fallbackGeminiModel = 'gemini-2.5-flash-lite';
}
