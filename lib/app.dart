import 'package:flutter/material.dart';

import 'domain/enums.dart';
import 'services/l10n.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

/// Vỏ ứng dụng: chỉ dựng MaterialApp và rebuild khi đổi ngôn ngữ.
class WorkSaveApp extends StatelessWidget {
  const WorkSaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: L10n.language,
      builder: (context, language, _) => MaterialApp(
        title: 'WorkSave',
        debugShowCheckedModeBanner: false,
        locale: Locale(language.code),
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
