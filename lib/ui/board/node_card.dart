import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../theme.dart';
import 'node_style.dart';

/// A node on the canvas: a plain card with a status mark, its title and one
/// quiet line of detail.
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.taken,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleCollapse,
  });

  final Node node;
  final bool selected;

  /// Picked as the path taken by its parent decision.
  final bool taken;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final look = Look.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final colour = NodeStyle.parseColor(node.color);
    final eliminated = node.status == NodeStatus.eliminated;
    final doneTask =
        node.status == NodeStatus.done && node.type == NodeType.task;
    final detail = NodeStyle.detail(node, DateTime.now(), taken: taken);
    final radius = BorderRadius.circular(look.radius);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: radius,
        boxShadow: [
          if (selected) BoxShadow(color: accent, spreadRadius: 2),
          if (selected)
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              spreadRadius: 6,
              blurRadius: 2,
            )
          else if (taken && !eliminated)
            BoxShadow(color: look.taken, spreadRadius: 1)
          else
            BoxShadow(color: t.hairline, spreadRadius: 0.5),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          StatusMark(node: node, taken: taken),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  maxLines: detail == null ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: doneTask ? t.secondary : t.text,
                  ),
                ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: switch (detail.tone) {
                          DetailTone.late => Palette.danger,
                          DetailTone.taken => look.taken,
                          DetailTone.plain => t.secondary,
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (node.voiceNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.mic_none_rounded, size: 14, color: t.secondary),
            ),
          if (colour != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
          if (node.children.isNotEmpty)
            Tooltip(
              message: node.collapsed ? 'Show steps' : 'Hide steps',
              child: InkWell(
                onTap: onToggleCollapse,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
                  child: node.collapsed
                      ? _CountBadge(count: node.nodeCount - 1)
                      : Icon(
                          Icons.expand_less_rounded,
                          size: 16,
                          color: t.secondary,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${NodeStyle.typeLabel(node.type)}: ${node.title}, '
          '${NodeStyle.statusLabel(node.status)}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: eliminated ? NodeStyle.eliminatedOpacity : 1,
          child: card,
        ),
      ),
    );
  }
}

/// The small mark at the start of a node: an empty circle to do, a filled
/// check when done, a diamond for a decision.
class StatusMark extends StatelessWidget {
  const StatusMark({super.key, required this.node, this.taken = false});

  final Node node;
  final bool taken;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final look = Look.of(context);
    const size = 17.0;
    Widget filled(Color c, IconData icon) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Icon(icon, size: 12, color: Colors.white),
    );
    if (node.type == NodeType.decision &&
        node.status != NodeStatus.eliminated) {
      final decided = node.chosenChildIds.isNotEmpty;
      return Icon(
        decided ? Icons.diamond : Icons.diamond_outlined,
        size: size,
        color: decided ? look.taken : look.decision,
      );
    }
    return switch (node.status) {
      NodeStatus.done => filled(look.done, Icons.check_rounded),
      NodeStatus.notYet => Icon(
        Icons.schedule_rounded,
        size: size,
        color: look.notYet,
      ),
      NodeStatus.eliminated => Icon(
        Icons.remove_circle_outline_rounded,
        size: size,
        color: t.secondary,
      ),
      NodeStatus.pending =>
        taken
            ? filled(look.taken, Icons.check_rounded)
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.tertiary, width: 1.5),
                ),
              ),
    };
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: t.grouped,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.hairline, width: 0.5),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.secondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
