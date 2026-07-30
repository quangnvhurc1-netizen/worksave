import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/notes.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/task.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../../services/notification_center.dart';
import '../theme.dart';

/// Đồng hồ Pomodoro; phiên focus xong sẽ tự ghi nhật ký cho task đang gắn.
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroSettings _settings = PomodoroSettings.defaults;
  PomodoroPhase _phase = PomodoroPhase.focus;
  Duration _remaining = Duration(minutes: PomodoroSettings.defaults.focusMinutes);
  bool _running = false;
  int _completedFocusSessions = 0;
  DateTime? _startedAt;
  Timer? _ticker;

  List<Task> _tasks = const [];
  int? _selectedTaskId;
  PomodoroDailyStats _todayStats = (sessions: 0, minutes: 0);

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadEverything() async {
    final settings = await Repos.settings.pomodoroSettings();
    final tasks = await Repos.tasks.unfinished();
    final stats = await Repos.pomodoro.todayStats();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _tasks = tasks;
      _todayStats = stats;
      if (!_running) _remaining = _durationOf(_phase);
      if (!tasks.any((t) => t.id == _selectedTaskId)) _selectedTaskId = null;
    });
  }

  Duration _durationOf(PomodoroPhase phase) => Duration(
        minutes: switch (phase) {
          PomodoroPhase.focus => _settings.focusMinutes,
          PomodoroPhase.shortBreak => _settings.shortBreakMinutes,
          PomodoroPhase.longBreak => _settings.longBreakMinutes,
        },
      );

  Color get _phaseColor => switch (_phase) {
        PomodoroPhase.focus => AppColors.danger,
        PomodoroPhase.shortBreak => AppColors.success,
        PomodoroPhase.longBreak => AppColors.primary,
      };

  void _start() {
    if (_running) return;
    _startedAt ??= DateTime.now();
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        unawaited(_completePhase());
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _startedAt = null;
      _remaining = _durationOf(_phase);
    });
  }

  void _skip() {
    _ticker?.cancel();
    _startedAt = null;
    _advance(countFocus: false);
  }

  Future<void> _completePhase() async {
    _ticker?.cancel();
    final wasFocus = _phase.isFocus;
    final startedAt = _startedAt;

    if (wasFocus && startedAt != null) {
      await Repos.pomodoro.record(PomodoroSession(
        taskId: _selectedTaskId,
        minutes: _settings.focusMinutes,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
      ));
      final taskId = _selectedTaskId;
      if (taskId != null) {
        await Repos.tasks.addLog(taskId,
            L10n.t2('pomo_session_log', {'m': '${_settings.focusMinutes}'}));
      }
      final stats = await Repos.pomodoro.todayStats();
      if (mounted) setState(() => _todayStats = stats);
      Celebration.instance.fire(
          L10n.t2('praise_pomodoro', {'m': '${_settings.focusMinutes}'}));
    }

    final title =
        wasFocus ? L10n.t('pomo_done_notif') : L10n.t('pomo_break_notif');
    final body =
        wasFocus ? L10n.t('pomo_done_body') : L10n.t('pomo_break_body');
    LocalNotification(title: title, body: body).show();
    NotificationCenter.instance.push(
      kind: NotificationKind.pomodoro,
      title: title,
      body: body,
      targetTab: AppTab.pomodoro,
    );

    _startedAt = null;
    _advance(countFocus: wasFocus);
  }

  void _advance({required bool countFocus}) {
    setState(() {
      if (_phase.isFocus) {
        if (countFocus) _completedFocusSessions++;
        final needsLongBreak = countFocus &&
            _completedFocusSessions % _settings.cyclesBeforeLongBreak == 0;
        _phase =
            needsLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      } else {
        _phase = PomodoroPhase.focus;
      }
      _remaining = _durationOf(_phase);
      _running = false;
    });
  }

  Future<void> _openSettings() async {
    final updated = await showDialog<PomodoroSettings>(
      context: context,
      builder: (_) => _PomodoroSettingsDialog(initial: _settings),
    );
    if (updated == null) return;
    await Repos.settings.savePomodoroSettings(updated);
    if (!mounted) return;
    setState(() {
      _settings = updated;
      if (!_running) _remaining = _durationOf(_phase);
    });
  }

  static String _formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final total = _durationOf(_phase).inSeconds;
    final progress =
        total == 0 ? 0.0 : 1 - (_remaining.inSeconds / total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScreenTitle(L10n.t('pomodoro_title')),
              const Spacer(),
              IconButton(
                tooltip: L10n.t('pomo_config_tooltip'),
                icon: const Icon(Icons.tune),
                onPressed: _openSettings,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Column(
              children: [
                _PhaseChip(phase: _phase, color: _phaseColor),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.black12,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_phaseColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCountdown(_remaining),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: _phaseColor,
                            ),
                          ),
                          Text(
                            '${L10n.t('streak')}: $_completedFocusSessions'
                            '/${_settings.cyclesBeforeLongBreak}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _running ? _pause : _start,
                      icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      label:
                          Text(_running ? L10n.t('pause') : L10n.t('start')),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(L10n.t('reset')),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _skip,
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: Text(L10n.t('skip')),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 420,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedTaskId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: L10n.t('pomo_task_label'),
                      helperText: L10n.t('pomo_task_help'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null, child: Text(L10n.t('pomo_no_task'))),
                      for (final task in _tasks)
                        DropdownMenuItem<int?>(
                          value: task.id,
                          child: Text(task.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedTaskId = value),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  color: AppColors.panelSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange),
                        const SizedBox(width: 10),
                        Text(
                          L10n.t2('pomo_today', {
                            'c': '${_todayStats.sessions}',
                            'm': '${_todayStats.minutes}',
                          }),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase, required this.color});
  final PomodoroPhase phase;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${phase.isFocus ? "🍅" : "☕"} ${L10n.t(phase.l10nKey)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
}

class _PomodoroSettingsDialog extends StatefulWidget {
  const _PomodoroSettingsDialog({required this.initial});
  final PomodoroSettings initial;

  @override
  State<_PomodoroSettingsDialog> createState() =>
      _PomodoroSettingsDialogState();
}

class _PomodoroSettingsDialogState extends State<_PomodoroSettingsDialog> {
  late final TextEditingController _focus =
      TextEditingController(text: '${widget.initial.focusMinutes}');
  late final TextEditingController _short =
      TextEditingController(text: '${widget.initial.shortBreakMinutes}');
  late final TextEditingController _long =
      TextEditingController(text: '${widget.initial.longBreakMinutes}');
  late final TextEditingController _cycles =
      TextEditingController(text: '${widget.initial.cyclesBeforeLongBreak}');

  @override
  void dispose() {
    for (final c in [_focus, _short, _long, _cycles]) {
      c.dispose();
    }
    super.dispose();
  }

  int _positiveOr(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    return (value == null || value < 1) ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('pomo_config')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numberField(_focus, L10n.t('pomo_focus_min')),
            _numberField(_short, L10n.t('pomo_short_min')),
            _numberField(_long, L10n.t('pomo_long_min')),
            _numberField(_cycles, L10n.t('pomo_cycles')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            PomodoroSettings(
              focusMinutes: _positiveOr(_focus, widget.initial.focusMinutes),
              shortBreakMinutes:
                  _positiveOr(_short, widget.initial.shortBreakMinutes),
              longBreakMinutes:
                  _positiveOr(_long, widget.initial.longBreakMinutes),
              cyclesBeforeLongBreak:
                  _positiveOr(_cycles, widget.initial.cyclesBeforeLongBreak),
            ),
          ),
          child: Text(L10n.t('save')),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
