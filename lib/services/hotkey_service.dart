import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Quản lý phím tắt toàn cục (Ctrl+Shift+Space để ghi nhanh).
///
/// Tách khỏi widget để lỗi đăng ký được ghi lại thay vì nuốt lặng lẽ — trước
/// đây phím tắt chết là không có cách nào biết vì sao.
class HotkeyService {
  HotkeyService._();
  static final HotkeyService instance = HotkeyService._();

  static final HotKey quickCapture = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  bool _registered = false;
  String? _lastError;

  bool get isRegistered => _registered;
  String? get lastError => _lastError;

  /// Nhãn hiển thị của phím tắt, để UI không phải tự viết chuỗi.
  static String get label => 'Ctrl + Shift + Space';

  /// Đăng ký phím tắt.
  ///
  /// KHÔNG gọi [hotKeyManager.unregister] cho phím chưa từng đăng ký: phía
  /// Windows nó tra bảng id native và có thể abort() cả tiến trình — lỗi này
  /// không bắt được bằng try/catch trong Dart. Việc dọn phím tắt cũ đã do
  /// `unregisterAll()` ở main() lo, nên ở đây chỉ đăng ký một lần.
  Future<void> register(VoidCallback onTrigger) async {
    if (_registered) return;

    try {
      await hotKeyManager.register(
        quickCapture,
        keyDownHandler: (_) => onTrigger(),
      );
      _registered = true;
      _lastError = null;
    } on Object catch (error) {
      _registered = false;
      _lastError = '$error';
    }
  }

  /// Chỉ huỷ khi chắc chắn đã đăng ký thành công, vì lý do nêu ở [register].
  Future<void> unregister() async {
    if (!_registered) return;
    try {
      await hotKeyManager.unregister(quickCapture);
    } on Object {
      // Không huỷ được cũng không ảnh hưởng gì.
    }
    _registered = false;
  }
}
