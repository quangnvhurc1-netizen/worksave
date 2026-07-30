import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/attendance.dart';
import '../../domain/models/schedule_item.dart';
import '../../domain/models/settings.dart';
import '../../services/hotkey_service.dart';
import '../../services/l10n.dart';
import '../../services/reminder_service.dart';
import '../theme.dart';

/// Cho biết vì sao app có (hoặc không) nhắc: vòng lặp còn sống không, lần chạy
/// gần nhất, lỗi gần nhất, và các mốc sắp tới đã tính sẵn giờ.
class ReminderDiagnosticsDialog extends StatefulWidget {
  const ReminderDiagnosticsDialog({super.key});

  @override
  State<ReminderDiagnosticsDialog> createState() =>
      _ReminderDiagnosticsDialogState();
}

class _ReminderDiagnosticsDialogState
    extends State<ReminderDiagnosticsDialog> {
  ReminderSettings _settings = ReminderSettings.defaults;
  List<ScheduleItem> _pending = const [];
  List<AttendanceSlot> _todaySlots = const [];
  List<AttendanceRule> _rules = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await Repos.settings.reminderSettings();
    final all = await Repos.schedules.all();
    final slots = await Repos.attendance.slotsOn(DateTime.now());
    final rules = await Repos.attendance.rules();
    if (!mounted) return;

    final now = DateTime.now();
    final pending = all
        .where((item) => !item.confirmed && item.remind)
        .toList()
      ..sort((a, b) =>
          a.dueAt(settings.dayStart).compareTo(b.dueAt(settings.dayStart)));

    setState(() {
      _settings = settings;
      _pending = pending
          .where((item) => item
              .dueAt(settings.dayStart)
              .isAfter(now.subtract(const Duration(days: 7))))
          .take(8)
          .toList();
      _todaySlots = slots;
      _rules = rules;
      _loaded = true;
    });
  }

  Future<void> _sendTest() async {
    final error = await ReminderService.instance.sendTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? L10n.t('diag_test_sent')
          : L10n.t2('diag_test_failed', {'e': error})),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final service = ReminderService.instance;

    return AlertDialog(
      title: Text(L10n.t('diag_title')),
      content: SizedBox(
        width: 620,
        height: 500,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(L10n.t('diag_running'),
                        service.isRunning ? '✅' : '❌'),
                    _row(
                      L10n.t('diag_last_run'),
                      service.lastRunAt == null
                          ? '—'
                          : formatDateTime(service.lastRunAt!),
                    ),
                    _row(
                      L10n.t('diag_last_fired'),
                      service.lastFiredAt == null
                          ? '—'
                          : '${formatDateTime(service.lastFiredAt!)} '
                              '(${service.lastFiredCount})',
                    ),
                    _row(L10n.t('diag_last_error'), service.lastError ?? '—',
                        highlight: service.lastError != null),
                    const Divider(height: 24),
                    _row(
                      L10n.t('diag_hotkey'),
                      HotkeyService.instance.isRegistered
                          ? '✅ ${HotkeyService.label}'
                          : '❌ ${HotkeyService.instance.lastError ?? L10n.t('diag_hotkey_blocked')}',
                      highlight: !HotkeyService.instance.isRegistered,
                    ),
                    const Divider(height: 24),
                    _row(
                      L10n.t('diag_config'),
                      '${L10n.t('day_start_time')}: '
                          '${_settings.dayStart.format()} · '
                          '${L10n.t('lead_minutes')}: '
                          '${_settings.leadTime.inMinutes} · '
                          '${L10n.t('nag_minutes')}: '
                          '${_settings.nagInterval.inMinutes}',
                    ),
                    const Divider(height: 24),
                    Text(L10n.t('diag_attendance'),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.xs),
                    if (_rules.every((rule) => !rule.enabled))
                      Text(L10n.t('diag_attendance_off'),
                          style: const TextStyle(color: AppColors.danger))
                    else if (_todaySlots.isEmpty)
                      Text(L10n.t('attendance_none_today'),
                          style: const TextStyle(color: Colors.black54))
                    else
                      for (final slot in _todaySlots)
                        Text('• ${formatTime(slot.dueAt)} '
                            '${L10n.t(slot.kind.l10nKey)} — '
                            '${slot.confirmed ? L10n.t('attendance_done') : L10n.t('attendance_pending')}'),
                    const Divider(height: 24),
                    Text(L10n.t('diag_schedule'),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.xs),
                    if (_pending.isEmpty)
                      Text(L10n.t('diag_schedule_empty'),
                          style: const TextStyle(color: Colors.black54))
                    else
                      for (final item in _pending)
                        Text('• ${formatDateTime(item.dueAt(_settings.dayStart))}'
                            ' — ${item.content}'),
                  ],
                ),
              ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _sendTest,
          icon: const Icon(Icons.notifications_active, size: 18),
          label: Text(L10n.t('diag_test_btn')),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('close'))),
      ],
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: highlight ? AppColors.danger : null,
                ),
              ),
            ),
          ],
        ),
      );
}
