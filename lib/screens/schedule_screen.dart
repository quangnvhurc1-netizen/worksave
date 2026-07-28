import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';
import '../services/celebration.dart';

/// Lịch dạng lưới tháng kiểu Outlook: mỗi ngày 1 ô vuông, sự kiện hiện ngay
/// trong ô. Điều hướng được về quá khứ và tương lai không giới hạn.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _month; // luôn là ngày 1 của tháng đang xem
  List<ScheduleItem> _items = [];

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _monthNames = [
    'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
    'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    final items = await AppDb.instance.getSchedules();
    if (!mounted) return;
    setState(() => _items = items);
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Map<String, List<ScheduleItem>> get _byDate {
    final map = <String, List<ScheduleItem>>{};
    for (final s in _items) {
      map.putIfAbsent(_key(s.date), () => []).add(s);
    }
    return map;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 42 ô (6 tuần) bắt đầu từ thứ 2 của tuần chứa ngày 1.
  List<DateTime> _gridDays() {
    final first = _month;
    final lead = first.weekday - 1; // T2 = 1
    final start = first.subtract(Duration(days: lead));
    return List.generate(
        42, (i) => DateTime(start.year, start.month, start.day + i));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: L10n.t('jump_month'),
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  // ---------- Dialog quản lý 1 ngày ----------
  Future<void> _openDay(DateTime date) async {
    await showDialog(
      context: context,
      builder: (_) => _DayDialog(date: date),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final byDate = _byDate;
    final today = DateTime.now();
    final days = _gridDays();

    return Column(
      children: [
        // ---- Thanh điều hướng tháng ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(L10n.t('schedule_title'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              OutlinedButton(
                  onPressed: _goToday, child: Text(L10n.t('today'))),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: L10n.t('prev_month'),
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left)),
              IconButton(
                  tooltip: L10n.t('next_month'),
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right)),
              const SizedBox(width: 4),
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${_monthNames[_month.month - 1]} năm ${_month.year}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(),
              Text(L10n.t('schedule_hint'),
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
        // ---- Hàng tên thứ ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _weekdays
                .map((w) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        child: Text(
                          w,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: w == 'T7' || w == 'CN'
                                ? Colors.redAccent
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // ---- Lưới 6 tuần x 7 ngày ----
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: List.generate(6, (row) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (col) {
                      final d = days[row * 7 + col];
                      final inMonth = d.month == _month.month;
                      final isToday = _sameDay(d, today);
                      final events = byDate[_key(d)] ?? const [];
                      final isWeekend = col >= 5;

                      return Expanded(
                        child: InkWell(
                          onTap: () => _openDay(d),
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xFFE8F0FE)
                                  : !inMonth
                                      ? const Color(0xFFFAFAFA)
                                      : isWeekend
                                          ? const Color(0xFFFDF7F7)
                                          : Colors.white,
                              border: Border.all(
                                color: isToday
                                    ? const Color(0xFF2E5AAC)
                                    : Colors.black12,
                                width: isToday ? 1.5 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: isToday
                                          ? const BoxDecoration(
                                              color: Color(0xFF2E5AAC),
                                              shape: BoxShape.circle,
                                            )
                                          : null,
                                      child: Text(
                                        '${d.day}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isToday
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isToday
                                              ? Colors.white
                                              : !inMonth
                                                  ? Colors.black26
                                                  : isWeekend
                                                      ? Colors.redAccent
                                                      : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (events.isNotEmpty && !inMonth)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 2),
                                        child: Icon(Icons.circle,
                                            size: 6, color: Colors.black26),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Chips sự kiện (tối đa 3 + "+n")
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (_, __) {
                                      const maxShow = 3;
                                      final show =
                                          events.take(maxShow).toList();
                                      final more =
                                          events.length - show.length;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final e in show)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 2),
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 4,
                                                  vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: e.confirmed
                                                    ? const Color(0xFFE6E6E6)
                                                    : e.isFromTask
                                                        ? const Color(
                                                            0xFFFDE9E0)
                                                        : const Color(
                                                            0xFFDCE7F8),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                border: Border(
                                                  left: BorderSide(
                                                      color: e.confirmed
                                                          ? Colors.grey
                                                          : e.isFromTask
                                                              ? const Color(
                                                                  0xFFD9534F)
                                                              : const Color(
                                                                  0xFF2E5AAC),
                                                      width: 2.5),
                                                ),
                                              ),
                                              child: Text(
                                                '${e.time ?? ''}${e.time != null ? ' ' : ''}${e.content}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  decoration: e.confirmed
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  color: inMonth
                                                      ? Colors.black87
                                                      : Colors.black38,
                                                ),
                                              ),
                                            ),
                                          if (more > 0)
                                            Text(
                                                L10n.t2('more_items',
                                                    {'n': '$more'}),
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black45)),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog xem/thêm/sửa/xóa các việc của 1 ngày.
class _DayDialog extends StatefulWidget {
  const _DayDialog({required this.date});
  final DateTime date;

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  final _input = TextEditingController();
  TimeOfDay? _newTime;
  List<ScheduleItem> _dayItems = [];
  String _dayStart = AppDb.defaultDayStart;
  int _lead = AppDb.defaultLeadMinutes;
  int _nag = AppDb.defaultNagMinutes;

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
    final all = await AppDb.instance.getSchedules();
    final ds = await AppDb.instance.dayStartTime;
    final ld = await AppDb.instance.leadMinutes;
    final ng = await AppDb.instance.nagMinutes;
    if (!mounted) return;
    _dayStart = ds;
    _lead = ld;
    _nag = ng;
    final items = all
        .where((s) =>
            s.date.year == widget.date.year &&
            s.date.month == widget.date.month &&
            s.date.day == widget.date.day)
        .toList()
      ..sort((a, b) =>
          a.dueAtWith(_dayStart).compareTo(b.dueAtWith(_dayStart)));
    setState(() => _dayItems = items);
  }

  Future<void> _add() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    await AppDb.instance.insertSchedule(ScheduleItem(
      date: widget.date,
      time: _newTime == null
          ? null
          : '${_newTime!.hour.toString().padLeft(2, '0')}:${_newTime!.minute.toString().padLeft(2, '0')}',
      content: content,
    ));
    _input.clear();
    setState(() => _newTime = null);
    _load();
  }

  Future<void> _edit(ScheduleItem item) async {
    if (item.isFromTask) {
      // Deadline từ task: sửa nội dung/ngày ở tab Task để không lệch dữ liệu.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.t('edit_in_task')),
      ));
      return;
    }
    final c = TextEditingController(text: item.content);
    DateTime date = item.date;
    TimeOfDay? time = item.time == null
        ? null
        : TimeOfDay(
            hour: int.tryParse(item.time!.split(':')[0]) ?? 0,
            minute: int.tryParse(item.time!.split(':')[1]) ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
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
                      label: Text(fmtDate(date)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setD(() => date = picked);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(time == null ? L10n.t('all_day') : time!.format(ctx)),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime:
                              time ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (t != null) setD(() => time = t);
                      },
                    ),
                    if (time != null)
                      IconButton(
                        tooltip: L10n.t('remove_time'),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setD(() => time = null),
                      ),
                  ],
                ),
                TextField(
                  controller: c,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(L10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(L10n.t('save'))),
          ],
        ),
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      final newTime = time == null
          ? null
          : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
      final changed = !(item.date.year == date.year &&
              item.date.month == date.month &&
              item.date.day == date.day) ||
          item.time != newTime;
      item.content = c.text.trim();
      if (changed) {
        item.confirmed = false; // đổi lịch -> nhắc lại
        item.lastNotifiedAt = null;
      }
      item.date = date;
      item.time = newTime;
      await AppDb.instance.updateSchedule(item);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wd = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7',
        'Chủ nhật'][widget.date.weekday - 1];
    return AlertDialog(
      title: Text('$wd, ${fmtDate(widget.date)}'),
      content: SizedBox(
        width: 520,
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
                  label: Text(_newTime == null
                      ? L10n.t('all_day')
                      : _newTime!.format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                      helpText: 'Giờ nhắc (bấm Hủy = cả ngày)',
                    );
                    setState(() => _newTime = t);
                  },
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(L10n.t('add')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_dayItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(L10n.t('no_day_items'),
                    style: const TextStyle(color: Colors.black54)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: _dayItems
                      .map((s) => ListTile(
                            dense: true,
                            leading: Tooltip(
                              message: s.confirmed
                                  ? L10n.t('unconfirm_tooltip')
                                  : L10n.t('confirm_done_tooltip'),
                              child: IconButton(
                                icon: Icon(
                                  s.confirmed
                                      ? Icons.check_circle
                                      : Icons.alarm_on,
                                  size: 22,
                                  color: s.confirmed
                                      ? Colors.green
                                      : const Color(0xFFD9534F),
                                ),
                                onPressed: () async {
                                  if (s.id != null) {
                                    await AppDb.instance.confirmSchedule(
                                        s.id!,
                                        confirmed: !s.confirmed);
                                    if (!s.confirmed) {
                                      Celebration.instance
                                          .fire('Đã xong "${s.content}"!');
                                    }
                                    _load();
                                  }
                                },
                              ),
                            ),
                            title: Text(
                              '${s.time ?? _dayStart} — ${s.content}',
                              style: TextStyle(
                                decoration: s.confirmed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              s.confirmed
                                  ? L10n.t('confirmed_done')
                                  : !s.remind
                                      ? L10n.t('remind_muted')
                                      : '${s.time ?? _dayStart} · '
                                          '${L10n.t2('item_nag_time', {
                                              'lead': '$_lead',
                                              'nag': '$_nag'
                                            })}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () => _edit(s),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: s.remind
                                      ? L10n.t('mute_tooltip')
                                      : L10n.t('unmute_tooltip'),
                                  icon: Icon(
                                    s.remind
                                        ? Icons.notifications_active
                                        : Icons.notifications_off,
                                    size: 20,
                                    color: s.remind
                                        ? const Color(0xFF2E5AAC)
                                        : Colors.black38,
                                  ),
                                  onPressed: () async {
                                    if (s.id != null) {
                                      await AppDb.instance.setScheduleRemind(
                                          s.id!, !s.remind);
                                      _load();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  onPressed: () async {
                                    if (s.id != null) {
                                      await AppDb.instance
                                          .deleteSchedule(s.id!);
                                      _load();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ))
                      .toList(),
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
