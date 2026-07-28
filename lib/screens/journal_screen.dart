import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _input = TextEditingController();
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await AppDb.instance.getJournal();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _add() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    await AppDb.instance.insertJournal(JournalEntry(content: content));
    _input.clear();
    _load();
  }

  Future<void> _edit(JournalEntry e) async {
    final c = TextEditingController(text: e.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('edit_journal')),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: c,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.t('save'))),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      e.content = c.text.trim();
      await AppDb.instance.updateJournal(e);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gom theo ngày (đã sort DESC theo created_at).
    final grouped = <String, List<JournalEntry>>{};
    for (final e in _entries) {
      grouped.putIfAbsent(fmtDate(e.createdAt), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(L10n.t('journal_title'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            L10n.t('journal_sub'),
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: L10n.t('journal_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(L10n.t('log_btn')),
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? Center(child: Text(L10n.t('no_journal')))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E5AAC)),
                        ),
                      ),
                      ...entry.value.map((e) => Card(
                            child: ListTile(
                              dense: true,
                              leading: Text(
                                '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12),
                              ),
                              title: Text(e.content),
                              onTap: () => _edit(e),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                onPressed: () async {
                                  if (e.id != null) {
                                    await AppDb.instance.deleteJournal(e.id!);
                                    _load();
                                  }
                                },
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
