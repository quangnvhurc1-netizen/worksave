import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';
import '../services/celebration.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = [];
  String _filter = 'all'; // all | todo | doing | done

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await AppDb.instance.getTasks();
    if (!mounted) return;
    setState(() => _tasks = tasks);
    widget.onChanged?.call();
  }

  List<TaskItem> get _visible => _filter == 'all'
      ? _tasks
      : _tasks.where((t) => t.status == _filter).toList();

  Color _statusColor(String s) => switch (s) {
        'doing' => Colors.blue,
        'done' => Colors.green,
        _ => Colors.grey,
      };

  Future<void> _openEditor([TaskItem? task]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskEditorDialog(task: task),
    );
    if (changed == true) _load();
  }

  Future<void> _cycleStatus(TaskItem t) async {
    t.status = switch (t.status) {
      'todo' => 'doing',
      'doing' => 'done',
      _ => 'todo',
    };
    t.doneAt = t.status == 'done' ? DateTime.now() : null;
    await AppDb.instance.updateTask(t);
    if (t.id != null) {
      // Done -> tắt nhắc deadline; mở lại -> nhắc tiếp.
      await AppDb.instance
          .confirmSchedulesForTask(t.id!, confirmed: t.status == 'done');
    }
    if (t.status == 'done') {
      Celebration.instance.fire('Đã xong "${t.title}"!');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(L10n.t('new_task')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(L10n.t('tasks_title'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'all', label: Text(L10n.t('filter_all'))),
                    ButtonSegment(
                        value: 'todo', label: Text(L10n.t('status_todo'))),
                    ButtonSegment(
                        value: 'doing', label: Text(L10n.t('status_doing'))),
                    ButtonSegment(
                        value: 'done', label: Text(L10n.t('status_done'))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) =>
                      setState(() => _filter = s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: _visible.isEmpty
                ? Center(child: Text(L10n.t('no_tasks')))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: _visible.length,
                    itemBuilder: (_, i) {
                      final t = _visible[i];
                      return Card(
                        child: ListTile(
                          leading: Tooltip(
                            message: L10n.t('cycle_status_tooltip'),
                            child: InkWell(
                              onTap: () => _cycleStatus(t),
                              borderRadius: BorderRadius.circular(20),
                              child: CircleAvatar(
                                backgroundColor:
                                    _statusColor(t.status).withOpacity(.15),
                                child: Icon(
                                  t.status == 'done'
                                      ? Icons.check
                                      : t.status == 'doing'
                                          ? Icons.play_arrow
                                          : Icons.radio_button_unchecked,
                                  color: _statusColor(t.status),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            t.title,
                            style: TextStyle(
                              decoration: t.status == 'done'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${AppDb.statusLabel(t.status)} · ${L10n.t('updated')} ${fmtDate(t.updatedAt)}'
                            '${t.deadline != null ? '  ·  ${t.remindDeadline ? "⏰" : "🔕"} ${fmtDateTime(t.deadline!, withTime: t.hasTime)}' : ''}'
                            '${t.blocker.trim().isNotEmpty ? '  ·  ⚠ ${L10n.t('has_blocker')}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: L10n.t('copy_ai_tooltip'),
                                icon: const Icon(Icons.smart_toy_outlined),
                                onPressed: () async {
                                  final prompt = await AppDb.instance
                                      .buildTaskAiPrompt(t);
                                  await Clipboard.setData(
                                      ClipboardData(text: prompt));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(L10n.t('copied_ai')),
                                    ));
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: L10n.t('delete'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(L10n.t('delete_task_q')),
                                      content: Text(
                                          'Xóa "${t.title}" và toàn bộ nhật ký của nó?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(L10n.t('cancel'))),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(L10n.t('delete'))),
                                      ],
                                    ),
                                  );
                                  if (ok == true && t.id != null) {
                                    await AppDb.instance.deleteTask(t.id!);
                                    _load();
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () => _openEditor(t),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.task});
  final TaskItem? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _context;
  late final TextEditingController _blocker;
  late final TextEditingController _direction;
  final TextEditingController _newLog = TextEditingController();
  String _status = 'todo';
  DateTime? _deadline;
  bool _hasTime = false;
  bool _remindDeadline = true;
  List<WorkLog> _logs = [];

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _context = TextEditingController(text: t?.context ?? '');
    _blocker = TextEditingController(text: t?.blocker ?? '');
    _direction = TextEditingController(text: t?.direction ?? '');
    _status = t?.status ?? 'todo';
    _deadline = t?.deadline;
    _hasTime = t?.hasTime ?? false;
    _remindDeadline = t?.remindDeadline ?? true;
    if (t?.id != null) _loadLogs(t!.id!);
  }

  Future<void> _loadLogs(int taskId) async {
    final logs = await AppDb.instance.getLogsForTask(taskId);
    if (!mounted) return;
    setState(() => _logs = logs);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _context.dispose();
    _blocker.dispose();
    _direction.dispose();
    _newLog.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (_isNew) {
      final t = TaskItem(
        title: _title.text.trim(),
        description: _desc.text,
        context: _context.text,
        blocker: _blocker.text,
        direction: _direction.text,
        status: _status,
        deadline: _deadline,
        remindDeadline: _remindDeadline,
        doneAt: _status == 'done' ? now : null,
      );
      final id = await AppDb.instance.insertTask(t);
      // Đẩy deadline sang lịch.
      await AppDb.instance.syncTaskSchedule(TaskItem(
        id: id,
        title: t.title,
        status: t.status,
        deadline: t.deadline,
        remindDeadline: t.remindDeadline,
      ));
    } else {
      final t = widget.task!;
      final wasDone = t.status == 'done';
      t.title = _title.text.trim();
      t.description = _desc.text;
      t.context = _context.text;
      t.blocker = _blocker.text;
      t.direction = _direction.text;
      t.deadline = _deadline;
      t.remindDeadline = _remindDeadline;
      if (t.status != 'done' && _status == 'done') t.doneAt = now;
      if (_status != 'done') t.doneAt = null;
      t.status = _status;
      await AppDb.instance.updateTask(t);
      await AppDb.instance.syncTaskSchedule(t);
      if (t.id != null && t.status == 'done') {
        await AppDb.instance.confirmSchedulesForTask(t.id!);
      }
      if (!wasDone && t.status == 'done') {
        Celebration.instance.fire('Đã xong "${t.title}"!');
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addLog() async {
    final content = _newLog.text.trim();
    final id = widget.task?.id;
    if (content.isEmpty || id == null) return;
    await AppDb.instance.insertLog(WorkLog(taskId: id, content: content));
    _newLog.clear();
    _loadLogs(id);
  }

  Widget _tf(TextEditingController c, String label, String hint,
      {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? L10n.t('new_task') : L10n.t('task_detail')),
      content: SizedBox(
        width: 640,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tf(_title, L10n.t('field_title'), ''),
              _tf(_desc, L10n.t('field_desc'), '', lines: 2),
              _tf(_context, L10n.t('field_context'), '', lines: 2),
              _tf(_blocker, L10n.t('field_blocker'), '', lines: 2),
              _tf(_direction, L10n.t('field_direction'), '', lines: 2),
              // ---- Deadline: ngày + giờ + bật/tắt nhắc ----
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alarm, size: 18),
                        const SizedBox(width: 6),
                        Text(L10n.t('deadline')),
                        TextButton(
                          child: Text(_deadline == null
                              ? L10n.t('pick_date')
                              : fmtDate(_deadline!)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _deadline ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                final old = _deadline;
                                _deadline = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    _hasTime ? (old?.hour ?? 9) : 0,
                                    _hasTime ? (old?.minute ?? 0) : 0);
                              });
                            }
                          },
                        ),
                        if (_deadline != null)
                          TextButton.icon(
                            icon: const Icon(Icons.schedule, size: 16),
                            label: Text(_hasTime
                                ? '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}'
                                : L10n.t('all_day')),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _hasTime
                                    ? TimeOfDay(
                                        hour: _deadline!.hour,
                                        minute: _deadline!.minute)
                                    : const TimeOfDay(hour: 9, minute: 0),
                                helpText: 'Giờ deadline',
                              );
                              if (t != null) {
                                setState(() {
                                  _hasTime = true;
                                  _deadline = DateTime(
                                      _deadline!.year,
                                      _deadline!.month,
                                      _deadline!.day,
                                      t.hour,
                                      t.minute);
                                });
                              }
                            },
                          ),
                        if (_deadline != null && _hasTime)
                          IconButton(
                            tooltip: L10n.t('remove_time'),
                            icon: const Icon(Icons.schedule_outlined,
                                size: 16),
                            onPressed: () => setState(() {
                              _hasTime = false;
                              _deadline = DateTime(_deadline!.year,
                                  _deadline!.month, _deadline!.day);
                            }),
                          ),
                        if (_deadline != null)
                          IconButton(
                            tooltip: L10n.t('remove_deadline'),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _deadline = null;
                              _hasTime = false;
                            }),
                          ),
                      ],
                    ),
                    if (_deadline != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(L10n.t('remind_deadline')),
                        subtitle: Text(
                          _remindDeadline
                              ? (_hasTime
                                  ? L10n.t('remind_on_time')
                                  : L10n.t('remind_on_day'))
                              : L10n.t('remind_off'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _remindDeadline,
                        onChanged: (v) =>
                            setState(() => _remindDeadline = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(L10n.t('status_label')),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'todo', label: Text(L10n.t('status_todo'))),
                      ButtonSegment(
                          value: 'doing', label: Text(L10n.t('status_doing'))),
                      ButtonSegment(
                          value: 'done', label: Text(L10n.t('status_done'))),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) =>
                        setState(() => _status = s.first),
                  ),
                ],
              ),
              if (!_isNew) ...[
                const Divider(height: 32),
                Text(L10n.t('worklog_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newLog,
                        decoration: InputDecoration(
                          hintText: L10n.t('worklog_hint'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addLog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addLog,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(L10n.t('log_btn')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._logs.map((l) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(fmtDate(l.logDate),
                          style: const TextStyle(color: Colors.black54)),
                      title: Text(l.content),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          if (l.id != null) {
                            await AppDb.instance.deleteLog(l.id!);
                            _loadLogs(widget.task!.id!);
                          }
                        },
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.t('cancel'))),
        FilledButton(onPressed: _save, child: Text(L10n.t('save'))),
      ],
    );
  }
}
