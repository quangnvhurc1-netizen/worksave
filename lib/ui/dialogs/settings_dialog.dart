import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../core/clock_time.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/settings.dart';
import '../../services/backup_service.dart';
import '../../services/l10n.dart';
import '../theme.dart';
import 'tab_order_dialog.dart';

/// Cài đặt: AI, cách nhắc, review, ngôn ngữ, thứ tự tab, sao lưu.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  static const BackupService _backup = BackupService();

  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _reviewTime = TextEditingController();
  final _dayStart = TextEditingController();
  final _leadMinutes = TextEditingController();
  final _nagMinutes = TextEditingController();

  bool _obscureKey = true;
  bool _loaded = false;
  bool _launchOnStartup = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _apiKey,
      _model,
      _reviewTime,
      _dayStart,
      _leadMinutes,
      _nagMinutes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final settings = Repos.settings;
    _apiKey.text = await settings.geminiApiKey() ?? '';
    _model.text = await settings.geminiModel();
    _reviewTime.text = (await settings.reviewTime()).format();

    final reminder = await settings.reminderSettings();
    _dayStart.text = reminder.dayStart.format();
    _leadMinutes.text = '${reminder.leadTime.inMinutes}';
    _nagMinutes.text = '${reminder.nagInterval.inMinutes}';

    try {
      _launchOnStartup = await launchAtStartup.isEnabled();
    } on Object {
      _launchOnStartup = false;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final settings = Repos.settings;
    await settings.saveGeminiApiKey(_apiKey.text);
    await settings.saveGeminiModel(_model.text.trim().isEmpty
        ? SettingsRepository.defaultGeminiModel
        : _model.text);

    final reviewTime = ClockTime.tryParse(_reviewTime.text);
    if (reviewTime != null) await settings.saveReviewTime(reviewTime);

    final current = await settings.reminderSettings();
    await settings.saveReminderSettings(ReminderSettings(
      dayStart: ClockTime.tryParse(_dayStart.text) ?? current.dayStart,
      leadTime: _durationOr(_leadMinutes.text, current.leadTime, minimum: 0),
      nagInterval:
          _durationOr(_nagMinutes.text, current.nagInterval, minimum: 1),
    ));

    if (mounted) Navigator.pop(context);
  }

  static Duration _durationOr(String raw, Duration fallback,
      {required int minimum}) {
    final minutes = int.tryParse(raw.trim());
    if (minutes == null || minutes < minimum) return fallback;
    return Duration(minutes: minutes);
  }

  Future<void> _toggleStartup(bool enabled) async {
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      if (mounted) setState(() => _launchOnStartup = enabled);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _exportBackup() async {
    final result = await _backup.exportToFile();
    if (!mounted) return;
    switch (result) {
      case BackupCancelled():
        break;
      case BackupSucceeded(:final path):
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.t2('backup_ok', {'p': path}))));
      case BackupFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.t2('backup_fail', {'e': '$error'}))));
    }
  }

  Future<void> _importBackup() async {
    final file = await _backup.pickBackupFile();
    if (file == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.t('restore_confirm_title')),
        content: Text(L10n.t2('restore_confirm_body', {'p': file.path})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(L10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(L10n.t('restore_confirm_btn'))),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    final result = await _backup.importFrom(file);
    if (!mounted) return;
    switch (result) {
      case BackupSucceeded():
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(L10n.t('restore_done_title')),
            content: Text(L10n.t('restore_done_body')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(L10n.t('ok'))),
            ],
          ),
        );
      case BackupFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.t2('backup_fail', {'e': '$error'}))));
      case BackupCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('⚙ ${L10n.t('settings_title')}'),
      content: SizedBox(
        width: 560,
        child: _loaded
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAiSection(),
                    const Divider(height: 28),
                    _buildReminderSection(),
                    const Divider(height: 28),
                    _buildLanguageSection(),
                    const Divider(height: 28),
                    _buildTabOrderSection(),
                    const Divider(height: 28),
                    _buildBackupSection(),
                  ],
                ),
              )
            : const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator())),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(onPressed: _save, child: Text(L10n.t('save'))),
      ],
    );
  }

  Widget _buildAiSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: L10n.t('api_key'),
              hintText: L10n.t('api_key_hint'),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _model,
            decoration: InputDecoration(
              labelText: L10n.t('model'),
              helperText: L10n.t('model_help'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(L10n.t('key_note'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );

  Widget _buildReminderSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t('reminder_section'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(L10n.t('reminder_note'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _dayStart,
            decoration: InputDecoration(
              labelText: L10n.t('day_start_time'),
              helperText: L10n.t('day_start_help'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _leadMinutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: L10n.t('lead_minutes'),
                    helperText: L10n.t('lead_help'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _nagMinutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: L10n.t('nag_minutes'),
                    helperText: L10n.t('nag_help'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reviewTime,
            decoration: InputDecoration(
              labelText: L10n.t('review_time'),
              helperText: L10n.t('review_time_help'),
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L10n.t('autostart')),
            subtitle: Text(L10n.t('autostart_sub'),
                style: const TextStyle(fontSize: 12)),
            value: _launchOnStartup,
            onChanged: _toggleStartup,
          ),
        ],
      );

  Widget _buildLanguageSection() => Row(
        children: [
          const Icon(Icons.language, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(L10n.t('language')),
          const SizedBox(width: AppSpacing.md),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.vi, label: Text('Tiếng Việt')),
              ButtonSegment(value: AppLanguage.en, label: Text('English')),
            ],
            selected: {L10n.language.value},
            onSelectionChanged: (selection) async {
              await L10n.setLanguage(selection.first);
              if (mounted) setState(() {});
            },
          ),
        ],
      );

  Widget _buildTabOrderSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t('tabs_section'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(L10n.t('tabs_note'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final changed = await showDialog<bool>(
                context: context,
                builder: (_) => const TabOrderDialog(),
              );
              if ((changed ?? false) && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L10n.t('tab_order_saved'))));
              }
            },
            icon: const Icon(Icons.swap_vert, size: 18),
            label: Text(L10n.t('edit_tabs_btn')),
          ),
        ],
      );

  Widget _buildBackupSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t('backup_section'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(L10n.t('backup_note'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(Icons.download, size: 18),
                label: Text(L10n.t('export_btn')),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _importBackup,
                icon: const Icon(Icons.upload, size: 18),
                label: Text(L10n.t('import_btn')),
              ),
            ],
          ),
        ],
      );
}
