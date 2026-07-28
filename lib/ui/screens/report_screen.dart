import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models/task.dart';
import '../../services/ai_prompt_builder.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Sinh prompt báo cáo tuần từ nhật ký các task.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const AiPromptBuilder _promptBuilder = AiPromptBuilder();

  late DateTime _monday;
  String _prompt = '';
  List<Task> _unfinished = const [];

  @override
  void initState() {
    super.initState();
    _monday = DateTime.now().mondayOfWeek;
    _rebuild();
  }

  DateTime get _friday => _monday.add(const Duration(days: 4));
  DateTime get _sunday => _monday.add(const Duration(days: 6));

  Future<void> _rebuild() async {
    final logs = await Repos.tasks.logsBetween(_monday, _sunday);
    final unfinished = await Repos.tasks.unfinished();
    final titles = await Repos.tasks.titlesById();

    final prompt = await _promptBuilder.forWeeklyReport(
      monday: _monday,
      friday: _friday,
      logs: logs,
      unfinished: unfinished,
      taskTitles: titles,
    );

    if (!mounted) return;
    setState(() {
      _prompt = prompt;
      _unfinished = unfinished;
    });
  }

  void _shiftWeek(int weeks) {
    setState(() => _monday = _monday.add(Duration(days: 7 * weeks)));
    _rebuild();
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L10n.t('report_copied'))));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScreenTitle(L10n.t('tab_report')),
              const Spacer(),
              IconButton(
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left)),
              Text('${formatDate(_monday)} → ${formatDate(_friday)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (_unfinished.isNotEmpty) _buildUnfinishedWarning(),
          const SizedBox(height: AppSpacing.xs),
          ScreenHint(L10n.t('report_hint')),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.mutedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _prompt,
                  style: const TextStyle(
                      fontFamily: 'Consolas', fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _copyPrompt,
                icon: const Icon(Icons.copy),
                label: Text(L10n.t('report_copy_btn')),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _rebuild,
                icon: const Icon(Icons.refresh),
                label: Text(L10n.t('refresh')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnfinishedWarning() {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(L10n.t2('report_unfinished', {
              'n': '${_unfinished.length}',
              'list': _unfinished.map((t) => t.title).join(', '),
            })),
          ),
        ],
      ),
    );
  }
}
