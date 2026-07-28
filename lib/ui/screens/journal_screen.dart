import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/notes.dart';
import '../../services/l10n.dart';
import '../theme.dart';
import '../widgets/text_entry_field.dart';

/// Nhật ký suy nghĩ tự do, nhóm theo ngày.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Repos.notes.journal();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _add(String content) async {
    await Repos.notes.addJournal(content);
    await _load();
  }

  Future<void> _edit(JournalEntry entry) async {
    final updated = await showEditTextDialog(
      context: context,
      title: L10n.t('edit_journal'),
      initialValue: entry.content,
    );
    if (updated == null) return;
    await Repos.notes.updateJournal(entry.copyWith(content: updated));
    await _load();
  }

  Map<String, List<JournalEntry>> get _groupedByDay {
    final grouped = <String, List<JournalEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(formatDate(entry.createdAt), () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: ScreenTitle(L10n.t('journal_title')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ScreenHint(L10n.t('journal_sub')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: TextEntryField(
            hintText: L10n.t('journal_hint'),
            buttonLabel: L10n.t('log_btn'),
            maxLines: 4,
            onSubmit: _add,
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? Center(child: Text(L10n.t('no_journal')))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
                  children: [
                    for (final group in _groupedByDay.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.sm, bottom: AppSpacing.xs),
                        child: Text(
                          group.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ),
                      for (final entry in group.value)
                        Card(
                          child: ListTile(
                            dense: true,
                            leading: Text(formatTime(entry.createdAt),
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                            title: Text(entry.content),
                            onTap: () => _edit(entry),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                final id = entry.id;
                                if (id == null) return;
                                await Repos.notes.deleteJournal(id);
                                await _load();
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
