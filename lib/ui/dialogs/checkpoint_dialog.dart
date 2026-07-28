import 'package:flutter/material.dart';

import '../../domain/models/notes.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Nhập một bản "save trạng thái". Trả về [Checkpoint] hoặc null nếu hủy.
class CheckpointDialog extends StatefulWidget {
  const CheckpointDialog({
    super.key,
    this.initialDoing = '',
    this.initialNextStep = '',
    this.badge,
  });

  final String initialDoing;
  final String initialNextStep;
  final String? badge;

  @override
  State<CheckpointDialog> createState() => _CheckpointDialogState();
}

class _CheckpointDialogState extends State<CheckpointDialog> {
  late final TextEditingController _doing =
      TextEditingController(text: widget.initialDoing);
  late final TextEditingController _nextStep =
      TextEditingController(text: widget.initialNextStep);
  final TextEditingController _remember = TextEditingController();

  @override
  void dispose() {
    for (final c in [_doing, _nextStep, _remember]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final doing = _doing.text.trim();
    if (doing.isEmpty) return;
    Navigator.pop(
      context,
      Checkpoint(
        doing: doing,
        nextStep: _nextStep.text.trim(),
        remember: _remember.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    return AlertDialog(
      title: Text('💾 ${L10n.t('tab_saves')}'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.infoSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 12)),
                ),
              _field(_doing, L10n.t('save_doing'), 6),
              _field(_nextStep, L10n.t('save_next'), 5),
              _field(_remember, L10n.t('save_remember'), 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: Text(L10n.t('save')),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, int lines) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
          controller: controller,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      );
}
