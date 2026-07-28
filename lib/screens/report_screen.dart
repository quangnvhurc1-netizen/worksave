import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime _monday; // thứ 2 của tuần đang chọn
  String _prompt = '';
  List<TaskItem> _unfinished = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monday = now.subtract(Duration(days: now.weekday - 1));
    _monday = DateTime(_monday.year, _monday.month, _monday.day);
    _build();
  }

  DateTime get _friday => _monday.add(const Duration(days: 4));
  DateTime get _sunday => _monday.add(const Duration(days: 6));

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _build() async {
    final logs =
        await AppDb.instance.getLogsBetween(_iso(_monday), _iso(_sunday));
    final unfinished = await AppDb.instance.getUnfinishedTasks();
    final tasks = await AppDb.instance.getTasks();
    final taskById = {for (final t in tasks) t.id: t};

    // Gom log theo ngày
    final Map<String, List<String>> byDate = {};
    for (final l in logs) {
      final key = fmtDate(l.logDate);
      final taskTitle =
          l.taskId != null ? taskById[l.taskId]?.title : null;
      final line = taskTitle != null
          ? '[$taskTitle] ${l.content.trim()}'
          : l.content.trim();
      byDate.putIfAbsent(key, () => []).add(line);
    }

    final b = StringBuffer();
    b.writeln('Bạn là trợ lý viết báo cáo công việc. '
        'Dưới đây là nhật ký làm việc của tôi trong tuần từ '
        '${fmtDate(_monday)} đến ${fmtDate(_friday)}.');
    b.writeln();
    b.writeln('Hãy tổng hợp thành báo cáo tuần, viết bằng tiếng Việt, '
        'văn phong công việc, mỗi ngày gom các việc cùng chủ đề lại thành 1-2 câu gọn. '
        'Trả lời ĐÚNG theo format sau, không thêm gì khác:');
    b.writeln('-Ngày .../.../...: "Nội dung task sau tổng hợp"');
    b.writeln('-Ngày .../.../...: "..."');
    b.writeln();
    b.writeln('=== NHẬT KÝ THÔ ===');
    if (byDate.isEmpty) {
      b.writeln('(Tuần này chưa có nhật ký nào. '
          'Hãy vào tab Task, mở từng task và bấm "Ghi" nhật ký hằng ngày.)');
    } else {
      for (final entry in byDate.entries) {
        b.writeln('Ngày ${entry.key}:');
        for (final line in entry.value) {
          b.writeln('  - $line');
        }
      }
    }

    if (unfinished.isNotEmpty) {
      b.writeln();
      b.writeln('=== VIỆC CHƯA XONG (đưa vào mục "kế hoạch tuần sau") ===');
      for (final t in unfinished) {
        b.writeln('- ${t.title} (${AppDb.statusLabel(t.status)})'
            '${t.blocker.trim().isNotEmpty ? ' — vướng: ${t.blocker.trim()}' : ''}');
      }
    }

    if (!mounted) return;
    setState(() {
      _prompt = b.toString();
      _unfinished = unfinished;
    });
  }

  void _shiftWeek(int weeks) {
    setState(() => _monday = _monday.add(Duration(days: 7 * weeks)));
    _build();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L10n.t('tab_report'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left)),
              Text('${fmtDate(_monday)} → ${fmtDate(_friday)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (_unfinished.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Còn ${_unfinished.length} task chưa Done — kiểm tra lại trước khi gửi báo cáo: '
                      '${_unfinished.map((t) => t.title).join(', ')}',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Prompt bên dưới được tổng hợp từ nhật ký các task trong tuần. '
            'Bấm Copy rồi dán vào AI chat để sinh báo cáo.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _prompt,
                  style: const TextStyle(
                      fontFamily: 'Consolas', fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _prompt));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Đã copy prompt báo cáo tuần vào clipboard.')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy prompt'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _build,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
