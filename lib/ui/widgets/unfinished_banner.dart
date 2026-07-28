import 'package:flutter/material.dart';

import '../../domain/models/task.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Nhắc nhở còn task chưa chuyển sang Done.
class UnfinishedTasksBanner extends StatelessWidget {
  const UnfinishedTasksBanner({
    super.key,
    required this.tasks,
    required this.onView,
    required this.onDismiss,
  });

  final List<Task> tasks;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final preview = tasks.take(_previewCount).map((t) => t.title).join(', ');
    final suffix = tasks.length > _previewCount ? '…' : '';

    return MaterialBanner(
      backgroundColor: AppColors.warningSurface,
      leading:
          const Icon(Icons.notifications_active, color: Colors.orange),
      content: Text(L10n.t2('unfinished_banner', {
        'n': '${tasks.length}',
        'list': '$preview$suffix',
      })),
      actions: [
        TextButton(onPressed: onView, child: Text(L10n.t('view_tasks'))),
        TextButton(onPressed: onDismiss, child: Text(L10n.t('hide'))),
      ],
    );
  }
}
