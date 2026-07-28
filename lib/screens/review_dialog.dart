import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';
import '../services/celebration.dart';

/// Review cuối ngày: điểm qua các task chưa xong, ghi log nhanh, chốt Done.
/// Đây là mắt xích nuôi dữ liệu cho báo cáo tuần.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  List<TaskItem> _tasks = [];
  final Map<int, TextEditingController> _logCtrls = {};
  final Map<int, bool> _markDone = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await AppDb.instance.getUnfinishedTasks();
    for (final t in tasks) {
      if (t.id != null) {
        _logCtrls[t.id!] = TextEditingController();
        _markDone[t.id!] = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in _logCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    int doneCount = 0;
    int logCount = 0;
    for (final t in _tasks) {
      if (t.id == null) continue;
      final log = _logCtrls[t.id!]?.text.trim() ?? '';
      if (log.isNotEmpty) {
        await AppDb.instance.insertLog(WorkLog(taskId: t.id, content: log));
        logCount++;
      }
      if (_markDone[t.id!] == true) {
        t.status = 'done';
        t.doneAt = DateTime.now();
        await AppDb.instance.updateTask(t);
        await AppDb.instance.confirmSchedulesForTask(t.id!);
        doneCount++;
      }
    }
    await AppDb.instance.setSetting('review_date', _todayIso());

    if (doneCount > 0) {
      Celebration.instance
          .fire('Hoàn thành $doneCount task hôm nay — nghỉ ngơi xứng đáng!');
    } else if (logCount > 0) {
      Celebration.instance
          .fire('Đã chốt sổ hôm nay với $logCount dòng nhật ký!');
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _skip() async {
    // Bỏ qua hôm nay -> không hỏi lại nữa trong ngày.
    await AppDb.instance.setSetting('review_date', _todayIso());
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wb_twilight, color: Colors.orange),
          const SizedBox(width: 8),
          Text(L10n.t('review_title')),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 460,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : _tasks.isEmpty
                ? Center(child: Text(L10n.t('review_none')))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10n.t('review_sub'),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (_, i) {
                            final t = _tasks[i];
                            final id = t.id!;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(t.title,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ),
                                        Text(L10n.t('done_q'),
                                            style:
                                                TextStyle(fontSize: 12)),
                                        Checkbox(
                                          value: _markDone[id],
                                          onChanged: (v) => setState(() =>
                                              _markDone[id] = v ?? false),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller: _logCtrls[id],
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
                  ),
      ),
      actions: [
        TextButton(
            onPressed: _skip, child: Text(L10n.t('review_skip'))),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text(L10n.t('review_submit')),
        ),
      ],
    );
  }
}
