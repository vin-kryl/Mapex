import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../theme.dart';
import 'node_style.dart';

/// The same tree as an indented list.
class OutlineView extends StatelessWidget {
  const OutlineView({
    super.key,
    required this.root,
    required this.selectedId,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleCollapse,
  });

  final Node root;
  final String? selectedId;
  final ValueChanged<Node> onTap;
  final ValueChanged<Node> onLongPress;
  final ValueChanged<Node> onToggleCollapse;

  /// Indent per level, and the most a row may be indented as a share of
  /// the screen, so deep trees never scroll sideways.
  static const indentStep = 20.0;
  static const maxIndentShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final rows = <({Node node, int depth})>[];
    void collect(Node n, int depth) {
      rows.add((node: n, depth: depth));
      if (n.collapsed) return;
      for (final c in n.children) {
        collect(c, depth + 1);
      }
    }

    collect(root, 0);
    final width = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Metrics.gutter / 2,
        Metrics.gutter / 2,
        Metrics.gutter,
        Metrics.gutter * 8,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (:node, :depth) = rows[i];
        final indent = math.min(depth * indentStep, width * maxIndentShare);
        final eliminated = node.status == NodeStatus.eliminated;
        final selected = node.id == selectedId;
        return Opacity(
          opacity: eliminated ? NodeStyle.eliminatedOpacity : 1,
          child: Material(
            color: selected ? scheme.surfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(Look.of(context).radius / 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(Look.of(context).radius / 2),
              onTap: () => onTap(node),
              onLongPress: () => onLongPress(node),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    SizedBox(width: indent),
                    SizedBox(
                      width: 40,
                      child: node.children.isEmpty
                          ? null
                          : IconButton(
                              tooltip: node.collapsed ? 'Expand' : 'Collapse',
                              iconSize: 20,
                              icon: Icon(
                                node.collapsed
                                    ? Icons.chevron_right
                                    : Icons.expand_more,
                              ),
                              onPressed: () => onToggleCollapse(node),
                            ),
                    ),
                    Icon(
                      NodeStyle.statusIcon(node),
                      size: 18,
                      color: NodeStyle.statusColor(node, context),
                    ),
                    const SizedBox(width: 10),
                    if (NodeStyle.parseColor(node.color) case final c?)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        node.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: depth == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          decoration:
                              node.status == NodeStatus.done &&
                                  node.type == NodeType.task
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (node.collapsed && node.children.isNotEmpty)
                      Text(
                        '+${node.nodeCount - 1}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
