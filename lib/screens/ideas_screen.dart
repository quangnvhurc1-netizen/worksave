import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  final TextEditingController _input = TextEditingController();
  List<Idea> _ideas = [];

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
    final ideas = await AppDb.instance.getIdeas();
    if (!mounted) return;
    setState(() => _ideas = ideas);
  }

  Future<void> _add() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    await AppDb.instance.insertIdea(Idea(content: content));
    _input.clear();
    _load();
  }

  Future<void> _edit(Idea idea) async {
    final c = TextEditingController(text: idea.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('edit_idea')),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: c,
            maxLines: 5,
            decoration:
                const InputDecoration(border: OutlineInputBorder()),
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
      idea.content = c.text.trim();
      await AppDb.instance.updateIdea(idea);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(L10n.t('ideas_title'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: InputDecoration(
                    hintText: L10n.t('idea_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(L10n.t('save')),
              ),
            ],
          ),
        ),
        Expanded(
          child: _ideas.isEmpty
              ? Center(child: Text(L10n.t('no_ideas')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _ideas.length,
                  itemBuilder: (_, i) {
                    final idea = _ideas[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.lightbulb_outline,
                            color: Colors.amber),
                        title: Text(idea.content),
                        subtitle: Text(fmtDate(idea.createdAt),
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => _edit(idea),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: L10n.t('to_task_tooltip'),
                              icon: const Icon(Icons.task_alt,
                                  color: Color(0xFF2E5AAC)),
                              onPressed: () async {
                                final firstLine =
                                    idea.content.split('\n').first.trim();
                                final title = firstLine.length > 80
                                    ? '${firstLine.substring(0, 80)}…'
                                    : firstLine;
                                await AppDb.instance.insertTask(TaskItem(
                                  title: title,
                                  description: idea.content,
                                ));
                                if (idea.id != null) {
                                  await AppDb.instance.deleteIdea(idea.id!);
                                }
                                _load();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '✅ Đã chuyển "$title" thành task — xem ở tab Task.')));
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (idea.id != null) {
                                  await AppDb.instance.deleteIdea(idea.id!);
                                  _load();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
