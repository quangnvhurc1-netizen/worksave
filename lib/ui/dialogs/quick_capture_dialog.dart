import 'package:flutter/material.dart';

import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../services/l10n.dart';

/// Ghi nhanh vào Nhật ký hoặc Ý tưởng (Ctrl+Shift+Space).
class QuickCaptureDialog extends StatefulWidget {
  const QuickCaptureDialog({super.key});

  @override
  State<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<QuickCaptureDialog> {
  final _input = TextEditingController();
  QuickCaptureTarget _target = QuickCaptureTarget.journal;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;

    switch (_target) {
      case QuickCaptureTarget.journal:
        await Repos.notes.addJournal(content);
      case QuickCaptureTarget.idea:
        await Repos.notes.addIdea(content);
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(_target == QuickCaptureTarget.journal
          ? L10n.t('saved_journal')
          : L10n.t('saved_idea')),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('quick_title')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<QuickCaptureTarget>(
              segments: [
                ButtonSegment(
                  value: QuickCaptureTarget.journal,
                  label: Text(L10n.t('tab_journal')),
                  icon: const Icon(Icons.edit_note, size: 18),
                ),
                ButtonSegment(
                  value: QuickCaptureTarget.idea,
                  label: Text(L10n.t('tab_ideas')),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                ),
              ],
              selected: {_target},
              onSelectionChanged: (selection) =>
                  setState(() => _target = selection.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _input,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: L10n.t('quick_hint'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(onPressed: _save, child: Text(L10n.t('save'))),
      ],
    );
  }
}
