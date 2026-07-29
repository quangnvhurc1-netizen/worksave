import 'package:flutter/foundation.dart';

import '../data/repositories/repositories.dart';

/// Tên người dùng, dùng để xưng hô trong thông báo và lời chúc mừng.
/// Rỗng thì mọi nơi tự lùi về cách gọi chung ("bạn" / "friend").
class UserProfile {
  const UserProfile._();

  static final ValueNotifier<String> name = ValueNotifier<String>('');

  static Future<void> load() async {
    name.value = await Repos.settings.userName();
  }

  static Future<void> setName(String value) async {
    name.value = value.trim();
    await Repos.settings.saveUserName(value);
  }

  static bool get hasName => name.value.trim().isNotEmpty;
}
