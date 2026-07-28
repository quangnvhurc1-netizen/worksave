import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/notes.dart';
import '../../services/l10n.dart';
import '../theme.dart';
import '../widgets/text_entry_field.dart';

/// Ghi nhanh ý tưởng, có thể chuyển thẳng thành task.
class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  List<Idea> _ideas = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ideas = await Repos.notes.ideas();
    if (!mounted) return;
    setState(() => _ideas = ideas);
  }

  Future<void> _add(String content) async {
    await Repos.notes.addIdea(content);
    await _load();
  }

  Future<void> _edit(Idea idea) async {
    final updated = await showEditTextDialog(
      context: context,
      title: L10n.t('edit_idea'),
      initialValue: idea.content,
    );
    if (updated == null) return;
    await Repos.notes.updateIdea(idea.copyWith(content: updated));
    await _load();
  }

  Future<void> _convertToTask(Idea idea) async {
    final task = await Repos.notes.convertIdeaToTask(idea);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t2('converted_to_task', {'t': task.title}))));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: ScreenTitle(L10n.t('ideas_title')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: TextEntryField(
            hintText: L10n.t('idea_hint'),
            buttonLabel: L10n.t('save'),
            onSubmit: _add,
          ),
        ),
        Expanded(
          child: _ideas.isEmpty
              ? Center(child: Text(L10n.t('no_ideas')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
                  itemCount: _ideas.length,
                  itemBuilder: (context, index) {
                    final idea = _ideas[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.lightbulb_outline,
                            color: Colors.amber),
                        title: Text(idea.content),
                        subtitle: Text(formatDate(idea.createdAt),
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => _edit(idea),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: L10n.t('to_task_tooltip'),
                              icon: const Icon(Icons.task_alt,
                                  color: AppColors.primary),
                              onPressed: () => _convertToTask(idea),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final id = idea.id;
                                if (id == null) return;
                                await Repos.notes.deleteIdea(id);
                                await _load();
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
