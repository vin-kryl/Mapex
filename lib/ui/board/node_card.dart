import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../theme.dart';
import 'node_style.dart';

/// A node on the canvas.
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
    final scheme = Theme.of(context).colorScheme;
    final accent = NodeStyle.parseColor(node.color);
    final eliminated = node.status == NodeStatus.eliminated;
    final decision = node.type == NodeType.decision;
    final border = selected
        ? Border.all(color: scheme.primary, width: 2)
        : Border.all(
            color: taken ? Look.of(context).taken : scheme.outline,
            width: taken ? 2 : 1,
          );
    final card = Container(
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.35) ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          decision ? Look.of(context).radius / 2 : Look.of(context).radius,
        ),
        border: border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            NodeStyle.statusIcon(node),
            size: 18,
            color: NodeStyle.statusColor(node, context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                decoration:
                    node.status == NodeStatus.done && node.type == NodeType.task
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (node.children.isNotEmpty)
            InkWell(
              onTap: onToggleCollapse,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: node.collapsed
                    ? _CountBadge(count: node.nodeCount - 1)
                    : Icon(
                        Icons.expand_less,
                        size: 18,
                        color: scheme.onSurfaceVariant,
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$count',
        style: TextStyle(fontSize: 11, color: scheme.onPrimary),
      ),
    );
  }
}
