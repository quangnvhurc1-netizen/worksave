import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../services/l10n.dart';
import '../../services/notification_center.dart';
import '../theme.dart';

/// Chuông thông báo: badge số chưa đọc, bấm ra bảng danh sách gọn bên cạnh
/// thanh điều hướng — thay cho snackbar chắn ngang màn hình.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.onOpenTab});

  final ValueChanged<AppTab> onOpenTab;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final MenuController _menu = MenuController();

  static IconData _iconFor(NotificationKind kind) => switch (kind) {
        NotificationKind.schedule => Icons.event,
        NotificationKind.attendance => Icons.fingerprint,
        NotificationKind.pomodoro => Icons.timer,
        NotificationKind.info => Icons.info_outline,
      };

  void _handleTap(AppNotification entry) {
    NotificationCenter.instance.markRead(entry.id);
    _menu.close();
    final target = entry.targetTab;
    if (target != null) widget.onOpenTab(target);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationCenter.instance.items,
      builder: (context, entries, _) {
        final unread = entries.where((entry) => !entry.read).length;

        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(8, 0),
          style: const MenuStyle(
            padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
          ),
          menuChildren: [_buildPanel(entries)],
          builder: (context, controller, child) => IconButton(
            tooltip: L10n.t('notif_center'),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: unread == 0
                ? const Icon(Icons.notifications_none)
                : Badge(
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_active),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(List<AppNotification> entries) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
            child: Row(
              children: [
                Text(L10n.t('notif_center'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (entries.isNotEmpty) ...[
                  TextButton(
                    onPressed: NotificationCenter.instance.markAllRead,
                    child: Text(L10n.t('notif_mark_all')),
                  ),
                  TextButton(
                    onPressed: () {
                      NotificationCenter.instance.clear();
                      _menu.close();
                    },
                    child: Text(L10n.t('notif_clear')),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(L10n.t('notif_empty'),
                  style: const TextStyle(color: Colors.black54)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    dense: true,
                    tileColor:
                        entry.read ? null : AppColors.infoSurface,
                    leading: Icon(_iconFor(entry.kind),
                        size: 20,
                        color: entry.read
                            ? Colors.black38
                            : AppColors.primary),
                    title: Text(entry.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              entry.read ? FontWeight.normal : FontWeight.w600,
                        )),
                    subtitle: Text(
                      entry.body.isEmpty
                          ? formatTime(entry.createdAt)
                          : '${formatTime(entry.createdAt)} · ${entry.body}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _handleTap(entry),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
