import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import 'theme.dart';

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
                    label: colorToHex(c),
                    size: 32,
                    selected: current == colorToHex(c),
                    onTap: () => setState(() => _hex.text = colorToHex(c)),
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

/// A round colour swatch. [color] null shows the "none / black and white"
/// swatch. [icon], if given, is drawn in the middle.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size = 36,
    this.icon,
  });

  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final IconData? icon;

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
            child: icon == null
                ? null
                : Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
