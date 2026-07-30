import 'package:meta/meta.dart';

import '../enums.dart';

/// Một dòng trong hộp thư thông báo của app (không lưu xuống DB — chỉ tồn tại
/// trong phiên làm việc, giống chuông thông báo của web).
@immutable
class AppNotification {
  final int id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Tab sẽ mở khi người dùng bấm vào thông báo.
  final AppTab? targetTab;
  final bool read;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.targetTab,
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        targetTab: targetTab,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}
