import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../services/l10n.dart';
import '../../services/notification_center.dart';
import '../theme.dart';

/// Logo WorkSave kiêm nút thông báo: badge số chưa đọc đính ngay trên logo,
/// bấm vào ra bảng danh sách.
///
/// Quan trọng: [MenuAnchor] KHÔNG được nằm trong một builder lắng nghe danh
/// sách thông báo. Nếu anchor bị dựng lại trong lúc menu đang mở (đánh dấu đã
/// đọc, hoặc có thông báo mới tới), overlay và anchor lệch nhau và app treo.
/// Nên chỉ badge và nội dung bảng mới lắng nghe thay đổi.
class NotificationMenu extends StatefulWidget {
  const NotificationMenu({super.key, required this.onOpenTab});

  final ValueChanged<AppTab> onOpenTab;

  @override
  State<NotificationMenu> createState() => _NotificationMenuState();
}

class _NotificationMenuState extends State<NotificationMenu> {
  static const double _logoSize = 32;

  /// Giữ ở State để bảng thông báo đóng được menu mà không đụng tới
  /// Navigator — MenuAnchor dùng overlay, không phải route.
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(8, 0),
      style: const MenuStyle(
        padding: WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
      ),
      menuChildren: [
        _NotificationPanel(onOpenTab: widget.onOpenTab, menu: _menu),
      ],
      builder: (context, controller, child) => Tooltip(
        message: L10n.t('notif_center'),
        child: InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.md),
            child: const _LogoWithBadge(size: _logoSize),
          ),
        ),
      ),
    );
  }
}

/// Logo kèm badge số chưa đọc. Chỉ phần này rebuild khi danh sách đổi.
class _LogoWithBadge extends StatelessWidget {
  const _LogoWithBadge({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo =
        Icon(Icons.videogame_asset, size: size, color: AppColors.primary);

    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationCenter.instance.items,
      builder: (context, entries, child) {
        final unread = entries.where((entry) => !entry.read).length;
        if (unread == 0) return child ?? logo;
        return Badge(label: Text('$unread'), child: child ?? logo);
      },
      child: logo,
    );
  }
}

/// Nội dung bảng thông báo.
class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.onOpenTab, required this.menu});

  final ValueChanged<AppTab> onOpenTab;
  final MenuController menu;

  static const double _maxPanelHeight = 380;
  static const double _panelWidth = 360;

  static IconData _iconFor(NotificationKind kind) => switch (kind) {
        NotificationKind.schedule => Icons.event,
        NotificationKind.attendance => Icons.fingerprint,
        NotificationKind.pomodoro => Icons.timer,
        NotificationKind.info => Icons.info_outline,
      };

  /// Đóng menu TRƯỚC khi đổi dữ liệu, để overlay không bị dựng lại giữa chừng.
  void _handleTap(AppNotification entry) {
    menu.close();
    NotificationCenter.instance.markRead(entry.id);
    final target = entry.targetTab;
    if (target != null) onOpenTab(target);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _panelWidth,
      child: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationCenter.instance.items,
        builder: (context, entries, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(entries.isNotEmpty),
            const Divider(height: 1),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(L10n.t('notif_empty'),
                    style: const TextStyle(color: Colors.black54)),
              )
            else
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: _maxPanelHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _buildTile(entries[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasEntries) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          Text(L10n.t('notif_center'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (hasEntries) ...[
            TextButton(
              onPressed: NotificationCenter.instance.markAllRead,
              child: Text(L10n.t('notif_mark_all')),
            ),
            TextButton(
              onPressed: () {
                menu.close();
                NotificationCenter.instance.clear();
              },
              child: Text(L10n.t('notif_clear')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(AppNotification entry) {
    return ListTile(
      dense: true,
      tileColor: entry.read ? null : AppColors.infoSurface,
      leading: Icon(_iconFor(entry.kind),
          size: 20,
          color: entry.read ? Colors.black38 : AppColors.primary),
      title: Text(
        entry.title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: entry.read ? FontWeight.normal : FontWeight.w600,
        ),
      ),
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
  }
}
