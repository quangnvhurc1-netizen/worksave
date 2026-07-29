import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../services/l10n.dart';
import '../../services/tab_order_service.dart';
import '../theme.dart';

/// Sắp xếp lại thứ tự tab bằng mũi tên hoặc kéo thả.
class TabOrderDialog extends StatefulWidget {
  const TabOrderDialog({super.key});

  @override
  State<TabOrderDialog> createState() => _TabOrderDialogState();
}

class _TabOrderDialogState extends State<TabOrderDialog> {
  late List<AppTab> _tabs = List.of(TabOrderService.order.value);

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _tabs.length) return;
    setState(() => _tabs.insert(target, _tabs.removeAt(index)));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
      _tabs.insert(adjusted, _tabs.removeAt(oldIndex));
    });
  }

  static IconData _iconFor(AppTab tab) => switch (tab) {
        AppTab.tasks => Icons.checklist,
        AppTab.pomodoro => Icons.timer,
        AppTab.saves => Icons.save,
        AppTab.ideas => Icons.lightbulb_outline,
        AppTab.journal => Icons.edit_note,
        AppTab.schedule => Icons.calendar_month,
        AppTab.attendance => Icons.fingerprint,
        AppTab.report => Icons.summarize,
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('tab_order_title')),
      content: SizedBox(
        width: 460,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.t('tab_order_help'),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _tabs.length,
                onReorder: _reorder,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  return Card(
                    key: ValueKey(tab),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading:
                          Icon(_iconFor(tab), color: AppColors.primary),
                      title: Text('${index + 1}. ${L10n.t(tab.l10nKey)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: L10n.t('move_up'),
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            onPressed:
                                index == 0 ? null : () => _move(index, -1),
                          ),
                          IconButton(
                            tooltip: L10n.t('move_down'),
                            icon: const Icon(Icons.arrow_downward, size: 20),
                            onPressed: index == _tabs.length - 1
                                ? null
                                : () => _move(index, 1),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.drag_handle,
                                  color: Colors.black38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _tabs = List.of(AppTab.values)),
          child: Text(L10n.t('reset_default')),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.t('cancel'))),
        FilledButton(
          onPressed: () async {
            await TabOrderService.save(_tabs);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(L10n.t('save')),
        ),
      ],
    );
  }
}
