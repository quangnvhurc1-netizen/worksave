import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';

/// Ghi nhanh (Ctrl+Shift+Space hoặc từ tray): gõ -> Enter -> xong.
class QuickCaptureDialog extends StatefulWidget {
  const QuickCaptureDialog({super.key});

  @override
  State<QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<QuickCaptureDialog> {
  final _input = TextEditingController();
  String _target = 'journal'; // journal | idea

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    if (_target == 'journal') {
      await AppDb.instance.insertJournal(JournalEntry(content: content));
    } else {
      await AppDb.instance.insertIdea(Idea(content: content));
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(_target == 'journal'
            ? L10n.t('saved_journal')
            : L10n.t('saved_idea')),
        duration: const Duration(seconds: 2),
      ));
    }
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
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'journal',
                    label: Text(L10n.t('tab_journal')),
                    icon: const Icon(Icons.edit_note, size: 18)),
                ButtonSegment(
                    value: 'idea',
                    label: Text(L10n.t('tab_ideas')),
                    icon: const Icon(Icons.lightbulb_outline, size: 18)),
              ],
              selected: {_target},
              onSelectionChanged: (s) => setState(() => _target = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _input,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
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
            child: const Text('Hủy (Esc)')),
        FilledButton(onPressed: _save, child: const Text('Lưu (Enter)')),
      ],
    );
  }
}
