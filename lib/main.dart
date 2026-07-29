import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/l10n.dart';
import 'services/nudge_service.dart';
import 'services/tab_order_service.dart';
import 'services/user_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initPlatform();
  await _loadUserPreferences();
  runApp(const WorkSaveApp());
}

Future<void> _initPlatform() async {
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();
  await localNotifier.setup(
    appName: 'WorkSave',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );
  launchAtStartup.setup(
    appName: 'WorkSave',
    appPath: Platform.resolvedExecutable,
  );

  const options = WindowOptions(
    size: Size(1180, 760),
    minimumSize: Size(900, 600),
    center: true,
    title: 'WorkSave',
  );
  unawaited(windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  }));
}

Future<void> _loadUserPreferences() async {
  await L10n.load();
  await TabOrderService.load();
  await UserProfile.load();
  await const NudgeService().prime();
}
