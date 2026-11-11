import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../state/providers.dart';
import 'color_picker.dart';
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
