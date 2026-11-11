import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/board.dart';
import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../settings/app_settings.dart';
import '../theme.dart';
import 'tree_layout.dart';

/// A small live picture of a board: its nodes and wires, scaled to fit.
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key, required this.board, required this.direction});

  final Board board;
  final LayoutDirection direction;

  static const _spec = LayoutSpec(
    nodeWidth: 200,
    nodeHeight: 56,
    siblingGap: 20,
    levelGap: 56,
    padding: 0,
  );

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final look = Look.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.grouped,
        borderRadius: BorderRadius.circular(look.radius),
        border: Border.all(color: t.hairline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(look.radius),
        child: CustomPaint(
          painter: _PreviewPainter(
            layout: CanvasLayout.compute(board.root, direction, _spec),
            root: board.root,
            card: t.card,
            edge: t.hairline,
            wire: t.wire,
            taken: look.taken,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.layout,
    required this.root,
    required this.card,
    required this.edge,
    required this.wire,
    required this.taken,
  });

  final CanvasLayout layout;
  final Node root;
  final Color card;
  final Color edge;
  final Color wire;
  final Color taken;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = layout.bounds;
    const pad = 16.0;
    final scale = math.min(
      math.min(
        (size.width - pad * 2) / bounds.width,
        (size.height - pad * 2) / bounds.height,
      ),
      0.5,
    );
    final offset = size.center(Offset.zero) - bounds.center * scale;
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
    final nodes = {for (final e in TreeOps.walk(root)) e.node.id: e.node};
    final takenIds = {
      for (final n in nodes.values)
        if (n.type == NodeType.decision) ...n.chosenChildIds,
    };
    final stroke = 1 / scale;
    for (final (p, c) in layout.edges) {
      final a = layout.rects[p]!;
      final b = layout.rects[c]!;
      final faded = nodes[c]?.status == NodeStatus.eliminated;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * (takenIds.contains(c) ? 1.4 : 1)
        ..color = takenIds.contains(c)
            ? taken
            : wire.withValues(alpha: faded ? 0.4 : 1);
      final vertical = b.top >= a.bottom;
      final start = vertical ? a.bottomCenter : a.centerRight;
      final end = vertical ? b.topCenter : b.centerLeft;
      final mid = (start + end) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            vertical ? start.dx : mid.dx,
            vertical ? mid.dy : start.dy,
            vertical ? end.dx : mid.dx,
            vertical ? mid.dy : end.dy,
            end.dx,
            end.dy,
          ),
        paint,
      );
    }
    for (final e in layout.rects.entries) {
      final faded = nodes[e.key]?.status == NodeStatus.eliminated;
      final r = RRect.fromRectAndRadius(e.value, const Radius.circular(14));
      canvas
        ..drawRRect(r, Paint()..color = card.withValues(alpha: faded ? 0.5 : 1))
        ..drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = takenIds.contains(e.key) ? taken : edge,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.layout != layout || old.card != card || old.taken != taken;
}
