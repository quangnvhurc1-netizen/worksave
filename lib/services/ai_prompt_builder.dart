import '../core/date_x.dart';
import '../data/repositories/repositories.dart';
import '../domain/models/notes.dart';
import '../domain/models/task.dart';
import '../services/l10n.dart';

/// Dựng các prompt gửi cho AI. Tách khỏi tầng dữ liệu để repository không
/// phải biết gì về chuyện hiển thị hay câu chữ.
class AiPromptBuilder {
  const AiPromptBuilder();

  /// Prompt xin gợi ý xử lý cho một task.
  Future<String> forTask(Task task) async {
    final buffer = StringBuffer()
      ..writeln('Tôi đang xử lý một task trong công việc, dưới đây là toàn bộ '
          'thông tin. Hãy phân tích và gợi ý hướng giải quyết cụ thể, từng bước.')
      ..writeln()
      ..writeln('## Task: ${task.title}')
      ..writeln('- Trạng thái: ${L10n.t(task.status.l10nKey)}');

    final deadline = task.deadline;
    if (deadline != null) {
      final when = deadline.isAllDay
          ? formatDate(deadline.date)
          : '${formatDate(deadline.date)} ${deadline.time!.format()}';
      buffer.writeln('- Deadline: $when');
    }
    _writeIfNotEmpty(buffer, 'Mô tả', task.description);
    _writeIfNotEmpty(buffer, 'Bối cảnh / hệ thống liên quan', task.context);
    _writeIfNotEmpty(buffer, 'Vướng mắc hiện tại', task.blocker);
    _writeIfNotEmpty(buffer, 'Hướng giải quyết tôi đang nghĩ tới', task.direction);

    final id = task.id;
    if (id != null) {
      final logs = await Repos.tasks.logsOf(id);
      if (logs.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('## Nhật ký đã làm:');
        for (final log in logs.reversed) {
          buffer.writeln('- [${formatDate(log.logDate)}] ${log.content.trim()}');
        }
      }
    }

    buffer
      ..writeln()
      ..writeln('Yêu cầu: gợi ý các bước tiếp theo, rủi ro cần lưu ý, và nếu '
          'thiếu thông tin thì liệt kê câu hỏi tôi cần làm rõ.');
    return buffer.toString();
  }

  /// Prompt sinh báo cáo tuần từ nhật ký các task.
  Future<String> forWeeklyReport({
    required DateTime monday,
    required DateTime friday,
    required List<WorkLog> logs,
    required List<Task> unfinished,
    required Map<int, String> taskTitles,
  }) async {
    final buffer = StringBuffer()
      ..writeln('Bạn là trợ lý viết báo cáo công việc. Dưới đây là nhật ký '
          'làm việc của tôi trong tuần từ ${formatDate(monday)} đến '
          '${formatDate(friday)}.')
      ..writeln()
      ..writeln('Hãy tổng hợp thành báo cáo tuần, viết bằng tiếng Việt, văn '
          'phong công việc, mỗi ngày gom các việc cùng chủ đề thành 1-2 câu '
          'gọn. Trả lời ĐÚNG theo format sau, không thêm gì khác:')
      ..writeln('-Ngày .../.../...: "Nội dung task sau tổng hợp"')
      ..writeln('-Ngày .../.../...: "..."')
      ..writeln()
      ..writeln('=== NHẬT KÝ THÔ ===');

    final byDate = <String, List<String>>{};
    for (final log in logs) {
      final title = log.taskId == null ? null : taskTitles[log.taskId];
      final line = title == null
          ? log.content.trim()
          : '[$title] ${log.content.trim()}';
      byDate.putIfAbsent(formatDate(log.logDate), () => []).add(line);
    }

    if (byDate.isEmpty) {
      buffer.writeln('(Tuần này chưa có nhật ký nào. Hãy vào tab Task, mở '
          'từng task và bấm "Ghi" nhật ký hằng ngày.)');
    } else {
      for (final entry in byDate.entries) {
        buffer.writeln('Ngày ${entry.key}:');
        for (final line in entry.value) {
          buffer.writeln('  - $line');
        }
      }
    }

    if (unfinished.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('=== VIỆC CHƯA XONG (đưa vào mục "kế hoạch tuần sau") ===');
      for (final task in unfinished) {
        final blocker = task.hasBlocker ? ' — vướng: ${task.blocker.trim()}' : '';
        buffer.writeln('- ${task.title} (${L10n.t(task.status.l10nKey)})$blocker');
      }
    }
    return buffer.toString();
  }

  static void _writeIfNotEmpty(StringBuffer buffer, String label, String value) {
    if (value.trim().isEmpty) return;
    buffer.writeln('- $label: ${value.trim()}');
  }
}
