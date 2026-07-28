import 'package:flutter/material.dart';

/// Bảng màu và theme dùng chung — thay vì rải mã màu khắp các widget.
abstract final class AppColors {
  static const Color primary = Color(0xFF2E5AAC);
  static const Color danger = Color(0xFFD9534F);
  static const Color success = Color(0xFF2E9E5B);
  static const Color warningSurface = Color(0xFFFFF4E0);
  static const Color infoSurface = Color(0xFFE8F0FE);
  static const Color panelSurface = Color(0xFFF5F8FF);
  static const Color mutedSurface = Color(0xFFF5F6FA);
  static const Color taskChip = Color(0xFFFDE9E0);
  static const Color scheduleChip = Color(0xFFDCE7F8);
  static const Color doneChip = Color(0xFFE6E6E6);
  static const Color weekendSurface = Color(0xFFFDF7F7);
  static const Color outsideMonthSurface = Color(0xFFFAFAFA);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.comfortable,
    );

/// Tiêu đề màn hình, dùng chung cho mọi tab.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      );
}

/// Dòng mô tả phụ dưới tiêu đề.
class ScreenHint extends StatelessWidget {
  const ScreenHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Colors.black54, fontSize: 13),
      );
}
