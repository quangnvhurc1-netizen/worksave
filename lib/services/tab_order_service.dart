import 'package:flutter/foundation.dart';

import '../data/repositories/repositories.dart';
import '../domain/enums.dart';

/// Thứ tự tab do người dùng cấu hình. Là nguồn sự thật duy nhất cho
/// thanh điều hướng, nên đổi ở Settings là UI cập nhật ngay.
class TabOrderService {
  const TabOrderService._();

  static final ValueNotifier<List<AppTab>> order =
      ValueNotifier<List<AppTab>>(AppTab.values);

  static Future<void> load() async {
    order.value = await Repos.settings.tabOrder();
  }

  static Future<void> save(List<AppTab> tabs) async {
    order.value = List.unmodifiable(tabs);
    await Repos.settings.saveTabOrder(tabs);
  }

  static Future<void> resetToDefault() => save(AppTab.values);

  /// Vị trí hiện tại của một tab, -1 nếu không có.
  static int indexOf(AppTab tab) => order.value.indexOf(tab);
}
