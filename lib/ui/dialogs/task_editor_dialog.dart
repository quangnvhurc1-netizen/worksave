import 'package:flutter/material.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/deadline.dart';
import '../../domain/models/notes.dart';
import '../../domain/models/task.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Tạo mới / sửa task, kèm nhật ký làm việc của task đó.
class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({super.key, this.task});
  final Task? task;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _context = TextEditingController();
  final _blocker = TextEditingController();
  final _direction = TextEditingController();
  final _newLog = TextEditingController();

  TaskStatus _status = TaskStatus.todo;
  Deadline? _deadline;
  bool _remindDeadline = true;
  List<WorkLog> _logs = const [];

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description;
      _context.text = task.context;
      _blocker.text = task.blocker;
      _direction.text = task.direction;
      _status = task.status;
      _deadline = task.deadline;
      _remindDeadline = task.remindDeadline;
      if (task.id != null) _loadLogs(task.id!);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _context,
      _blocker,
      _direction,
      _newLog,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLogs(int taskId) async {
    final logs = await Repos.tasks.logsOf(taskId);
    if (!mounted) return;
    setState(() => _logs = logs);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final existing = widget.task;
    if (existing == null) {
      await Repos.tasks.create(Task.create(
        title: title,
        description: _description.text,
        context: _context.text,
        blocker: _blocker.text,
        direction: _direction.text,
        status: _status,
        deadline: _deadline,
        remindDeadline: _remindDeadline,
      ));
      if (_status.isDone) {
        Celebration.instance.fire(L10n.t2('praise_task', {'t': title}));
      }
    } else {
      final wasDone = existing.status.isDone;
      await Repos.tasks.update(existing.copyWith(
        title: title,
        description: _description.text,
        context: _context.text,
        blocker: _blocker.text,
        direction: _direction.text,
        status: _status,
        deadline: _deadline,
        clearDeadline: _deadline == null,
        remindDeadline: _remindDeadline,
        clearDoneAt: !_status.isDone,
      ));
      if (!wasDone && _status.isDone) {
        Celebration.instance.fire(L10n.t2('praise_task', {'t': title}));
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addLog() async {
    final content = _newLog.text.trim();
    final taskId = widget.task?.id;
    if (content.isEmpty || taskId == null) return;
    await Repos.tasks.addLog(taskId, content);
    _newLog.clear();
    await _loadLogs(taskId);
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline?.date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _deadline = _deadline == null
        ? Deadline(date: picked)
        : _deadline!.copyWith(date: picked));
  }

  Future<void> _pickDeadlineTime() async {
    final current = _deadline?.time;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || _deadline == null) return;
    setState(() => _deadline =
        _deadline!.copyWith(time: ClockTime(picked.hour, picked.minute)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? L10n.t('new_task') : L10n.t('task_detail')),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_title, L10n.t('field_title')),
              _field(_description, L10n.t('field_desc'), lines: 2),
              _field(_context, L10n.t('field_context'), lines: 2),
              _field(_blocker, L10n.t('field_blocker'), lines: 2),
              _field(_direction, L10n.t('field_direction'), lines: 2),
              _buildDeadlineBox(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(L10n.t('status_label')),
                  const SizedBox(width: AppSpacing.sm),
                  SegmentedButton<TaskStatus>(
                    segments: [
                      for (final status in TaskStatus.values)
                        ButtonSegment(
                            value: status, label: Text(L10n.t(status.l10nKey))),
                    ],
                    selected: {_status},
                    onSelectionChanged: (selection) =>
                        setState(() => _status = selection.first),
                  ),
                ],
              ),
              if (!_isNew) _buildLogSection(),
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

  Widget _field(TextEditingController controller, String label,
          {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
          controller: controller,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      );

  Widget _buildDeadlineBox() {
    final deadline = _deadline;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface,
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
                onPressed: _pickDeadlineDate,
                child: Text(deadline == null
                    ? L10n.t('pick_date')
                    : formatDate(deadline.date)),
              ),
              if (deadline != null)
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(deadline.isAllDay
                      ? L10n.t('all_day')
                      : deadline.time!.format()),
                  onPressed: _pickDeadlineTime,
                ),
              if (deadline != null && !deadline.isAllDay)
                IconButton(
                  tooltip: L10n.t('remove_time'),
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  onPressed: () => setState(
                      () => _deadline = deadline.copyWith(clearTime: true)),
                ),
              if (deadline != null)
                IconButton(
                  tooltip: L10n.t('remove_deadline'),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _deadline = null),
                ),
            ],
          ),
          if (deadline != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(L10n.t('remind_deadline')),
              subtitle: Text(
                !_remindDeadline
                    ? L10n.t('remind_off')
                    : deadline.isAllDay
                        ? L10n.t('remind_on_day')
                        : L10n.t('remind_on_time'),
                style: const TextStyle(fontSize: 12),
              ),
              value: _remindDeadline,
              onChanged: (value) => setState(() => _remindDeadline = value),
            ),
        ],
      ),
    );
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(L10n.t('worklog_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _addLog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(L10n.t('log_btn')),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final log in _logs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(formatDate(log.logDate),
                style: const TextStyle(color: Colors.black54)),
            title: Text(log.content),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () async {
                final logId = log.id;
                final taskId = widget.task?.id;
                if (logId == null || taskId == null) return;
                await Repos.tasks.deleteLog(logId);
                await _loadLogs(taskId);
              },
            ),
          ),
      ],
    );
  }
}
