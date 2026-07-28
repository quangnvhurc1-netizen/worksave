import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/notes.dart';
import '../../services/gemini_service.dart';
import '../../services/l10n.dart';
import '../dialogs/checkpoint_dialog.dart';
import '../theme.dart';

/// "Save game": chốt trạng thái làm việc, có thể nhờ AI tổng hợp vào thứ 6.
class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  static const GeminiService _gemini = GeminiService();

  List<Checkpoint> _checkpoints = const [];
  bool _generating = false;
  bool _generatedToday = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final checkpoints = await Repos.notes.checkpoints();
    final generated = await Repos.settings.isFridaySummaryGeneratedToday();
    if (!mounted) return;
    setState(() {
      _checkpoints = checkpoints;
      _generatedToday = generated;
    });
  }

  Future<void> _summariseWithAi() async {
    setState(() => _generating = true);
    final summary = await _gemini.buildFridaySummary();
    if (!mounted) return;
    setState(() => _generating = false);

    final warning = summary.warning;
    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(warning),
        duration: const Duration(seconds: 6),
      ));
    }

    final split = _splitSummary(summary.text);
    await _openCheckpointDialog(
      doing: split.doing,
      nextStep: split.next,
      badge: summary.isFromAi
          ? (summary.source == SummarySource.aiCached
              ? L10n.t('save_badge_cached')
              : L10n.t('save_badge_ai'))
          : L10n.t('save_badge_local'),
    );
  }

  /// AI được yêu cầu trả về 2 phần; nếu đúng format thì tách sẵn cho người dùng.
  static ({String doing, String next}) _splitSummary(String text) {
    const marker = 'VIỆC TIẾP THEO:';
    final index = text.indexOf(marker);
    if (index <= 0) return (doing: text, next: '');
    return (
      doing: text.substring(0, index).replaceFirst('ĐANG LÀM DỞ:', '').trim(),
      next: text.substring(index + marker.length).trim(),
    );
  }

  Future<void> _openCheckpointDialog({
    String doing = '',
    String nextStep = '',
    String? badge,
  }) async {
    var initialDoing = doing;
    if (initialDoing.isEmpty) {
      final inProgress = await Repos.tasks.unfinished();
      initialDoing = inProgress.map((t) => '- ${t.title}').join('\n');
    }
    if (!mounted) return;

    final checkpoint = await showDialog<Checkpoint>(
      context: context,
      builder: (_) => CheckpointDialog(
        initialDoing: initialDoing,
        initialNextStep: nextStep,
        badge: badge,
      ),
    );
    if (checkpoint == null) return;
    await Repos.notes.addCheckpoint(checkpoint);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCheckpointDialog(),
        icon: const Icon(Icons.save),
        label: Text(L10n.t('save_manual')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: ScreenTitle(L10n.t('tab_saves')),
          ),
          _buildAiCard(),
          Expanded(
            child: _checkpoints.isEmpty
                ? Center(child: Text(L10n.t('no_saves')))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 80),
                    itemCount: _checkpoints.length,
                    itemBuilder: (context, index) => _CheckpointCard(
                      checkpoint: _checkpoints[index],
                      isLatest: index == 0,
                      onDelete: () async {
                        final id = _checkpoints[index].id;
                        if (id == null) return;
                        await Repos.notes.deleteCheckpoint(id);
                        await _load();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      color: AppColors.panelSurface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(L10n.t('ai_summary_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (_generatedToday)
                  Chip(
                    label: Text(L10n.t('ai_generated_today'),
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _gemini.isFriday
                  ? (_generatedToday
                      ? L10n.t('ai_friday_cached')
                      : L10n.t('ai_friday_ready'))
                  : L10n.t('ai_not_friday'),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _generating ? null : _summariseWithAi,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating
                  ? L10n.t('ai_working')
                  : L10n.t('ai_summarise_btn')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({
    required this.checkpoint,
    required this.isLatest,
    required this.onDelete,
  });

  final Checkpoint checkpoint;
  final bool isLatest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timestamp = formatDateTime(checkpoint.createdAt);
    return Card(
      child: ExpansionTile(
        leading: Icon(isLatest ? Icons.bookmark : Icons.bookmark_border,
            color: isLatest ? AppColors.primary : null),
        title: Text(isLatest ? '${L10n.t('save_latest')} — $timestamp' : timestamp),
        subtitle: Text(checkpoint.doing,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _block(L10n.t('save_doing'), checkpoint.doing),
          _block(L10n.t('save_next'), checkpoint.nextStep),
          _block(L10n.t('save_remember'), checkpoint.remember),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(L10n.t('delete')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value),
        ],
      ),
    );
  }
}
