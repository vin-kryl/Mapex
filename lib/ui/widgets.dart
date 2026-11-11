import 'package:flutter/material.dart';

import 'theme.dart';

/// Rows in one rounded box with thin lines between them, like a grouped
/// list in Apple's apps.
class GroupedBox extends StatelessWidget {
  const GroupedBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final radius = BorderRadius.circular(isApple ? 10 : 16);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: radius,
        border: Border.all(color: t.hairline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Divider(height: 0.5, color: t.hairline),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section: a small grey heading, an optional link, then its content.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: sectionLabel(context))),
              if (action != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    action!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Quiet centred text for an empty or failed state.
class QuietMessage extends StatelessWidget {
  const QuietMessage({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Metrics.gutter * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: t.tertiary),
              const SizedBox(height: 12),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: t.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
