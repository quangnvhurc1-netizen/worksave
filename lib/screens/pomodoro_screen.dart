import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';
import '../services/celebration.dart';

enum PomoPhase { focus, shortBreak, longBreak }

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // Cấu hình (phút)
  int _focusMin = 25;
  int _shortMin = 5;
  int _longMin = 15;
  int _cyclesBeforeLong = 4;

  PomoPhase _phase = PomoPhase.focus;
  int _remaining = 25 * 60; // giây
  bool _running = false;
  int _completedFocus = 0; // số phiên focus trong chuỗi hiện tại
  DateTime? _startedAt;
  Timer? _timer;

  List<TaskItem> _tasks = [];
  int? _taskId;
  int _todayCount = 0;
  int _todayMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadTasks();
    _loadStats();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final db = AppDb.instance;
    _focusMin = int.tryParse(await db.getSetting('pomo_focus') ?? '') ?? 25;
    _shortMin = int.tryParse(await db.getSetting('pomo_short') ?? '') ?? 5;
    _longMin = int.tryParse(await db.getSetting('pomo_long') ?? '') ?? 15;
    _cyclesBeforeLong =
        int.tryParse(await db.getSetting('pomo_cycles') ?? '') ?? 4;
    if (!mounted) return;
    setState(() {
      if (!_running) _remaining = _durationFor(_phase) * 60;
    });
  }

  Future<void> _saveConfig() async {
    final db = AppDb.instance;
    await db.setSetting('pomo_focus', '$_focusMin');
    await db.setSetting('pomo_short', '$_shortMin');
    await db.setSetting('pomo_long', '$_longMin');
    await db.setSetting('pomo_cycles', '$_cyclesBeforeLong');
  }

  Future<void> _loadTasks() async {
    final tasks = await AppDb.instance.getUnfinishedTasks();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      if (_taskId != null && !tasks.any((t) => t.id == _taskId)) {
        _taskId = null;
      }
    });
  }

  Future<void> _loadStats() async {
    final (c, m) = await AppDb.instance.pomodoroToday();
    if (!mounted) return;
    setState(() {
      _todayCount = c;
      _todayMinutes = m;
    });
  }

  int _durationFor(PomoPhase p) => switch (p) {
        PomoPhase.focus => _focusMin,
        PomoPhase.shortBreak => _shortMin,
        PomoPhase.longBreak => _longMin,
      };

  String get _phaseLabel => switch (_phase) {
        PomoPhase.focus => L10n.t('phase_focus'),
        PomoPhase.shortBreak => L10n.t('phase_short'),
        PomoPhase.longBreak => L10n.t('phase_long'),
      };

  Color get _phaseColor => switch (_phase) {
        PomoPhase.focus => const Color(0xFFD9534F),
        PomoPhase.shortBreak => const Color(0xFF2E9E5B),
        PomoPhase.longBreak => const Color(0xFF2E5AAC),
      };

  void _start() {
    if (_running) return;
    _startedAt ??= DateTime.now();
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _finishPhase();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _startedAt = null;
      _remaining = _durationFor(_phase) * 60;
    });
  }

  /// Bỏ qua phiên hiện tại, sang phiên kế (không ghi nhận focus).
  void _skip() {
    _timer?.cancel();
    _startedAt = null;
    _advancePhase(recordFocus: false);
  }

  Future<void> _finishPhase() async {
    _timer?.cancel();
    final wasFocus = _phase == PomoPhase.focus;

    if (wasFocus && _startedAt != null) {
      await AppDb.instance.insertPomodoro(PomodoroSession(
        taskId: _taskId,
        minutes: _focusMin,
        startedAt: _startedAt!,
        finishedAt: DateTime.now(),
      ));
      // Ghi luôn 1 dòng nhật ký làm việc nếu có gắn task.
      if (_taskId != null) {
        await AppDb.instance.insertLog(WorkLog(
          taskId: _taskId,
          content: L10n.t2('pomo_session_log', {'m': '$_focusMin'}),
        ));
      }
      _loadStats();
      Celebration.instance.fire('Xong 1 pomodoro $_focusMin phút!');
    }

    LocalNotification(
      title: wasFocus
          ? L10n.t('pomo_done_notif')
          : L10n.t('pomo_break_notif'),
      body: wasFocus
          ? L10n.t('pomo_done_body')
          : L10n.t('pomo_break_body'),
    ).show();

    _startedAt = null;
    _advancePhase(recordFocus: wasFocus);
  }

  void _advancePhase({required bool recordFocus}) {
    setState(() {
      if (_phase == PomoPhase.focus) {
        if (recordFocus) _completedFocus++;
        _phase = (_completedFocus % _cyclesBeforeLong == 0 && recordFocus)
            ? PomoPhase.longBreak
            : PomoPhase.shortBreak;
      } else {
        _phase = PomoPhase.focus;
      }
      _remaining = _durationFor(_phase) * 60;
      _running = false;
    });
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _openConfig() async {
    final f = TextEditingController(text: '$_focusMin');
    final s = TextEditingController(text: '$_shortMin');
    final l = TextEditingController(text: '$_longMin');
    final c = TextEditingController(text: '$_cyclesBeforeLong');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('pomo_config')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numField(f, L10n.t('pomo_focus_min')),
              _numField(s, L10n.t('pomo_short_min')),
              _numField(l, L10n.t('pomo_long_min')),
              _numField(c, L10n.t('pomo_cycles')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.t('save'))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _focusMin = int.tryParse(f.text) ?? _focusMin;
        _shortMin = int.tryParse(s.text) ?? _shortMin;
        _longMin = int.tryParse(l.text) ?? _longMin;
        _cyclesBeforeLong = int.tryParse(c.text) ?? _cyclesBeforeLong;
        if (!_running) _remaining = _durationFor(_phase) * 60;
      });
      await _saveConfig();
    }
  }

  Widget _numField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = _durationFor(_phase) * 60;
    final progress = total == 0 ? 0.0 : 1 - (_remaining / total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L10n.t('pomodoro_title'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                tooltip: L10n.t('pomo_config_tooltip'),
                icon: const Icon(Icons.tune),
                onPressed: _openConfig,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _phaseColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_phase == PomoPhase.focus ? "🍅" : "☕"} $_phaseLabel',
                    style: TextStyle(
                        color: _phaseColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 240,
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
                            _fmt(_remaining),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: _phaseColor,
                            ),
                          ),
                          Text('${L10n.t('streak')}: $_completedFocus/$_cyclesBeforeLong',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _running ? _pause : _start,
                      icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      label: Text(_running ? L10n.t('pause') : L10n.t('start')),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(L10n.t('reset')),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _skip,
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: Text(L10n.t('skip')),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 420,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _taskId,
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
                      ..._tasks.map((t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text(t.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _taskId = v),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFFF5F8FF),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange),
                        const SizedBox(width: 10),
                        Text(
                          L10n.t2('pomo_today',
                              {'c': '$_todayCount', 'm': '$_todayMinutes'}),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
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
