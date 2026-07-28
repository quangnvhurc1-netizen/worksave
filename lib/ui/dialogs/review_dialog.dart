import 'package:flutter/material.dart';

import '../../data/repositories/repositories.dart';
import '../../domain/models/task.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Review cuối ngày: ghi nhật ký cho từng task và chốt cái nào đã xong.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  List<Task> _tasks = const [];
  final Map<int, TextEditingController> _logControllers = {};
  final Set<int> _markedDone = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _logControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final tasks = await Repos.tasks.unfinished();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      for (final task in tasks) {
        final id = task.id;
        if (id != null) _logControllers[id] = TextEditingController();
      }
      _loaded = true;
    });
  }

  Future<void> _submit() async {
    var doneCount = 0;
    var loggedCount = 0;

    for (final task in _tasks) {
      final id = task.id;
      if (id == null) continue;

      final logText = _logControllers[id]?.text.trim() ?? '';
      if (logText.isNotEmpty) {
        await Repos.tasks.addLog(id, logText);
        loggedCount++;
      }
      if (_markedDone.contains(id)) {
        await Repos.tasks.markDone(task);
        doneCount++;
      }
    }
    await Repos.settings.markReviewDoneToday();

    if (doneCount > 0) {
      Celebration.instance
          .fire(L10n.t2('praise_review_done', {'n': '$doneCount'}));
    } else if (loggedCount > 0) {
      Celebration.instance
          .fire(L10n.t2('praise_review_log', {'n': '$loggedCount'}));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _skipToday() async {
    await Repos.settings.markReviewDoneToday();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wb_twilight, color: Colors.orange),
          const SizedBox(width: AppSpacing.sm),
          Text(L10n.t('review_title')),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 460,
        child: _buildBody(),
      ),
      actions: [
        TextButton(
            onPressed: _skipToday, child: Text(L10n.t('review_skip'))),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text(L10n.t('review_submit')),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tasks.isEmpty) {
      return Center(child: Text(L10n.t('review_none')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHint(L10n.t('review_sub')),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              final id = task.id;
              if (id == null) return const SizedBox.shrink();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(task.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(L10n.t('done_q'),
                              style: const TextStyle(fontSize: 12)),
                          Checkbox(
                            value: _markedDone.contains(id),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                _markedDone.add(id);
                              } else {
                                _markedDone.remove(id);
                              }
                            }),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _logControllers[id],
                        decoration: InputDecoration(
                          hintText: L10n.t('worklog_hint'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
