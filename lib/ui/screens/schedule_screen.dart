import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/schedule_item.dart';
import '../../domain/models/settings.dart';
import '../../services/l10n.dart';
import '../dialogs/day_schedule_dialog.dart';
import '../theme.dart';

/// Lịch tháng dạng lưới kiểu Outlook.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const List<String> _weekdayLabels = [
    'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN',
  ];
  static const int _weeksShown = 6;
  static const int _daysPerWeek = 7;

  late DateTime _month;

  /// Dữ liệu đã gom sẵn theo ngày và lưới 42 ô, tính một lần mỗi khi tải hoặc
  /// đổi tháng — build chỉ việc vẽ.
  Map<String, List<ScheduleItem>> _itemsByDate = const {};
  List<DateTime> _gridDays = const [];
  ReminderSettings _reminder = ReminderSettings.defaults;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  /// 42 ô bắt đầu từ thứ 2 của tuần chứa ngày 1.
  static List<DateTime> _buildGrid(DateTime month) {
    final start = month.mondayOfWeek;
    return List.generate(
      _weeksShown * _daysPerWeek,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
  }

  /// Chỉ tải đúng khoảng ngày đang hiển thị, không nạp cả bảng lịch.
  Future<void> _load() async {
    final reminder = await Repos.settings.reminderSettings();
    final days = _buildGrid(_month);
    final grouped = await Repos.schedules
        .groupedBetween(days.first, days.last, reminder.dayStart);
    if (!mounted) return;
    setState(() {
      _reminder = reminder;
      _gridDays = days;
      _itemsByDate = grouped;
    });
  }

  void _goToMonth(DateTime month) {
    setState(() => _month = DateTime(month.year, month.month));
    unawaited(_load());
  }

  void _shiftMonth(int delta) =>
      _goToMonth(DateTime(_month.year, _month.month + delta));

  void _goToToday() => _goToMonth(DateTime.now());

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: L10n.t('jump_month'),
    );
    if (picked == null) return;
    _goToMonth(picked);
  }

  Future<void> _openDay(DateTime date) async {
    await showDialog<void>(
      context: context,
      builder: (_) => DayScheduleDialog(date: date, reminder: _reminder),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _itemsByDate;
    final days = _gridDays;
    final today = DateTime.now();
    if (days.isEmpty) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildToolbar(),
        _buildWeekdayHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                for (var week = 0; week < _weeksShown; week++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var day = 0; day < _daysPerWeek; day++)
                          Expanded(
                            child: _DayCell(
                              date: days[week * _daysPerWeek + day],
                              items: grouped[days[week * _daysPerWeek + day]
                                      .toIsoDate()] ??
                                  const [],
                              isCurrentMonth:
                                  days[week * _daysPerWeek + day].month ==
                                      _month.month,
                              isToday: days[week * _daysPerWeek + day]
                                  .isSameDay(today),
                              isWeekend: day >= 5,
                              onTap: () =>
                                  _openDay(days[week * _daysPerWeek + day]),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          ScreenTitle(L10n.t('schedule_title')),
          const SizedBox(width: AppSpacing.lg),
          OutlinedButton(
              onPressed: _goToToday, child: Text(L10n.t('today'))),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: L10n.t('prev_month'),
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: L10n.t('next_month'),
            onPressed: () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Text(
                L10n.t2('month_year',
                    {'m': '${_month.month}', 'y': '${_month.year}'}),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Spacer(),
          Text(L10n.t('schedule_hint'),
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < _weekdayLabels.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  _weekdayLabels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: i >= 5 ? Colors.redAccent : Colors.black87,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một ô ngày trên lưới lịch.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.items,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isWeekend,
    required this.onTap,
  });

  final DateTime date;
  final List<ScheduleItem> items;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isWeekend;
  final VoidCallback onTap;

  Color get _background {
    if (isToday) return AppColors.infoSurface;
    if (!isCurrentMonth) return AppColors.outsideMonthSurface;
    return isWeekend ? AppColors.weekendSurface : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: _background,
          border: Border.all(
            color: isToday ? AppColors.primary : Colors.black12,
            width: isToday ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDayNumber(),
            const SizedBox(height: 2),
            Expanded(
              // Ô ngày cuộn được: nhiều việc thì lăn chuột trong ô để xem
              // hết, thay vì cắt bớt và làm mất thông tin.
              child: Scrollbar(
                thickness: 3,
                radius: const Radius.circular(2),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ScheduleChip(
                    item: items[index],
                    isCurrentMonth: isCurrentMonth,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayNumber() {
    final Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (!isCurrentMonth) {
      textColor = Colors.black26;
    } else {
      textColor = isWeekend ? Colors.redAccent : Colors.black87;
    }

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: isToday
          ? const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle)
          : null,
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.item, required this.isCurrentMonth});

  final ScheduleItem item;
  final bool isCurrentMonth;

  Color get _fill {
    if (item.confirmed) return AppColors.doneChip;
    return item.isFromTask ? AppColors.taskChip : AppColors.scheduleChip;
  }

  Color get _accent {
    if (item.confirmed) return Colors.grey;
    return item.isFromTask ? AppColors.danger : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final prefix = item.time == null ? '' : '${item.time!.format()} ';
    return Container(
      height: 17,
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: _accent, width: 2.5)),
      ),
      child: Text(
        '$prefix${item.content}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          decoration: item.confirmed ? TextDecoration.lineThrough : null,
          color: isCurrentMonth ? Colors.black87 : Colors.black38,
        ),
      ),
    );
  }
}
