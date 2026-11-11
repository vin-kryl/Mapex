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
  /// Ignores where the user placed nodes; see [CanvasLayout] for that.
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

/// Where each node shows on the free canvas.
///
/// A node the user placed sits where they put it. A node that was never
/// placed keeps the spot the automatic layout gives it relative to its
/// parent, so new steps appear next to their parent wherever it was moved.
class CanvasLayout {
  const CanvasLayout({required this.rects, required this.edges});

  /// Where each visible node sits, in board coordinates (may be negative).
  final Map<String, Rect> rects;

  /// Parent and child id of each visible connection.
  final List<(String, String)> edges;

  /// The smallest box holding every node.
  Rect get bounds => rects.values.reduce((a, b) => a.expandToInclude(b));

  static CanvasLayout compute(
    Node root,
    LayoutDirection direction,
    LayoutSpec spec,
  ) {
    final auto = TreeLayout.compute(
      root,
      direction,
      LayoutSpec(
        nodeWidth: spec.nodeWidth,
        nodeHeight: spec.nodeHeight,
        siblingGap: spec.siblingGap,
        levelGap: spec.levelGap,
        padding: 0,
      ),
    );
    final rects = <String, Rect>{};
    void place(Node n, Rect? parentAuto, Rect? parentShown) {
      final own = auto.rects[n.id];
      if (own == null) return;
      final p = n.position;
      final Rect shown;
      if (p != null) {
        shown = Rect.fromLTWH(p.x, p.y, spec.nodeWidth, spec.nodeHeight);
      } else if (parentAuto != null && parentShown != null) {
        shown = own.shift(parentShown.topLeft - parentAuto.topLeft);
      } else {
        shown = own;
      }
      rects[n.id] = shown;
      if (n.collapsed) return;
      for (final kid in n.children) {
        place(kid, own, shown);
      }
    }

    place(root, null, null);
    return CanvasLayout(rects: rects, edges: auto.edges);
  }

  /// Only [id]'s branch, for focus mode.
  CanvasLayout branch(Node node) {
    final ids = <String>{};
    void walk(Node n) {
      if (!rects.containsKey(n.id)) return;
      ids.add(n.id);
      if (!n.collapsed) n.children.forEach(walk);
    }

    walk(node);
    return CanvasLayout(
      rects: {for (final id in ids) id: rects[id]!},
      edges: [
        for (final e in edges)
          if (ids.contains(e.$1) && ids.contains(e.$2)) e,
      ],
    );
  }
}
