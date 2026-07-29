import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/notes.dart';
import '../../domain/models/reminder.dart';
import '../../domain/models/task.dart';
import '../../services/l10n.dart';
import '../../services/reminder_service.dart';
import '../../services/tab_order_service.dart';
import '../dialogs/quick_capture_dialog.dart';
import '../dialogs/review_dialog.dart';
import '../dialogs/search_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../theme.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/unfinished_banner.dart';
import 'attendance_screen.dart';
import 'ideas_screen.dart';
import 'journal_screen.dart';
import 'pomodoro_screen.dart';
import 'report_screen.dart';
import 'saves_screen.dart';
import 'schedule_screen.dart';
import 'tasks_screen.dart';

/// Vỏ chính: thanh điều hướng, khay hệ thống, phím tắt, và điều phối
/// các dịch vụ nền. Logic nhắc lịch nằm ở [ReminderService], không ở đây.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WindowListener, TrayListener {
  static const String _trayIconPath = 'assets/tray_icon.ico';
  static const Duration _reviewCheckInterval = Duration(minutes: 1);

  static const String _menuShow = 'show';
  static const String _menuCapture = 'capture';
  static const String _menuExit = 'exit';

  AppTab _selectedTab = AppTab.tasks;
  List<Task> _unfinished = const [];
  bool _bannerDismissed = false;
  bool _dialogOpen = false;

  Timer? _reviewTimer;
  StreamSubscription<List<DueReminder>>? _reminderSubscription;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    TabOrderService.order.addListener(_onTabOrderChanged);
    L10n.language.addListener(_onLanguageChanged);

    unawaited(windowManager.setPreventClose(true));
    unawaited(_setUpTray());
    unawaited(_registerHotkey());

    ReminderService.instance.start();
    _reminderSubscription =
        ReminderService.instance.onRemindersFired.listen(_showReminderSnackBar);

    unawaited(_refreshUnfinished());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_showLatestCheckpoint()));

    unawaited(_maybeOpenReview());
    _reviewTimer = Timer.periodic(
        _reviewCheckInterval, (_) => unawaited(_maybeOpenReview()));
  }

  @override
  void dispose() {
    _reviewTimer?.cancel();
    unawaited(_reminderSubscription?.cancel() ?? Future<void>.value());
    ReminderService.instance.stop();
    TabOrderService.order.removeListener(_onTabOrderChanged);
    L10n.language.removeListener(_onLanguageChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  // ---------------- Trạng thái chung ----------------

  void _onTabOrderChanged() {
    if (mounted) setState(() {});
  }

  void _onLanguageChanged() {
    unawaited(_setUpTray());
    if (mounted) setState(() {});
  }

  Future<void> _refreshUnfinished() async {
    final tasks = await Repos.tasks.unfinished();
    if (!mounted) return;
    setState(() => _unfinished = tasks);
  }

  void _goToTab(AppTab tab) {
    if (mounted) setState(() => _selectedTab = tab);
  }

  // ---------------- Khay hệ thống & phím tắt ----------------

  Future<void> _setUpTray() async {
    try {
      await trayManager.setIcon(_trayIconPath);
      await trayManager.setToolTip(L10n.t('tray_tooltip'));
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: _menuShow, label: L10n.t('tray_show')),
        MenuItem(key: _menuCapture, label: L10n.t('tray_capture')),
        MenuItem.separator(),
        MenuItem(key: _menuExit, label: L10n.t('tray_exit')),
      ]));
    } on Object {
      // Không dựng được tray thì app vẫn chạy bình thường.
    }
  }

  Future<void> _registerHotkey() async {
    try {
      await hotKeyManager.register(
        HotKey(
          key: PhysicalKeyboardKey.space,
          modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) => unawaited(_openQuickCapture()),
      );
    } on Object {
      // Phím tắt bị app khác chiếm — vẫn ghi nhanh được từ menu tray.
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    // Bấm X = thu vào khay ẩn, không thoát, để nhắc lịch vẫn chạy.
    unawaited(windowManager.hide());
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuShow:
        unawaited(_showWindow());
      case _menuCapture:
        unawaited(_openQuickCapture());
      case _menuExit:
        unawaited(_quit());
    }
  }

  Future<void> _quit() async {
    ReminderService.instance.stop();
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  // ---------------- Hộp thoại ----------------

  Future<void> _showDialogOnce(Widget dialog) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showDialog<void>(context: context, builder: (_) => dialog);
    _dialogOpen = false;
  }

  Future<void> _openQuickCapture() async {
    await _showWindow();
    await _showDialogOnce(const QuickCaptureDialog());
  }

  Future<void> _openReview() async {
    await _showDialogOnce(const ReviewDialog());
    await _refreshUnfinished();
  }

  Future<void> _maybeOpenReview() async {
    if (_dialogOpen) return;

    final reviewTime = await Repos.settings.reviewTime();
    if (DateTime.now().isBefore(reviewTime.onDate(DateTime.now()))) return;
    if (await Repos.settings.isReviewDoneToday()) return;

    final pending = await Repos.tasks.unfinished();
    if (pending.isEmpty) {
      await Repos.settings.markReviewDoneToday();
      return;
    }

    await _showWindow();
    await _openReview();
  }

  Future<void> _showLatestCheckpoint() async {
    final checkpoint = await Repos.notes.latestCheckpoint();
    if (checkpoint == null || !mounted) return;
    await _showDialogOnce(_LatestCheckpointDialog(checkpoint: checkpoint));
  }

  void _showReminderSnackBar(List<DueReminder> reminders) {
    if (!mounted || reminders.isEmpty) return;
    final summary = reminders.map((r) => r.item.content).join(' · ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🔔 $summary'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: L10n.t('tab_schedule'),
        onPressed: () => _goToTab(AppTab.schedule),
      ),
    ));
  }

  // ---------------- Dựng giao diện ----------------

  Widget _pageFor(AppTab tab) => switch (tab) {
        AppTab.tasks => TasksScreen(onTasksChanged: _refreshUnfinished),
        AppTab.pomodoro => const PomodoroScreen(),
        AppTab.saves => const SavesScreen(),
        AppTab.ideas => const IdeasScreen(),
        AppTab.journal => const JournalScreen(),
        AppTab.schedule => const ScheduleScreen(),
        AppTab.attendance => const AttendanceScreen(),
        AppTab.report => const ReportScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final tabs = TabOrderService.order.value;
    final selectedIndex =
        tabs.contains(_selectedTab) ? tabs.indexOf(_selectedTab) : 0;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _buildNavigationRail(tabs, selectedIndex),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    if (_unfinished.isNotEmpty && !_bannerDismissed)
                      UnfinishedTasksBanner(
                        tasks: _unfinished,
                        onView: () {
                          setState(() => _bannerDismissed = true);
                          _goToTab(AppTab.tasks);
                        },
                        onDismiss: () =>
                            setState(() => _bannerDismissed = true),
                      ),
                    Expanded(child: _pageFor(tabs[selectedIndex])),
                  ],
                ),
              ),
            ],
          ),
          const CelebrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(List<AppTab> tabs, int selectedIndex) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _goToTab(tabs[index]),
      labelType: NavigationRailLabelType.all,
      leading: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Icon(Icons.videogame_asset,
                size: 32, color: AppColors.primary),
          ),
          IconButton(
            tooltip: L10n.t('search_tooltip'),
            icon: const Icon(Icons.search),
            onPressed: () => _showDialogOnce(const SearchDialog()),
          ),
          IconButton(
            tooltip: L10n.t('review_tooltip'),
            icon: const Icon(Icons.wb_twilight),
            onPressed: _openReview,
          ),
        ],
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: IconButton(
              tooltip: L10n.t('settings'),
              icon: const Icon(Icons.settings),
              onPressed: () => _showDialogOnce(const SettingsDialog()),
            ),
          ),
        ),
      ),
      destinations: [
        for (final tab in tabs)
          NavigationRailDestination(
            icon: Icon(_iconFor(tab)),
            label: Text(L10n.t(tab.l10nKey)),
          ),
      ],
    );
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
}

/// Hộp thoại "load game": hiện bản save gần nhất khi mở app.
class _LatestCheckpointDialog extends StatelessWidget {
  const _LatestCheckpointDialog({required this.checkpoint});
  final Checkpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.save, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text('${L10n.t('tab_saves')} — '
                  '${formatDateTime(checkpoint.createdAt)}')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(label: L10n.t('save_doing'), value: checkpoint.doing),
              _Field(label: L10n.t('save_next'), value: checkpoint.nextStep),
              _Field(
                  label: L10n.t('save_remember'), value: checkpoint.remember),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L10n.t('save_ack')),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
