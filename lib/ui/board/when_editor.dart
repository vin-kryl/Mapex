import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../../model/reminder.dart';
import '../../reminders/timing.dart';
import '../theme.dart';

/// A node's date, time and reminder as edited in the sheet.
class WhenValue {
  const WhenValue({this.date, this.time, this.reminder});

  factory WhenValue.of(Node n) {
    final day = Timing.day(n);
    final due = Timing.dueAt(n);
    return WhenValue(
      date: day,
      time: due == null ? null : TimeOfDay.fromDateTime(due),
      reminder: n.reminder,
    );
  }

  final DateTime? date;
  final TimeOfDay? time;

  /// Only kept when both a date and a time are set.
  final Reminder? reminder;

  DateTime? get timeAsDateTime {
    final d = date;
    final t = time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  WhenValue copyWith({
    DateTime? Function()? date,
    TimeOfDay? Function()? time,
    Reminder? Function()? reminder,
  }) => WhenValue(
    date: date != null ? date() : this.date,
    time: time != null ? time() : this.time,
    reminder: reminder != null ? reminder() : this.reminder,
  );
}

enum _Lead { useDefault, atTime, custom }

enum _Repeat { none, daily, weekly, everyHours, everyDays }

/// Date, time and reminder controls for the edit sheet.
class WhenEditor extends StatefulWidget {
  const WhenEditor({
    super.key,
    required this.value,
    required this.defaultLeadMinutes,
    required this.onChanged,
  });

  final WhenValue value;
  final int defaultLeadMinutes;
  final ValueChanged<WhenValue> onChanged;

  @override
  State<WhenEditor> createState() => _WhenEditorState();
}

class _WhenEditorState extends State<WhenEditor> {
  late final _leadCtrl = TextEditingController(
    text: '${widget.value.reminder?.leadMinutes ?? widget.defaultLeadMinutes}',
  );
  late final _everyCtrl = TextEditingController(text: _initialEvery());

  @override
  void dispose() {
    _leadCtrl.dispose();
    _everyCtrl.dispose();
    super.dispose();
  }

  String _initialEvery() {
    final m = widget.value.reminder?.intervalMinutes;
    if (m == null) return '2';
    return m % 1440 == 0 ? '${m ~/ 1440}' : '${(m / 60).ceil()}';
  }

  WhenValue get v => widget.value;

  _Lead get _lead {
    final r = v.reminder;
    if (r == null || r.leadMinutes == null) return _Lead.useDefault;
    return r.leadMinutes == 0 ? _Lead.atTime : _Lead.custom;
  }

  _Repeat get _repeat {
    final r = v.reminder;
    return switch (r?.repeat) {
      null || RepeatKind.none => _Repeat.none,
      RepeatKind.daily => _Repeat.daily,
      RepeatKind.weekly => _Repeat.weekly,
      RepeatKind.interval =>
        r!.intervalMinutes! % 1440 == 0
            ? _Repeat.everyDays
            : _Repeat.everyHours,
    };
  }

  void _setReminder(Reminder? r) =>
      widget.onChanged(v.copyWith(reminder: () => r));

  Reminder _rebuild({_Lead? lead, _Repeat? repeat}) {
    final l = lead ?? _lead;
    final rp = repeat ?? _repeat;
    final custom = int.tryParse(_leadCtrl.text);
    final every = int.tryParse(_everyCtrl.text) ?? 1;
    return Reminder(
      leadMinutes: switch (l) {
        _Lead.useDefault => null,
        _Lead.atTime => 0,
        _Lead.custom => (custom == null || custom < 0) ? 0 : custom,
      },
      repeat: switch (rp) {
        _Repeat.none => RepeatKind.none,
        _Repeat.daily => RepeatKind.daily,
        _Repeat.weekly => RepeatKind.weekly,
        _ => RepeatKind.interval,
      },
      intervalMinutes: switch (rp) {
        _Repeat.everyHours => (every < 1 ? 1 : every) * 60,
        _Repeat.everyDays => (every < 1 ? 1 : every) * 1440,
        _ => null,
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: v.date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) widget.onChanged(v.copyWith(date: () => picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: v.time ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    widget.onChanged(
      v.copyWith(time: () => picked, date: () => v.date ?? DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final hasTime = v.date != null && v.time != null;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.event, size: 18),
              label: Text(
                v.date == null ? 'Add date' : loc.formatMediumDate(v.date!),
              ),
              onPressed: _pickDate,
            ),
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(
                v.time == null ? 'Add time' : loc.formatTimeOfDay(v.time!),
              ),
              onPressed: _pickTime,
            ),
            if (v.date != null)
              IconButton(
                tooltip: 'Clear date and time',
                icon: const Icon(Icons.close),
                onPressed: () => widget.onChanged(const WhenValue()),
              ),
          ],
        ),
        if (hasTime) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me'),
            value: v.reminder != null,
            onChanged: (on) => _setReminder(on ? _rebuild() : null),
          ),
          if (v.reminder != null) ...[
            DropdownButtonFormField<_Lead>(
              initialValue: _lead,
              decoration: const InputDecoration(labelText: 'Heads-up'),
              items: [
                DropdownMenuItem(
                  value: _Lead.useDefault,
                  child: Text(
                    'Default (${_leadText(widget.defaultLeadMinutes)})',
                  ),
                ),
                const DropdownMenuItem(
                  value: _Lead.atTime,
                  child: Text('Only at the time'),
                ),
                const DropdownMenuItem(
                  value: _Lead.custom,
                  child: Text('Minutes before…'),
                ),
              ],
              onChanged: (l) => _setReminder(_rebuild(lead: l)),
            ),
            if (_lead == _Lead.custom) ...[
              const SizedBox(height: Metrics.gap),
              TextField(
                controller: _leadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes before'),
                onChanged: (_) => _setReminder(_rebuild()),
              ),
            ],
            const SizedBox(height: Metrics.gap),
            DropdownButtonFormField<_Repeat>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: const [
                DropdownMenuItem(value: _Repeat.none, child: Text('Never')),
                DropdownMenuItem(value: _Repeat.daily, child: Text('Daily')),
                DropdownMenuItem(value: _Repeat.weekly, child: Text('Weekly')),
                DropdownMenuItem(
                  value: _Repeat.everyHours,
                  child: Text('Every few hours'),
                ),
                DropdownMenuItem(
                  value: _Repeat.everyDays,
                  child: Text('Every few days'),
                ),
              ],
              onChanged: (r) => _setReminder(_rebuild(repeat: r)),
            ),
            if (_repeat == _Repeat.everyHours ||
                _repeat == _Repeat.everyDays) ...[
              const SizedBox(height: Metrics.gap),
              TextField(
                controller: _everyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _repeat == _Repeat.everyHours
                      ? 'Every how many hours'
                      : 'Every how many days',
                ),
                onChanged: (_) => _setReminder(_rebuild()),
              ),
            ],
          ],
        ] else if (v.date != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Add a time to get a reminder.',
              style: TextStyle(color: muted),
            ),
          ),
      ],
    );
  }

  static String _leadText(int minutes) {
    if (minutes == 0) return 'at the time';
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 hour before' : '$h hours before';
    }
    return '$minutes min before';
  }
}
