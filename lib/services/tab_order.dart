import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../db/app_db.dart';
import 'l10n.dart';

/// Định danh cố định của từng tab (không đổi khi đổi ngôn ngữ / thứ tự).
class TabDef {
  final String id;
  final IconData icon;
  const TabDef(this.id, this.icon);

  String get label => L10n.t('tab_$id');
}

class TabOrder {
  static const List<TabDef> all = [
    TabDef('tasks', Icons.checklist),
    TabDef('pomodoro', Icons.timer),
    TabDef('saves', Icons.save),
    TabDef('ideas', Icons.lightbulb_outline),
    TabDef('journal', Icons.edit_note),
    TabDef('schedule', Icons.calendar_month),
    TabDef('report', Icons.summarize),
  ];

  static const List<String> defaultOrder = [
    'tasks', 'pomodoro', 'saves', 'ideas', 'journal', 'schedule', 'report',
  ];

  /// Thứ tự hiện tại; đổi -> app rebuild thanh điều hướng.
  static final ValueNotifier<List<String>> order =
      ValueNotifier<List<String>>(List.of(defaultOrder));

  static TabDef defOf(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static Future<void> load() async {
    final saved = await AppDb.instance.getSetting('tab_order');
    if (saved == null || saved.trim().isEmpty) return;
    final ids = saved.split(',').where((e) => e.trim().isNotEmpty).toList();
    // Bỏ id lạ, bổ sung tab mới (khi app cập nhật thêm tab).
    final valid = ids.where((id) => defaultOrder.contains(id)).toList();
    for (final id in defaultOrder) {
      if (!valid.contains(id)) valid.add(id);
    }
    order.value = valid;
  }

  static Future<void> save(List<String> ids) async {
    order.value = List.of(ids);
    await AppDb.instance.setSetting('tab_order', ids.join(','));
  }
}

/// Dialog: sửa thứ tự tab bằng mũi tên lên/xuống hoặc kéo thả, rồi Lưu.
class TabOrderDialog extends StatefulWidget {
  const TabOrderDialog({super.key});

  @override
  State<TabOrderDialog> createState() => _TabOrderDialogState();
}

class _TabOrderDialogState extends State<TabOrderDialog> {
  late List<String> _ids;

  @override
  void initState() {
    super.initState();
    _ids = List.of(TabOrder.order.value);
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _ids.length) return;
    setState(() {
      final item = _ids.removeAt(index);
      _ids.insert(target, item);
    });
  }

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
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _ids.length,
                onReorder: (oldI, newI) {
                  setState(() {
                    if (newI > oldI) newI -= 1;
                    final item = _ids.removeAt(oldI);
                    _ids.insert(newI, item);
                  });
                },
                itemBuilder: (_, i) {
                  final def = TabOrder.defOf(_ids[i]);
                  return Card(
                    key: ValueKey(def.id),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: Icon(def.icon, color: const Color(0xFF2E5AAC)),
                      title: Text('${i + 1}. ${def.label}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: L10n.t('move_up'),
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            onPressed:
                                i == 0 ? null : () => _move(i, -1),
                          ),
                          IconButton(
                            tooltip: L10n.t('move_down'),
                            icon: const Icon(Icons.arrow_downward, size: 20),
                            onPressed: i == _ids.length - 1
                                ? null
                                : () => _move(i, 1),
                          ),
                          ReorderableDragStartListener(
                            index: i,
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
          onPressed: () =>
              setState(() => _ids = List.of(TabOrder.defaultOrder)),
          child: Text(L10n.t('reset_default')),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.t('cancel'))),
        FilledButton(
          onPressed: () async {
            await TabOrder.save(_ids);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(L10n.t('save')),
        ),
      ],
    );
  }
}
