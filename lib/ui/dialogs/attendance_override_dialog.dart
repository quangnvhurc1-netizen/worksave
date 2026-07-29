import 'package:flutter/material.dart';

import '../../core/clock_time.dart';
import '../../core/date_x.dart';
import '../../domain/enums.dart';
import '../../domain/models/attendance.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Đặt giờ chấm công riêng cho một ngày cụ thể (OT), hoặc tắt nhắc hôm đó.
class AttendanceOverrideDialog extends StatefulWidget {
  const AttendanceOverrideDialog({super.key, this.existing});
  final AttendanceOverride? existing;

  @override
  State<AttendanceOverrideDialog> createState() =>
      _AttendanceOverrideDialogState();
}

class _AttendanceOverrideDialogState extends State<AttendanceOverrideDialog> {
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late AttendanceKind _kind = widget.existing?.kind ?? AttendanceKind.checkOut;
  late ClockTime? _time = widget.existing?.time ?? const ClockTime(20, 0);
  late bool _skip = widget.existing?.skipsReminder ?? false;
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      AttendanceOverride(
        id: widget.existing?.id,
        date: _date,
        kind: _kind,
        time: _skip ? null : _time,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('attendance_override_title')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${L10n.t('date')}: '),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(formatDate(_date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<AttendanceKind>(
              segments: [
                for (final kind in AttendanceKind.values)
                  ButtonSegment(value: kind, label: Text(L10n.t(kind.l10nKey))),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('${L10n.t('time')}: '),
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(_time?.format() ?? '--:--'),
                  onPressed: _skip
                      ? null
                      : () async {
                          final current = _time ?? const ClockTime(20, 0);
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                                hour: current.hour, minute: current.minute),
                          );
                          if (picked != null) {
                            setState(() =>
                                _time = ClockTime(picked.hour, picked.minute));
                          }
                        },
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(L10n.t('attendance_skip_title')),
              subtitle: Text(L10n.t('attendance_skip_sub'),
                  style: const TextStyle(fontSize: 12)),
              value: _skip,
              onChanged: (value) => setState(() => _skip = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: L10n.t('attendance_note'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('cancel'))),
        FilledButton(onPressed: _submit, child: Text(L10n.t('save'))),
      ],
    );
  }
}
