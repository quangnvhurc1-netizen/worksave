import 'package:flutter/material.dart';

import '../../services/l10n.dart';
import '../theme.dart';

/// Ô nhập + nút lưu, dùng chung cho Ý tưởng và Nhật ký.
/// Tự quản controller nên màn hình gọi chỉ cần truyền callback.
class TextEntryField extends StatefulWidget {
  const TextEntryField({
    super.key,
    required this.hintText,
    required this.buttonLabel,
    required this.onSubmit,
    this.maxLines = 1,
  });

  final String hintText;
  final String buttonLabel;
  final Future<void> Function(String content) onSubmit;
  final int maxLines;

  @override
  State<TextEntryField> createState() => _TextEntryFieldState();
}

class _TextEntryFieldState extends State<TextEntryField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();
    await widget.onSubmit(content);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: Text(widget.buttonLabel),
        ),
      ],
    );
  }
}

/// Hộp thoại sửa một đoạn văn bản; trả về nội dung mới hoặc null nếu hủy.
Future<String?> showEditTextDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  int maxLines = 6,
}) async {
  final controller = TextEditingController(text: initialValue);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L10n.t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L10n.t('save'))),
      ],
    ),
  );
  final text = controller.text.trim();
  controller.dispose();
  if (!(confirmed ?? false) || text.isEmpty) return null;
  return text;
}
