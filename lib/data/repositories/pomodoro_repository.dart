import '../../domain/models/notes.dart';
import '../dao/note_dao.dart';

/// Thống kê Pomodoro.
typedef PomodoroDailyStats = ({int sessions, int minutes});

class PomodoroRepository {
  const PomodoroRepository({PomodoroDao dao = const PomodoroDao()}) : _dao = dao;
  final PomodoroDao _dao;

  Future<void> record(PomodoroSession session) => _dao.insert(session);

  Future<PomodoroDailyStats> todayStats() async {
    final now = DateTime.now();
    final sessions =
        await _dao.findFinishedSince(DateTime(now.year, now.month, now.day));
    return (
      sessions: sessions.length,
      minutes: sessions.fold<int>(0, (sum, s) => sum + s.minutes),
    );
  }

  /// Tổng phút focus theo từng task.
  Future<Map<int, int>> minutesByTask() async {
    final sessions = await _dao.findWithTask();
    final result = <int, int>{};
    for (final s in sessions) {
      final id = s.taskId;
      if (id == null) continue;
      result[id] = (result[id] ?? 0) + s.minutes;
    }
    return result;
  }
}
