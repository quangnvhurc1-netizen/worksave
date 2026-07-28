import '../../domain/enums.dart';
import '../../domain/models/search_hit.dart';
import '../dao/note_dao.dart';
import '../dao/schedule_dao.dart';
import '../dao/task_dao.dart';

/// Tìm kiếm trải khắp mọi loại dữ liệu.
class SearchRepository {
  const SearchRepository({
    TaskDao taskDao = const TaskDao(),
    WorkLogDao logDao = const WorkLogDao(),
    IdeaDao ideaDao = const IdeaDao(),
    JournalDao journalDao = const JournalDao(),
    CheckpointDao checkpointDao = const CheckpointDao(),
    ScheduleDao scheduleDao = const ScheduleDao(),
  })  : _tasks = taskDao,
        _logs = logDao,
        _ideas = ideaDao,
        _journal = journalDao,
        _checkpoints = checkpointDao,
        _schedules = scheduleDao;

  final TaskDao _tasks;
  final WorkLogDao _logs;
  final IdeaDao _ideas;
  final JournalDao _journal;
  final CheckpointDao _checkpoints;
  final ScheduleDao _schedules;

  static const int _minQueryLength = 2;

  Future<List<SearchHit>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < _minQueryLength) return const [];
    final like = '%$query%';

    final hits = <SearchHit>[];

    for (final task in await _tasks.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.task,
        title: task.title,
        snippet: _truncate('${task.description} ${task.blocker}'),
        date: task.updatedAt,
      ));
    }

    final titles = await _tasks.titlesById();
    for (final log in await _logs.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.workLog,
        title: titles[log.taskId] ?? '—',
        snippet: _truncate(log.content),
        date: log.logDate,
      ));
    }

    for (final idea in await _ideas.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.idea,
        title: _truncate(idea.content, 60),
        snippet: _truncate(idea.content),
        date: idea.createdAt,
      ));
    }

    for (final entry in await _journal.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.journal,
        title: _truncate(entry.content, 60),
        snippet: _truncate(entry.content),
        date: entry.createdAt,
      ));
    }

    for (final cp in await _checkpoints.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.checkpoint,
        title: _truncate(cp.doing, 60),
        snippet: _truncate('${cp.nextStep} ${cp.remember}'),
        date: cp.createdAt,
      ));
    }

    for (final item in await _schedules.search(like)) {
      hits.add(SearchHit(
        kind: SearchHitKind.schedule,
        title: _truncate(item.content, 60),
        snippet: '',
        date: item.date,
      ));
    }

    hits.sort((a, b) => b.date.compareTo(a.date));
    return hits;
  }

  static String _truncate(String value, [int max = 100]) {
    final text = value.trim().replaceAll('\n', ' · ');
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }
}
