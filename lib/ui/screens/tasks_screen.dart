import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/task.dart';
import '../../services/ai_prompt_builder.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../dialogs/task_editor_dialog.dart';
import '../theme.dart';

/// Danh sách task. Không viết SQL — mọi thứ đi qua [Repos.tasks].
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.onTasksChanged});

  final Future<void> Function()? onTasksChanged;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _tasks = const [];
  TaskStatus? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await Repos.tasks.all();
    if (!mounted) return;
    setState(() => _tasks = tasks);
    await widget.onTasksChanged?.call();
  }

  List<Task> get _visibleTasks => _filter == null
      ? _tasks
      : _tasks.where((task) => task.status == _filter).toList();

  Future<void> _openEditor([Task? task]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => TaskEditorDialog(task: task),
    );
    if (changed ?? false) await _load();
  }

  Future<void> _cycleStatus(Task task) async {
    final updated = await Repos.tasks.cycleStatus(task);
    if (updated.status.isDone) {
      Celebration.instance.fire(L10n.t2('praise_task', {'t': updated.title}));
    }
    await _load();
  }

  Future<void> _copyPromptFor(Task task) async {
    final prompt = await const AiPromptBuilder().forTask(task);
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L10n.t('copied_ai'))));
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.t('delete_task_q')),
        content: Text(task.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(L10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(L10n.t('delete'))),
        ],
      ),
    );
    final id = task.id;
    if ((confirmed ?? false) && id != null) {
      await Repos.tasks.delete(id);
      await _load();
    }
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: [
                ScreenTitle(L10n.t('tasks_title')),
                const Spacer(),
                _StatusFilter(
                  selected: _filter,
                  onChanged: (status) => setState(() => _filter = status),
                ),
              ],
            ),
          ),
          Expanded(
            child: _visibleTasks.isEmpty
                ? Center(child: Text(L10n.t('no_tasks')))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 80),
                    itemCount: _visibleTasks.length,
                    itemBuilder: (context, index) {
                      final task = _visibleTasks[index];
                      return _TaskTile(
                        task: task,
                        onTap: () => _openEditor(task),
                        onCycleStatus: () => _cycleStatus(task),
                        onCopyPrompt: () => _copyPromptFor(task),
                        onDelete: () => _confirmDelete(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onChanged});

  final TaskStatus? selected;
  final ValueChanged<TaskStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'all', label: Text(L10n.t('filter_all'))),
        for (final status in TaskStatus.values)
          ButtonSegment(
              value: status.dbValue, label: Text(L10n.t(status.l10nKey))),
      ],
      selected: {selected?.dbValue ?? 'all'},
      onSelectionChanged: (selection) {
        final value = selection.first;
        onChanged(value == 'all' ? null : TaskStatus.fromDb(value));
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onCycleStatus,
    required this.onCopyPrompt,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onCycleStatus;
  final VoidCallback onCopyPrompt;
  final VoidCallback onDelete;

  static Color _colorOf(TaskStatus status) => switch (status) {
        TaskStatus.todo => Colors.grey,
        TaskStatus.doing => Colors.blue,
        TaskStatus.done => AppColors.success,
      };

  static IconData _iconOf(TaskStatus status) => switch (status) {
        TaskStatus.todo => Icons.radio_button_unchecked,
        TaskStatus.doing => Icons.play_arrow,
        TaskStatus.done => Icons.check,
      };

  String _subtitle() {
    final parts = <String>[
      L10n.t(task.status.l10nKey),
      '${L10n.t('updated')} ${formatDate(task.updatedAt)}',
    ];
    final deadline = task.deadline;
    if (deadline != null) {
      final bell = task.remindDeadline ? '⏰' : '🔕';
      final when = deadline.isAllDay
          ? formatDate(deadline.date)
          : '${formatDate(deadline.date)} ${deadline.time!.format()}';
      parts.add('$bell $when');
    }
    if (task.hasBlocker) parts.add('⚠ ${L10n.t('has_blocker')}');
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(task.status);
    return Card(
      child: ListTile(
        leading: Tooltip(
          message: L10n.t('cycle_status_tooltip'),
          child: InkWell(
            onTap: onCycleStatus,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(_iconOf(task.status), color: color),
            ),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.status.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(_subtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: L10n.t('copy_ai_tooltip'),
              icon: const Icon(Icons.smart_toy_outlined),
              onPressed: onCopyPrompt,
            ),
            IconButton(
              tooltip: L10n.t('delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
