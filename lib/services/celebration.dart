import 'dart:math';

import 'package:flutter/foundation.dart';

import 'l10n.dart';
import 'user_profile.dart';

/// Phát tín hiệu chúc mừng; [CelebrationOverlay] lắng nghe để bắn pháo hoa.
///
/// Câu khen được lấy ngẫu nhiên từ bộ dịch nên đổi ngôn ngữ là đổi theo, và
/// có xưng tên nếu người dùng đã đặt tên trong Settings.
class Celebration {
  Celebration._();
  static final Celebration instance = Celebration._();

  static const int cheerCount = 6;

  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  final Random _random = Random();

  void fire(String what) {
    final cheer = L10n.t2('cheer_${_random.nextInt(cheerCount) + 1}', {
      'name': UserProfile.hasName ? UserProfile.name.value.trim() : '',
    });
    message.value = '${cheer.replaceAll('  ', ' ').trim()} $what';
  }

  void clear() => message.value = null;
}
