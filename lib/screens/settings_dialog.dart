import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../db/app_db.dart';
import '../services/backup_service.dart';
import '../services/gemini_service.dart';
import '../services/l10n.dart';
import '../services/tab_order.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _svc = GeminiService();
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _reviewTime = TextEditingController();
  final _dayStart = TextEditingController();
  final _lead = TextEditingController();
  final _nag = TextEditingController();
  bool _obscure = true;
  bool _loaded = false;
  bool _autoStart = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _key.text = (await _svc.apiKey) ?? '';
    _model.text = await _svc.model;
    _reviewTime.text =
        (await AppDb.instance.getSetting('review_time')) ?? '16:30';
    _dayStart.text = await AppDb.instance.dayStartTime;
    _lead.text = '${await AppDb.instance.leadMinutes}';
    _nag.text = '${await AppDb.instance.nagMinutes}';
    try {
      _autoStart = await launchAtStartup.isEnabled();
    } catch (_) {
      _autoStart = false;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _reviewTime.dispose();
    _dayStart.dispose();
    _lead.dispose();
    _nag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('⚙ ${L10n.t('settings_title')}'),
      content: SizedBox(
        width: 520,
        child: !_loaded
            ? const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _key,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: L10n.t('api_key'),
                      hintText: L10n.t('api_key_hint'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _model,
                    decoration: InputDecoration(
                      labelText: L10n.t('model'),
                      helperText: L10n.t('model_help'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(L10n.t('key_note'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  const Divider(height: 28),
                  TextField(
                    controller: _reviewTime,
                    decoration: InputDecoration(
                      labelText: L10n.t('review_time'),
                      helperText: L10n.t('review_time_help'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(L10n.t('autostart')),
                    subtitle: Text(L10n.t('autostart_sub'),
                        style: const TextStyle(fontSize: 12)),
                    value: _autoStart,
                    onChanged: (v) async {
                      try {
                        if (v) {
                          await launchAtStartup.enable();
                        } else {
                          await launchAtStartup.disable();
                        }
                        setState(() => _autoStart = v);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Không đổi được: $e')));
                        }
                      }
                    },
                  ),
                  const Divider(height: 28),
                  // ---- Cách nhắc lịch ----
                  Text(L10n.t('reminder_section'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(L10n.t('reminder_note'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dayStart,
                    decoration: InputDecoration(
                      labelText: L10n.t('day_start_time'),
                      helperText: L10n.t('day_start_help'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lead,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: L10n.t('lead_minutes'),
                            helperText: L10n.t('lead_help'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nag,
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
                  const Divider(height: 28),
                  // ---- Ngôn ngữ ----
                  Row(
                    children: [
                      const Icon(Icons.language, size: 20),
                      const SizedBox(width: 8),
                      Text(L10n.t('language')),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'vi', label: Text('Tiếng Việt')),
                          ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {L10n.lang.value},
                        onSelectionChanged: (sel) async {
                          await L10n.setLang(sel.first);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  // ---- Thứ tự tab ----
                  Text(L10n.t('tabs_section'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(L10n.t('tabs_note'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final changed = await showDialog<bool>(
                        context: context,
                        builder: (_) => const TabOrderDialog(),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(L10n.t('tab_order_saved'))));
                      }
                    },
                    icon: const Icon(Icons.swap_vert, size: 18),
                    label: Text(L10n.t('edit_tabs_btn')),
                  ),
                  const Divider(height: 28),
                  Text(L10n.t('backup_section'),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(L10n.t('backup_note'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => BackupService.exportBackup(context),
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(L10n.t('export_btn')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => BackupService.importBackup(context),
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(L10n.t('import_btn')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(
          onPressed: () async {
            await _svc.setApiKey(_key.text);
            await _svc.setModel(_model.text.trim().isEmpty
                ? GeminiService.defaultModel
                : _model.text);
            final timeRe = RegExp(r'^\d{1,2}:\d{2}$');
            final rt = _reviewTime.text.trim();
            if (timeRe.hasMatch(rt)) {
              await AppDb.instance.setSetting('review_time', rt);
            }
            final ds = _dayStart.text.trim();
            if (timeRe.hasMatch(ds)) {
              await AppDb.instance.setSetting('day_start_time', ds);
            }
            final lead = int.tryParse(_lead.text.trim());
            if (lead != null && lead >= 0) {
              await AppDb.instance.setSetting('lead_minutes', '$lead');
            }
            final nag = int.tryParse(_nag.text.trim());
            if (nag != null && nag >= 1) {
              await AppDb.instance.setSetting('nag_minutes', '$nag');
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(L10n.t('save')),
        ),
      ],
    );
  }
}
