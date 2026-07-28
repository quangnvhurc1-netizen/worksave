import 'package:meta/meta.dart';

import '../enums.dart';
import 'deadline.dart';

/// Một đầu việc. Bất biến — mọi thay đổi đi qua [copyWith] để tránh
/// sửa ngầm object đang được UI giữ.
@immutable
class Task {
  final int? id;
  final String title;
  final String description;
  final String context;
  final String blocker;
  final String direction;
  final TaskStatus status;
  final Deadline? deadline;
  final bool remindDeadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? doneAt;

  const Task({
    this.id,
    required this.title,
    this.description = '',
    this.context = '',
    this.blocker = '',
    this.direction = '',
    this.status = TaskStatus.todo,
    this.deadline,
    this.remindDeadline = true,
    required this.createdAt,
    required this.updatedAt,
    this.doneAt,
  });

  factory Task.create({
    required String title,
    String description = '',
    String context = '',
    String blocker = '',
    String direction = '',
    TaskStatus status = TaskStatus.todo,
    Deadline? deadline,
    bool remindDeadline = true,
  }) {
    final now = DateTime.now();
    return Task(
      title: title,
      description: description,
      context: context,
      blocker: blocker,
      direction: direction,
      status: status,
      deadline: deadline,
      remindDeadline: remindDeadline,
      createdAt: now,
      updatedAt: now,
      doneAt: status.isDone ? now : null,
    );
  }

  bool get hasBlocker => blocker.trim().isNotEmpty;

  Task copyWith({
    String? title,
    String? description,
    String? context,
    String? blocker,
    String? direction,
    TaskStatus? status,
    Deadline? deadline,
    bool clearDeadline = false,
    bool? remindDeadline,
    DateTime? doneAt,
    bool clearDoneAt = false,
  }) {
    final nextStatus = status ?? this.status;
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      context: context ?? this.context,
      blocker: blocker ?? this.blocker,
      direction: direction ?? this.direction,
      status: nextStatus,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      remindDeadline: remindDeadline ?? this.remindDeadline,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      doneAt: clearDoneAt
          ? null
          : (doneAt ??
              (nextStatus.isDone ? (this.doneAt ?? DateTime.now()) : null)),
    );
  }

  /// Chuyển sang trạng thái kế tiếp trong vòng todo -> doing -> done.
  Task cycleStatus() => copyWith(
        status: status.next,
        clearDoneAt: !status.next.isDone,
      );
}
