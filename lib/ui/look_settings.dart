import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../state/providers.dart';
import 'theme.dart';

/// The "Look" part of Settings: accent colour, node colours, status
/// colours and corner roundness.
class LookSettings extends ConsumerWidget {
  const LookSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    void save(AppSettings next) => notifier.update(next);

    Widget heading(String text, [String? sub]) => Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gap / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (sub != null) Text(sub, style: TextStyle(color: muted)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Main colour', 'Buttons, selection and highlights.'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ColorDot(
              color: null,
              label: 'Black and white',
              selected: s.accentColor == null,
              onTap: () => save(s.copyWith(accentColor: () => null)),
            ),
            for (final hex in _accentChoices)
              ColorDot(
                color: hexToColor(hex),
                label: hex,
                selected: s.accentColor == hex,
                onTap: () => save(s.copyWith(accentColor: () => hex)),
              ),
            _AddDot(
              tooltip: 'Another colour',
              onTap: () async {
                final hex = await pickColor(
                  context,
                  initial: s.accentColor ?? '#2563EB',
                );
                if (hex != null) save(s.copyWith(accentColor: () => hex));
              },
            ),
          ],
        ),
        const SizedBox(height: Metrics.gutter * 1.5),
        heading('Node colours', 'Offered when you colour-code a node.'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, hex) in s.nodeColors.indexed)
              ColorDot(
                color: hexToColor(hex),
                label: hex,
                selected: false,
                onTap: () async {
                  final result = await pickColor(
                    context,
                    initial: hex,
                    canRemove:
                        s.nodeColors.length > AppSettings.nodeColorsRange.min,
                  );
                  if (result == null) return;
                  final next = [...s.nodeColors];
                  if (result == removeColor) {
                    next.removeAt(i);
                  } else {
                    next[i] = result;
                  }
                  save(s.copyWith(nodeColors: next));
                },
              ),
            if (s.nodeColors.length < AppSettings.nodeColorsRange.max)
              _AddDot(
                tooltip: 'Add a colour',
                onTap: () async {
                  final hex = await pickColor(context, initial: '#E2E2E2');
                  if (hex != null) {
                    save(s.copyWith(nodeColors: [...s.nodeColors, hex]));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: Metrics.gutter * 1.5),
        heading('Status colours'),
        for (final (label, hex, apply) in [
          (
            'Decisions',
            s.decisionColor,
            (String v) => s.copyWith(decisionColor: v),
          ),
          ('Path taken', s.takenColor, (String v) => s.copyWith(takenColor: v)),
          ('Done', s.doneColor, (String v) => s.copyWith(doneColor: v)),
          ('Not yet', s.notYetColor, (String v) => s.copyWith(notYetColor: v)),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            trailing: ColorDot(
              color: hexToColor(hex),
              label: '$label colour',
              selected: false,
              onTap: () async {
                final v = await pickColor(context, initial: hex);
                if (v != null) save(apply(v));
              },
            ),
          ),
        const SizedBox(height: Metrics.gutter),
        Row(
          children: [
            Expanded(child: heading('Corner roundness')),
            Text('${s.cornerRadius.round()}', style: TextStyle(color: muted)),
          ],
        ),
        Slider(
          min: AppSettings.cornerRadiusRange.min,
          max: AppSettings.cornerRadiusRange.max,
          divisions: 14,
          value: s.cornerRadius,
          onChanged: (v) => save(s.copyWith(cornerRadius: v)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reset the look'),
            onPressed: () {
              const d = AppSettings.defaults;
              save(
                s.copyWith(
                  accentColor: () => d.accentColor,
                  nodeColors: d.nodeColors,
                  decisionColor: d.decisionColor,
                  takenColor: d.takenColor,
                  doneColor: d.doneColor,
                  notYetColor: d.notYetColor,
                  cornerRadius: d.cornerRadius,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _accentChoices = [
    '#2563EB',
    '#7C3AED',
    '#0F766E',
    '#16A34A',
    '#EA580C',
    '#DB2777',
  ];
}

/// Returned by [pickColor] when the user chose to remove the colour.
const removeColor = 'remove';

/// A grid of colours plus a field for any `#RRGGBB`. Returns the picked hex,
/// [removeColor], or null when cancelled.
Future<String?> pickColor(
  BuildContext context, {
  required String initial,
  bool canRemove = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ColorDialog(initial: initial, canRemove: canRemove),
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial, required this.canRemove});

  final String initial;
  final bool canRemove;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late final _hex = TextEditingController(text: widget.initial);

  String? get _valid {
    var t = _hex.text.trim();
    if (!t.startsWith('#')) t = '#$t';
    return AppSettings.hexColor.hasMatch(t) ? t.toUpperCase() : null;
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _valid;
    return AlertDialog(
      title: const Text('Pick a colour'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Palette.choices)
                  ColorDot(
                    color: c,
                    label: toHex(c),
                    size: 32,
                    selected: current == toHex(c),
                    onTap: () => setState(() => _hex.text = toHex(c)),
                  ),
              ],
            ),
            const SizedBox(height: Metrics.gutter),
            Row(
              children: [
                ColorDot(
                  color: current == null ? null : hexToColor(current),
                  label: 'Preview',
                  selected: false,
                  onTap: () {},
                ),
                const SizedBox(width: Metrics.gap),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    decoration: InputDecoration(
                      labelText: 'Hex',
                      hintText: '#RRGGBB',
                      errorText: current == null ? 'Like #2563EB' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (widget.canRemove)
          TextButton(
            onPressed: () => Navigator.of(context).pop(removeColor),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: current == null
              ? null
              : () => Navigator.of(context).pop(current),
          child: const Text('Use'),
        ),
      ],
    );
  }
}

String toHex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// A round colour swatch. [color] null shows the "none / black and white"
/// swatch.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size = 36,
  });

  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              gradient: color == null
                  ? const LinearGradient(
                      colors: [Palette.ink, Palette.ink, Palette.paper],
                      stops: [0, 0.5, 0.5],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDot extends StatelessWidget {
  const _AddDot({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline),
          ),
          child: Icon(Icons.add, size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
