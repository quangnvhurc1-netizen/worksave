import 'package:flutter/foundation.dart';

import '../domain/enums.dart';
import '../domain/models/app_notification.dart';

/// Hộp thư thông báo trong app: mọi lời nhắc đều đổ về đây thay vì bung
/// snackbar chắn ngang màn hình. Giao diện chỉ cần lắng nghe [items].
class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  /// Giữ lịch sử vừa đủ để xem lại, không phình bộ nhớ.
  static const int _maxEntries = 50;

  final ValueNotifier<List<AppNotification>> items =
      ValueNotifier<List<AppNotification>>(const []);

  int _nextId = 1;

  int get unreadCount => items.value.where((entry) => !entry.read).length;

  /// Thêm một thông báo. Trùng tiêu đề với thông báo chưa đọc gần nhất cùng
  /// loại thì chỉ làm mới thời gian, tránh spam khi nhắc lặp mỗi 10 phút.
  void push({
    required NotificationKind kind,
    required String title,
    String body = '',
    AppTab? targetTab,
  }) {
    final current = List<AppNotification>.of(items.value);
    final duplicateIndex = current.indexWhere((entry) =>
        !entry.read && entry.kind == kind && entry.title == title);

    if (duplicateIndex >= 0) {
      final existing = current.removeAt(duplicateIndex);
      current.insert(
        0,
        AppNotification(
          id: existing.id,
          kind: existing.kind,
          title: existing.title,
          body: body.isEmpty ? existing.body : body,
          targetTab: existing.targetTab,
        ),
      );
    } else {
      current.insert(
        0,
        AppNotification(
          id: _nextId++,
          kind: kind,
          title: title,
          body: body,
          targetTab: targetTab,
        ),
      );
    }

    items.value = current.length > _maxEntries
        ? current.sublist(0, _maxEntries)
        : current;
  }

  void markRead(int id) {
    items.value = [
      for (final entry in items.value)
        entry.id == id ? entry.copyWith(read: true) : entry,
    ];
  }

  void markAllRead() {
    items.value = [
      for (final entry in items.value) entry.copyWith(read: true),
    ];
  }

  void clear() => items.value = const [];
}
