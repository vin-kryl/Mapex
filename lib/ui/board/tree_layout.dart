import 'dart:math' as math;
import 'dart:ui';

import '../../model/node.dart';
import '../../settings/app_settings.dart';

/// Sizes used to lay out the tree. Chosen per screen size by the caller.
class LayoutSpec {
  const LayoutSpec({
    required this.nodeWidth,
    required this.nodeHeight,
    required this.siblingGap,
    required this.levelGap,
    required this.padding,
  });

  final double nodeWidth;
  final double nodeHeight;
  final double siblingGap;
  final double levelGap;
  final double padding;
}

class TreeLayout {
  const TreeLayout({
    required this.rects,
    required this.edges,
    required this.size,
  });

  /// Where each visible node sits.
  final Map<String, Rect> rects;

  /// Parent and child id of each visible connection.
  final List<(String, String)> edges;
  final Size size;

  /// Lays out [root] automatically. Children of collapsed nodes are hidden.
  /// The user never positions nodes.
  static TreeLayout compute(
    Node root,
    LayoutDirection direction,
    LayoutSpec spec,
  ) {
    final topDown = direction == LayoutDirection.topDown;
    // "Breadth" runs across siblings, "depth" runs down the levels.
    final breadth = topDown ? spec.nodeWidth : spec.nodeHeight;
    final depthStep =
        (topDown ? spec.nodeHeight : spec.nodeWidth) + spec.levelGap;

    final span = <String, double>{};
    double measure(Node n) {
      final kids = n.collapsed ? const <Node>[] : n.children;
      var total = 0.0;
      for (var i = 0; i < kids.length; i++) {
        total += measure(kids[i]);
        if (i > 0) total += spec.siblingGap;
      }
      return span[n.id] = math.max(breadth, total);
    }

    measure(root);

    final rects = <String, Rect>{};
    final edges = <(String, String)>[];
    var maxDepth = 0;

    void place(Node n, double start, int depth) {
      maxDepth = math.max(maxDepth, depth);
      final mySpan = span[n.id]!;
      final across = start + (mySpan - breadth) / 2;
      final down = depth * depthStep;
      rects[n.id] = topDown
          ? Rect.fromLTWH(
              spec.padding + across,
              spec.padding + down,
              spec.nodeWidth,
              spec.nodeHeight,
            )
          : Rect.fromLTWH(
              spec.padding + down,
              spec.padding + across,
              spec.nodeWidth,
              spec.nodeHeight,
            );
      final kids = n.collapsed ? const <Node>[] : n.children;
      if (kids.isEmpty) return;
      var total = 0.0;
      for (var i = 0; i < kids.length; i++) {
        total += span[kids[i].id]!;
        if (i > 0) total += spec.siblingGap;
      }
      var cursor = start + (mySpan - total) / 2;
      for (final kid in kids) {
        edges.add((n.id, kid.id));
        place(kid, cursor, depth + 1);
        cursor += span[kid.id]! + spec.siblingGap;
      }
    }

    place(root, 0, 0);

    final across = span[root.id]!;
    final down =
        maxDepth * depthStep + (topDown ? spec.nodeHeight : spec.nodeWidth);
    final size = topDown
        ? Size(across + spec.padding * 2, down + spec.padding * 2)
        : Size(down + spec.padding * 2, across + spec.padding * 2);
    return TreeLayout(rects: rects, edges: edges, size: size);
  }
}
