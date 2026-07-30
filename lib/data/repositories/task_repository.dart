import '../../domain/enums.dart';
import '../../domain/models/notes.dart';
import '../../domain/models/schedule_item.dart';
import '../../domain/models/task.dart';
import '../dao/note_dao.dart';
import '../dao/schedule_dao.dart';
import '../dao/task_dao.dart';

/// Nghiệp vụ quanh task. Chỗ duy nhất biết luật "deadline của task phải
/// đồng bộ sang lịch" và "task xong thì tắt nhắc".
class TaskRepository {
  const TaskRepository({
    TaskDao taskDao = const TaskDao(),
    ScheduleDao scheduleDao = const ScheduleDao(),
    WorkLogDao logDao = const WorkLogDao(),
  })  : _tasks = taskDao,
        _schedules = scheduleDao,
        _logs = logDao;

  final TaskDao _tasks;
  final ScheduleDao _schedules;
  final WorkLogDao _logs;

  Future<List<Task>> all() => _tasks.findAll();
  Future<List<Task>> unfinished() => _tasks.findUnfinished();
  Future<Task?> byId(int id) => _tasks.findById(id);
  Future<Map<int, String>> titlesById() => _tasks.titlesById();

  /// Tạo task rồi đẩy deadline (nếu có) sang lịch.
  Future<Task> create(Task task) async {
    final saved = task.withId(await _tasks.insert(task));
    await syncScheduleFor(saved);
    return saved;
  }

  /// Cập nhật task và đồng bộ lại mục lịch tương ứng.
  Future<void> update(Task task) async {
    await _tasks.update(task);
    await syncScheduleFor(task);
  }

  /// Xóa task kèm nhật ký và mục lịch của nó.
  Future<void> delete(int taskId) async {
    await _tasks.delete(taskId);
    await _logs.deleteByTask(taskId);
    await _schedules.deleteByTask(taskId);
  }

  /// Đổi trạng thái theo vòng todo -> doing -> done và cập nhật nhắc.
  Future<Task> cycleStatus(Task task) async {
    final next = task.cycleStatus();
    await update(next);
    return next;
  }

  Future<Task> markDone(Task task) async {
    final done = task.copyWith(status: TaskStatus.done);
    await update(done);
    return done;
  }

  /// Đưa deadline của task lên lịch:
  /// - không có deadline -> gỡ mục lịch liên kết
  /// - có deadline -> tạo/cập nhật, đổi mốc thì bật nhắc lại từ đầu
  Future<void> syncScheduleFor(Task task) async {
    final taskId = task.id;
    if (taskId == null) return;

    final deadline = task.deadline;
    if (deadline == null) {
      await _schedules.deleteByTask(taskId);
      return;
    }

    final existing = await _schedules.findByTask(taskId);
    final content = '[Deadline] ${task.title}';
    final isDone = task.status.isDone;

    if (existing == null) {
      await _schedules.insert(ScheduleItem(
        date: deadline.date,
        time: deadline.time,
        content: content,
        taskId: taskId,
        remind: task.remindDeadline,
        confirmed: isDone,
      ));
      return;
    }

    final movedInTime =
        existing.date != deadline.date || existing.time != deadline.time;
    await _schedules.update(existing.copyWith(
      date: deadline.date,
      time: deadline.time,
      clearTime: deadline.isAllDay,
      content: content,
      remind: task.remindDeadline,
      confirmed: isDone ? true : (movedInTime ? false : existing.confirmed),
      clearLastNotified: movedInTime,
    ));
  }

  // ---- Nhật ký làm việc ----
  Future<void> addLog(int taskId, String content) =>
      _logs.insert(WorkLog(taskId: taskId, content: content));

  Future<void> deleteLog(int logId) => _logs.delete(logId);

  Future<List<WorkLog>> logsOf(int taskId) => _logs.findByTask(taskId);

  Future<List<WorkLog>> logsBetween(DateTime from, DateTime to) =>
      _logs.findBetween(from, to);
}
