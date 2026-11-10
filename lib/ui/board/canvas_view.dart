import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../settings/app_settings.dart';
import 'node_card.dart';
import 'tree_layout.dart';

/// The tree, laid out automatically, with pan and pinch-zoom.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.root,
    required this.direction,
    required this.selectedId,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleCollapse,
  });

  final Node root;
  final LayoutDirection direction;
  final String? selectedId;
  final ValueChanged<Node> onTap;
  final ValueChanged<Node> onLongPress;
  final ValueChanged<Node> onToggleCollapse;

  /// Phones get bigger nodes for thumbs.
  static LayoutSpec specFor(double screenWidth) => screenWidth < 600
      ? const LayoutSpec(
          nodeWidth: 168,
          nodeHeight: 60,
          siblingGap: 16,
          levelGap: 44,
          padding: 48,
        )
      : const LayoutSpec(
          nodeWidth: 200,
          nodeHeight: 56,
          siblingGap: 20,
          levelGap: 56,
          padding: 64,
        );

  static const minScale = 0.2;
  static const maxScale = 2.5;

  /// How far the first view may zoom out to fit a wide tree.
  static const fitMinScale = 0.55;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  final _controller = TransformationController();
  String? _centeredFor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// When a tree (or a focused branch) is first shown, zooms out to fit its
  /// width (down to [CanvasView.fitMinScale]) and centres the root.
  void _centre(TreeLayout layout, Size viewport) {
    final key = '${widget.root.id}/${widget.direction.name}';
    if (_centeredFor == key) return;
    _centeredFor = key;
    final scale = (viewport.width / layout.size.width).clamp(
      CanvasView.fitMinScale,
      1.0,
    );
    final rootRect = layout.rects[widget.root.id]!;
    final dx = widget.direction == LayoutDirection.topDown
        ? viewport.width / 2 - rootRect.center.dx * scale
        : 0.0;
    final dy = widget.direction == LayoutDirection.leftRight
        ? viewport.height / 2 - rootRect.center.dy * scale
        : 0.0;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = CanvasView.specFor(MediaQuery.sizeOf(context).width);
        final layout = TreeLayout.compute(widget.root, widget.direction, spec);
        _centre(layout, constraints.biggest);
        final scheme = Theme.of(context).colorScheme;
        final nodes = {
          for (final e in TreeOps.walk(widget.root)) e.node.id: e.node,
        };
        final taken = <String>{
          for (final n in nodes.values)
            if (n.type == NodeType.decision) ...n.chosenChildIds,
        };
        return InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: CanvasView.minScale,
          maxScale: CanvasView.maxScale,
          boundaryMargin: EdgeInsets.all(constraints.biggest.longestSide),
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EdgePainter(
                      layout: layout,
                      direction: widget.direction,
                      color: scheme.outline,
                      fadedIds: {
                        for (final n in nodes.values)
                          if (n.status == NodeStatus.eliminated) n.id,
                      },
                    ),
                  ),
                ),
                for (final entry in layout.rects.entries)
                  Positioned.fromRect(
                    rect: entry.value,
                    child: NodeCard(
                      key: ValueKey(entry.key),
                      node: nodes[entry.key]!,
                      selected: entry.key == widget.selectedId,
                      taken: taken.contains(entry.key),
                      onTap: () => widget.onTap(nodes[entry.key]!),
                      onLongPress: () => widget.onLongPress(nodes[entry.key]!),
                      onToggleCollapse: () =>
                          widget.onToggleCollapse(nodes[entry.key]!),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.layout,
    required this.direction,
    required this.color,
    required this.fadedIds,
  });

  final TreeLayout layout;
  final LayoutDirection direction;
  final Color color;
  final Set<String> fadedIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (parentId, childId) in layout.edges) {
      final a = layout.rects[parentId]!;
      final b = layout.rects[childId]!;
      final paint = Paint()
        ..color = fadedIds.contains(childId)
            ? color.withValues(alpha: 0.4)
            : color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      if (direction == LayoutDirection.topDown) {
        final start = a.bottomCenter;
        final end = b.topCenter;
        final midY = (start.dy + end.dy) / 2;
        path
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
      } else {
        final start = a.centerRight;
        final end = b.centerLeft;
        final midX = (start.dx + end.dx) / 2;
        path
          ..moveTo(start.dx, start.dy)
          ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.layout != layout || old.color != color || old.direction != direction;
}
