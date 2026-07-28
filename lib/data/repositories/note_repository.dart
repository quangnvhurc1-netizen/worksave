import '../../domain/models/notes.dart';
import '../../domain/models/task.dart';
import '../dao/note_dao.dart';
import 'task_repository.dart';

/// Ý tưởng, nhật ký suy nghĩ và save trạng thái.
class NoteRepository {
  const NoteRepository({
    IdeaDao ideaDao = const IdeaDao(),
    JournalDao journalDao = const JournalDao(),
    CheckpointDao checkpointDao = const CheckpointDao(),
    TaskRepository tasks = const TaskRepository(),
  })  : _ideas = ideaDao,
        _journal = journalDao,
        _checkpoints = checkpointDao,
        _tasks = tasks;

  final IdeaDao _ideas;
  final JournalDao _journal;
  final CheckpointDao _checkpoints;
  final TaskRepository _tasks;

  // ---- Ý tưởng ----
  Future<List<Idea>> ideas() => _ideas.findAll();
  Future<void> addIdea(String content) => _ideas.insert(Idea(content: content));
  Future<void> updateIdea(Idea idea) => _ideas.update(idea);
  Future<void> deleteIdea(int id) => _ideas.delete(id);

  /// Biến ý tưởng thành task: dòng đầu làm tiêu đề, toàn văn làm mô tả.
  Future<Task> convertIdeaToTask(Idea idea) async {
    final firstLine = idea.content.split('\n').first.trim();
    final title =
        firstLine.length > 80 ? '${firstLine.substring(0, 80)}…' : firstLine;
    final task = await _tasks
        .create(Task.create(title: title, description: idea.content));
    if (idea.id != null) await _ideas.delete(idea.id!);
    return task;
  }

  // ---- Nhật ký suy nghĩ ----
  Future<List<JournalEntry>> journal() => _journal.findAll();
  Future<void> addJournal(String content) =>
      _journal.insert(JournalEntry(content: content));
  Future<void> updateJournal(JournalEntry entry) => _journal.update(entry);
  Future<void> deleteJournal(int id) => _journal.delete(id);

  // ---- Save trạng thái ----
  Future<List<Checkpoint>> checkpoints() => _checkpoints.findAll();
  Future<Checkpoint?> latestCheckpoint() => _checkpoints.findLatest();
  Future<void> addCheckpoint(Checkpoint c) => _checkpoints.insert(c);
  Future<void> deleteCheckpoint(int id) => _checkpoints.delete(id);
}
