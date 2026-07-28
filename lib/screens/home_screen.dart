import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/celebration.dart';
import '../services/l10n.dart';
import '../services/tab_order.dart';
import 'ideas_screen.dart';
import 'journal_screen.dart';
import 'pomodoro_screen.dart';
import 'quick_capture.dart';
import 'report_screen.dart';
import 'review_dialog.dart';
import 'saves_screen.dart';
import 'schedule_screen.dart';
import 'search_dialog.dart';
import 'settings_dialog.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WindowListener, TrayListener {
  int _index = 0;
  List<TaskItem> _unfinished = [];
  bool _bannerDismissed = false;
  Timer? _tickTimer;
  bool _reviewShowing = false;
  bool _dialogOpen = false;

  late final ConfettiController _confetti;
  String? _celebrateMsg;
  Timer? _celebrateTimer;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    Celebration.instance.message.addListener(_onCelebrate);
    TabOrder.order.addListener(_onTabOrderChanged);
    L10n.lang.addListener(_onLangChanged);

    windowManager.addListener(this);
    trayManager.addListener(this);
    windowManager.setPreventClose(true); // đóng cửa sổ -> thu vào tray
    _initTray();
    _registerHotkey();

    _loadReminder();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLatestSave());
    _tick();
    // Quét 30s/lần để mốc "báo trước" không bị trễ.
    _tickTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void _onTabOrderChanged() {
    if (mounted) setState(() => _index = 0);
  }

  void _onLangChanged() {
    _initTray(); // dựng lại menu tray theo ngôn ngữ mới
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _celebrateTimer?.cancel();
    Celebration.instance.message.removeListener(_onCelebrate);
    TabOrder.order.removeListener(_onTabOrderChanged);
    L10n.lang.removeListener(_onLangChanged);
    _confetti.dispose();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  /// Nhảy tới tab theo id (vị trí có thể đã bị người dùng đổi).
  void _goTab(String id) {
    final i = TabOrder.order.value.indexOf(id);
    if (i >= 0) setState(() => _index = i);
  }

  // ---------------- Reward (pháo hoa + chúc mừng) ----------------
  void _onCelebrate() {
    final msg = Celebration.instance.message.value;
    if (msg == null || !mounted) return;
    _confetti.play();
    setState(() => _celebrateMsg = msg);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _celebrateMsg = null);
      Celebration.instance.clear();
    });
  }

  // ---------------- Tray + hotkey ----------------
  Future<void> _initTray() async {
    try {
      await trayManager.setIcon('assets/tray_icon.ico');
      await trayManager.setToolTip(L10n.t('tray_tooltip'));
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: L10n.t('tray_show')),
        MenuItem(key: 'capture', label: L10n.t('tray_capture')),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: L10n.t('tray_exit')),
      ]));
    } catch (_) {
      // Không có tray (hiếm) -> app vẫn chạy bình thường.
    }
  }

  Future<void> _registerHotkey() async {
    try {
      final hk = HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(hk,
          keyDownHandler: (_) => _openQuickCapture());
    } catch (_) {
      // Hotkey bị app khác chiếm -> vẫn dùng được từ tray menu.
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _openQuickCapture() async {
    await _showWindow();
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    await showDialog(
        context: context, builder: (_) => const QuickCaptureDialog());
    _dialogOpen = false;
  }

  @override
  void onWindowClose() async {
    // Bấm X -> ẩn xuống tray (hidden icons), không thoát.
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();
        break;
      case 'capture':
        await _openQuickCapture();
        break;
      case 'exit':
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  // ---------------- Nhắc lịch + review cuối ngày ----------------
  Future<void> _tick() async {
    await _checkDueSchedules();
    await _maybeShowReview();
  }

  Future<void> _loadReminder() async {
    final tasks = await AppDb.instance.getUnfinishedTasks();
    if (!mounted) return;
    setState(() => _unfinished = tasks);
  }

  Future<void> _checkDueSchedules() async {
    final due = await AppDb.instance.getDueNagging();
    final nag = await AppDb.instance.nagMinutes;
    for (final r in due) {
      final s = r.item;
      final when =
          '${r.dueAt.hour.toString().padLeft(2, '0')}:${r.dueAt.minute.toString().padLeft(2, '0')}';
      final String head;
      if (r.isEarly) {
        head = L10n.t2('notif_early', {'n': '${r.minutesLeft}'});
      } else if (r.isOverdue) {
        head = L10n.t2('notif_overdue', {'n': '${-r.minutesLeft}'});
      } else {
        head = L10n.t('notif_now');
      }
      LocalNotification(
        title: s.isFromTask
            ? L10n.t('notif_title_deadline')
            : L10n.t('notif_title_schedule'),
        body: '$head\n$when — ${s.content}\n'
            '${L10n.t2('notif_repeat', {'n': '$nag'})}',
      ).show();
      if (s.id != null) {
        await AppDb.instance.touchNotified(s.id!);
      }
    }
    if (due.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '🔔 ${due.map((r) => r.item.content).join(' · ')}'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: L10n.t('tab_schedule'),
          onPressed: () => _goTab('schedule'),
        ),
      ));
    }
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _maybeShowReview() async {
    if (_reviewShowing || _dialogOpen) return;
    final now = DateTime.now();
    final rt = (await AppDb.instance.getSetting('review_time')) ?? '16:30';
    final parts = rt.split(':');
    final target = DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 16, int.tryParse(parts[1]) ?? 30);
    if (now.isBefore(target)) return;
    final reviewedDate = await AppDb.instance.getSetting('review_date');
    if (reviewedDate == _todayIso()) return;
    final unfinished = await AppDb.instance.getUnfinishedTasks();
    if (unfinished.isEmpty) {
      await AppDb.instance.setSetting('review_date', _todayIso());
      return;
    }

    _reviewShowing = true;
    await _showWindow();
    if (mounted) {
      await showDialog(
          context: context, builder: (_) => const ReviewDialog());
      _loadReminder();
    }
    _reviewShowing = false;
  }

  Future<void> _openReviewManually() async {
    if (_reviewShowing) return;
    _reviewShowing = true;
    await showDialog(context: context, builder: (_) => const ReviewDialog());
    _reviewShowing = false;
    _loadReminder();
  }

  // ---------------- Save gần nhất khi mở app ----------------
  Future<void> _showLatestSave() async {
    final cp = await AppDb.instance.getLatestCheckpoint();
    if (cp == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.save, color: Color(0xFF2E5AAC)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Save gần nhất — ${fmtDate(cp.createdAt)} '
                  '${cp.createdAt.hour.toString().padLeft(2, '0')}:${cp.createdAt.minute.toString().padLeft(2, '0')}'),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Đang làm dở', cp.doing),
                _field('Việc tiếp theo', cp.nextStep),
                _field('Cần nhớ', cp.remember),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã nhớ, bắt đầu làm việc'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final pageById = <String, Widget>{
      'tasks': TasksScreen(onChanged: _loadReminder),
      'pomodoro': const PomodoroScreen(),
      'saves': const SavesScreen(),
      'ideas': const IdeasScreen(),
      'journal': const JournalScreen(),
      'schedule': const ScheduleScreen(),
      'report': const ReportScreen(),
    };
    final ids = TabOrder.order.value;
    final safeIndex = _index.clamp(0, ids.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              NavigationRail(
                selectedIndex: safeIndex,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                leading: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.videogame_asset,
                          size: 32, color: Color(0xFF2E5AAC)),
                    ),
                    IconButton(
                      tooltip: L10n.t('search_tooltip'),
                      icon: const Icon(Icons.search),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SearchDialog()),
                    ),
                    IconButton(
                      tooltip: L10n.t('review_tooltip'),
                      icon: const Icon(Icons.wb_twilight),
                      onPressed: _openReviewManually,
                    ),
                  ],
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: L10n.t('settings'),
                        icon: const Icon(Icons.settings),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SettingsDialog(),
                        ),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final id in ids)
                    NavigationRailDestination(
                      icon: Icon(TabOrder.defOf(id).icon),
                      label: Text(TabOrder.defOf(id).label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    if (_unfinished.isNotEmpty && !_bannerDismissed)
                      MaterialBanner(
                        backgroundColor: const Color(0xFFFFF4E0),
                        leading: const Icon(Icons.notifications_active,
                            color: Colors.orange),
                        content: Text(L10n.t2('unfinished_banner', {
                          'n': '${_unfinished.length}',
                          'list':
                              '${_unfinished.take(3).map((t) => t.title).join(', ')}'
                                  '${_unfinished.length > 3 ? '…' : ''}',
                        })),
                        actions: [
                          TextButton(
                            onPressed: () {
                              setState(() => _bannerDismissed = true);
                              _goTab('tasks');
                            },
                            child: Text(L10n.t('view_tasks')),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _bannerDismissed = true),
                            child: Text(L10n.t('hide')),
                          ),
                        ],
                      ),
                    Expanded(
                        child: pageById[ids[safeIndex]] ?? const SizedBox()),
                  ],
                ),
              ),
            ],
          ),
          // ---- Pháo hoa ----
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              maxBlastForce: 25,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              gravity: 0.25,
              shouldLoop: false,
            ),
          ),
          // ---- Banner chúc mừng ----
          if (_celebrateMsg != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(
                      scale: max(0.0, v), child: child),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(30),
                    color: const Color(0xFF2E5AAC),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      child: Text(
                        _celebrateMsg!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
