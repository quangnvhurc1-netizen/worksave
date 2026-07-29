import 'package:flutter/material.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/attendance.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../../services/nudge_service.dart';
import '../../services/reminder_service.dart';
import '../dialogs/attendance_override_dialog.dart';
import '../theme.dart';

/// Nhắc chấm công: giờ lặp hằng tuần + ngoại lệ cho ngày cụ thể (OT / nghỉ).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceRule> _rules = const [];
  List<AttendanceSlot> _todaySlots = const [];
  List<AttendanceOverride> _overrides = const [];
  final Map<AttendanceKind, DateTime?> _nextReminders = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await Repos.attendance.rules();
    final slots = await Repos.attendance.slotsOn(DateTime.now());
    final overrides = await Repos.attendance.upcomingOverrides();

    final next = <AttendanceKind, DateTime?>{};
    for (final rule in rules) {
      next[rule.kind] = await Repos.attendance.nextReminderFor(rule);
    }

    if (!mounted) return;
    setState(() {
      _rules = rules;
      _todaySlots = slots;
      _overrides = overrides;
      _nextReminders
        ..clear()
        ..addAll(next);
    });
  }

  AttendanceRule _ruleFor(AttendanceKind kind) => _rules.firstWhere(
        (r) => r.kind == kind,
        orElse: () => AttendanceRule(
          kind: kind,
          time: kind == AttendanceKind.checkIn
              ? const ClockTime(7, 30)
              : const ClockTime(17, 0),
          weekdays: AttendanceRule.workWeek,
        ),
      );

  Future<void> _saveRule(AttendanceRule rule) async {
    await Repos.attendance.saveRuleAndResetToday(rule);
    await _load();
  }

  Future<void> _pickRuleTime(AttendanceRule rule) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: rule.time.hour, minute: rule.time.minute),
      helpText: L10n.t(rule.kind.l10nKey),
    );
    if (picked == null) return;
    await _saveRule(rule.copyWith(time: ClockTime(picked.hour, picked.minute)));
  }

  Future<void> _confirmSlot(AttendanceSlot slot) =>
      _setConfirmed(slot.kind, confirmed: !slot.confirmed);

  Future<void> _setConfirmed(
    AttendanceKind kind, {
    required bool confirmed,
  }) async {
    await Repos.attendance
        .setConfirmed(DateTime.now(), kind, confirmed: confirmed);
    if (confirmed) {
      Celebration.instance
          .fire(L10n.t2('praise_attendance', {'k': L10n.t(kind.l10nKey)}));
    }
    await _load();
  }

  /// Mốc hôm nay của loại này đang chờ xác nhận hay không — quyết định có
  /// hiện nút "Đã chấm công" ngay tại thẻ cấu hình.
  bool _isPendingToday(AttendanceKind kind) => _todaySlots.any(
        (slot) => slot.kind == kind && !slot.confirmed,
      );

  /// Bắn thử đúng thông báo thật (cùng câu, cùng kênh) để kiểm tra end-to-end.
  Future<void> _testNudge(AttendanceKind kind) async {
    final error = await ReminderService.instance
        .sendAttendancePreview(kind, const NudgeService());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? L10n.t('diag_test_sent')
          : L10n.t2('diag_test_failed', {'e': error})),
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _openOverrideDialog([AttendanceOverride? existing]) async {
    final result = await showDialog<AttendanceOverride>(
      context: context,
      builder: (_) => AttendanceOverrideDialog(existing: existing),
    );
    if (result == null) return;
    await Repos.attendance.saveOverride(result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOverrideDialog(),
        icon: const Icon(Icons.more_time),
        label: Text(L10n.t('attendance_add_override')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
        children: [
          ScreenTitle(L10n.t('attendance_title')),
          const SizedBox(height: AppSpacing.xs),
          ScreenHint(L10n.t('attendance_hint')),
          const SizedBox(height: AppSpacing.lg),
          _buildTodayCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(L10n.t('attendance_daily_section'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          for (final kind in AttendanceKind.values)
            _RuleCard(
              rule: _ruleFor(kind),
              nextReminderAt: _nextReminders[kind],
              onTest: () => _testNudge(kind),
              onConfirmToday: _isPendingToday(kind)
                  ? () => _setConfirmed(kind, confirmed: true)
                  : null,
              onToggle: (enabled) =>
                  _saveRule(_ruleFor(kind).copyWith(enabled: enabled)),
              onPickTime: () => _pickRuleTime(_ruleFor(kind)),
              onToggleWeekday: (weekday) {
                final rule = _ruleFor(kind);
                final days = Set<int>.of(rule.weekdays);
                if (!days.remove(weekday)) days.add(weekday);
                return _saveRule(rule.copyWith(weekdays: days));
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(L10n.t('attendance_override_section'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          ScreenHint(L10n.t('attendance_override_hint')),
          const SizedBox(height: AppSpacing.sm),
          if (_overrides.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(L10n.t('attendance_no_override'),
                  style: const TextStyle(color: Colors.black54)),
            )
          else
            for (final item in _overrides)
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    item.skipsReminder ? Icons.notifications_off : Icons.more_time,
                    color: item.skipsReminder
                        ? Colors.black38
                        : AppColors.primary,
                  ),
                  title: Text('${formatDate(item.date)} · '
                      '${L10n.t(item.kind.l10nKey)} · '
                      '${item.time?.format() ?? L10n.t('attendance_skip')}'),
                  subtitle: item.note.isEmpty ? null : Text(item.note),
                  onTap: () => _openOverrideDialog(item),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      final id = item.id;
                      if (id == null) return;
                      await Repos.attendance.deleteOverride(id);
                      await _load();
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    return Card(
      color: AppColors.panelSurface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${L10n.t('attendance_today')} — ${formatDate(DateTime.now())}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_todaySlots.isEmpty)
              Text(L10n.t('attendance_none_today'),
                  style: const TextStyle(color: Colors.black54))
            else
              for (final slot in _todaySlots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: IconButton(
                    tooltip: slot.confirmed
                        ? L10n.t('attendance_undo')
                        : L10n.t('attendance_confirm'),
                    icon: Icon(
                      slot.confirmed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: slot.confirmed
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    onPressed: () => _confirmSlot(slot),
                  ),
                  title: Text(
                    '${ClockTime.fromDateTime(slot.dueAt).format()} · '
                    '${L10n.t(slot.kind.l10nKey)}'
                    '${slot.isOverride ? ' (${L10n.t('attendance_ot_tag')})' : ''}',
                    style: TextStyle(
                      decoration: slot.confirmed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    slot.confirmed
                        ? L10n.t('attendance_done')
                        : L10n.t('attendance_pending'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ cấu hình một mốc chấm công lặp hằng tuần.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.nextReminderAt,
    required this.onTest,
    required this.onConfirmToday,
    required this.onToggle,
    required this.onPickTime,
    required this.onToggleWeekday,
  });

  final AttendanceRule rule;
  final DateTime? nextReminderAt;
  final VoidCallback onTest;

  /// Null khi mốc hôm nay không còn chờ xác nhận.
  final VoidCallback? onConfirmToday;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final Future<void> Function(int weekday) onToggleWeekday;

  static const List<String> _weekdayLabels = [
    'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN',
  ];

  /// Nói thẳng vì sao mốc này sẽ (hoặc sẽ không) nhắc — nếu không thì việc
  /// quên bật công tắc trông y hệt lỗi của app.
  Widget _buildStatusLine() {
    if (!rule.enabled) {
      return Text(L10n.t('attendance_status_off'),
          style: const TextStyle(color: AppColors.danger, fontSize: 12));
    }
    if (rule.weekdays.isEmpty) {
      return Text(L10n.t('attendance_status_no_weekday'),
          style: const TextStyle(color: AppColors.danger, fontSize: 12));
    }
    final next = nextReminderAt;
    if (next == null) {
      return Text(L10n.t('attendance_status_none'),
          style: const TextStyle(color: AppColors.danger, fontSize: 12));
    }
    if (next.isBefore(DateTime.now())) {
      // Cửa sổ nhắc của hôm nay đã mở và mốc chưa được xác nhận.
      return Text(
        L10n.t2('attendance_status_active', {'t': formatTime(next)}),
        style: const TextStyle(
            color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
      );
    }
    return Text(
      L10n.t2('attendance_status_next', {'t': formatDateTime(next)}),
      style: const TextStyle(color: AppColors.success, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  rule.kind == AttendanceKind.checkIn
                      ? Icons.login
                      : Icons.logout,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(L10n.t(rule.kind.l10nKey),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(rule.time.format()),
                  onPressed: onPickTime,
                ),
                const Spacer(),
                Switch(value: rule.enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  FilterChip(
                    label: Text(_weekdayLabels[weekday - 1]),
                    selected: rule.weekdays.contains(weekday),
                    onSelected: (_) => onToggleWeekday(weekday),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _buildStatusLine()),
                if (onConfirmToday != null)
                  FilledButton.icon(
                    onPressed: onConfirmToday,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(L10n.t('attendance_confirm_short')),
                  ),
                TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.notifications_active, size: 16),
                  label: Text(L10n.t('attendance_test_btn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
