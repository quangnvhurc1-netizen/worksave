import 'package:flutter/material.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/schedule_item.dart';
import '../../domain/models/settings.dart';
import '../../services/celebration.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Xem và quản lý các việc của một ngày.
class DayScheduleDialog extends StatefulWidget {
  const DayScheduleDialog({
    super.key,
    required this.date,
    required this.reminder,
  });

  final DateTime date;
  final ReminderSettings reminder;

  @override
  State<DayScheduleDialog> createState() => _DayScheduleDialogState();
}

class _DayScheduleDialogState extends State<DayScheduleDialog> {
  final _input = TextEditingController();
  ClockTime? _newTime;
  List<ScheduleItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await Repos.schedules
        .onDate(widget.date, widget.reminder.dayStart);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _add() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    await Repos.schedules.add(ScheduleItem(
      date: widget.date,
      time: _newTime,
      content: content,
    ));
    _input.clear();
    setState(() => _newTime = null);
    await _load();
  }

  Future<void> _toggleConfirmed(ScheduleItem item) async {
    final id = item.id;
    if (id == null) return;
    await Repos.schedules.setConfirmed(id, confirmed: !item.confirmed);
    if (!item.confirmed) {
      Celebration.instance.fire(L10n.t2('praise_task', {'t': item.content}));
    }
    await _load();
  }

  Future<void> _toggleRemind(ScheduleItem item) async {
    final id = item.id;
    if (id == null) return;
    await Repos.schedules.setRemind(id, remind: !item.remind);
    await _load();
  }

  /// Chỉ sửa được mục nhập tay. Mục sinh từ deadline của task phải sửa ở tab
  /// Task để hai nơi không lệch dữ liệu — nên nút sửa đơn giản là không bật.
  Future<void> _edit(ScheduleItem item) async {
    final updated = await showDialog<ScheduleItem>(
      context: context,
      builder: (_) => _EditScheduleItemDialog(item: item),
    );
    if (updated == null) return;
    await Repos.schedules.update(updated);
    await _load();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: L10n.t('pick_time_help'),
    );
    setState(() => _newTime =
        picked == null ? null : ClockTime(picked.hour, picked.minute));
  }

  String _subtitleFor(ScheduleItem item) {
    if (item.confirmed) return L10n.t('confirmed_done');
    if (!item.remind) return L10n.t('remind_muted');
    final time = item.effectiveTime(widget.reminder.dayStart).format();
    return '$time · ${L10n.t2('item_nag_time', {
          'lead': '${widget.reminder.leadTime.inMinutes}',
          'nag': '${widget.reminder.nagInterval.inMinutes}',
        })}';
  }

  @override
  Widget build(BuildContext context) {
    final weekdayNames = [
      'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật',
    ];

    return AlertDialog(
      title: Text(
          '${weekdayNames[widget.date.weekday - 1]}, ${formatDate(widget.date)}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: L10n.t('day_hint'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(_newTime?.format() ?? L10n.t('all_day')),
                  onPressed: _pickTime,
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(L10n.t('add')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(L10n.t('no_day_items'),
                    style: const TextStyle(color: Colors.black54)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in _items)
                      ListTile(
                        dense: true,
                        leading: IconButton(
                          tooltip: item.confirmed
                              ? L10n.t('unconfirm_tooltip')
                              : L10n.t('confirm_done_tooltip'),
                          icon: Icon(
                            item.confirmed
                                ? Icons.check_circle
                                : Icons.alarm_on,
                            size: 22,
                            color: item.confirmed
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          onPressed: () => _toggleConfirmed(item),
                        ),
                        title: Text(
                          '${item.effectiveTime(widget.reminder.dayStart).format()}'
                          ' — ${item.content}',
                          style: TextStyle(
                            decoration: item.confirmed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (item.isFromTask)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Tooltip(
                                  message: L10n.t('edit_in_task'),
                                  child: const Icon(Icons.lock_outline,
                                      size: 12, color: Colors.black38),
                                ),
                              ),
                            Expanded(
                              child: Text(_subtitleFor(item),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        onTap: item.isFromTask ? null : () => _edit(item),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: item.remind
                                  ? L10n.t('mute_tooltip')
                                  : L10n.t('unmute_tooltip'),
                              icon: Icon(
                                item.remind
                                    ? Icons.notifications_active
                                    : Icons.notifications_off,
                                size: 20,
                                color: item.remind
                                    ? AppColors.primary
                                    : Colors.black38,
                              ),
                              onPressed: () => _toggleRemind(item),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                final id = item.id;
                                if (id == null) return;
                                await Repos.schedules.delete(id);
                                await _load();
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('close'))),
      ],
    );
  }
}

/// Sửa nội dung / ngày / giờ của một mục nhập tay.
class _EditScheduleItemDialog extends StatefulWidget {
  const _EditScheduleItemDialog({required this.item});
  final ScheduleItem item;

  @override
  State<_EditScheduleItemDialog> createState() =>
      _EditScheduleItemDialogState();
}

class _EditScheduleItemDialogState extends State<_EditScheduleItemDialog> {
  late final TextEditingController _content =
      TextEditingController(text: widget.item.content);
  late DateTime _date = widget.item.date;
  late ClockTime? _time = widget.item.time;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _content.text.trim();
    if (content.isEmpty) return;
    final moved = _date != widget.item.date || _time != widget.item.time;
    Navigator.pop(
      context,
      widget.item.copyWith(
        content: content,
        date: _date,
        time: _time,
        clearTime: _time == null,
        confirmed: moved ? false : widget.item.confirmed,
        clearLastNotified: moved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('edit')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('${L10n.t('date')}: '),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(formatDate(_date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(_time?.format() ?? L10n.t('all_day')),
                  onPressed: () async {
                    final current = _time;
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: current == null
                          ? const TimeOfDay(hour: 9, minute: 0)
                          : TimeOfDay(
                              hour: current.hour, minute: current.minute),
                    );
                    if (picked != null) {
                      setState(() =>
                          _time = ClockTime(picked.hour, picked.minute));
                    }
                  },
                ),
                if (_time != null)
                  IconButton(
                    tooltip: L10n.t('remove_time'),
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _time = null),
                  ),
              ],
            ),
            TextField(
              controller: _content,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(onPressed: _submit, child: Text(L10n.t('save'))),
      ],
    );
  }
}
