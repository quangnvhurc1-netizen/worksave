import 'dart:math';

import 'package:flutter/foundation.dart';

/// Cơ chế reward: nơi nào có thành tích thì gọi Celebration.instance.fire(),
/// HomeScreen lắng nghe và bắn pháo hoa + banner chúc mừng.
class Celebration {
  Celebration._();
  static final Celebration instance = Celebration._();

  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  final Random _rng = Random();

  static const List<String> _praises = [
    '🎉 Giỏi quá!',
    '🔥 Quá đỉnh!',
    '🏆 Tuyệt vời!',
    '💪 Chiến thần năng suất!',
    '🚀 Cứ đà này thì sếp phải dè chừng!',
    '⭐ Xuất sắc!',
    '🎊 Một chiến thắng nữa!',
  ];

  void fire(String what) {
    message.value = '${_praises[_rng.nextInt(_praises.length)]} $what';
  }

  void clear() => message.value = null;
}
