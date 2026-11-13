import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../settings/app_settings.dart';
import '../theme.dart';
import 'node_card.dart';
import 'tree_layout.dart';

/// The board as a free canvas: pan, pinch-zoom, and drag any node on its own.
/// Wires follow the nodes. Dropping a node on another one attaches it there.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.root,
    required this.shown,
    required this.direction,
    required this.selectedId,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleCollapse,
    required this.onPlace,
    required this.onDropOn,
  });

  /// The whole board.
  final Node root;

  /// The branch on screen: [root], or the focused node.
  final Node shown;
  final LayoutDirection direction;
  final String? selectedId;
  final ValueChanged<Node> onTap;
  final ValueChanged<Node> onLongPress;
  final ValueChanged<Node> onToggleCollapse;

  /// Nodes moved on the canvas, with where they now sit.
  final ValueChanged<Map<String, NodePosition>> onPlace;

  /// A node dropped onto a new parent, with where nodes now sit.
  final void Function(
    String id,
    String newParentId,
    Map<String, NodePosition> positions,
  )
  onDropOn;

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

  /// Spacing of the dot grid behind the nodes.
  static const gridStep = 24.0;

  /// How far a finger or pointer must move before a hold turns into a drag.
  static const dragSlop = 6.0;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  final _controller = TransformationController();
  String? _centeredFor;

  /// Board coordinates of the content's top-left corner last frame.
  Offset? _origin;

  String? _dragId;
  Offset _dragStartGlobal = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _dragMoved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _scale => _controller.value.getMaxScaleOnAxis();

  /// When a board (or a focused branch) is first shown, zooms out to fit its
  /// width (down to [CanvasView.fitMinScale]) and centres the top node.
  void _centre(Rect content, Rect top, Size viewport) {
    final key = '${widget.shown.id}/${widget.direction.name}';
    if (_centeredFor == key) return;
    _centeredFor = key;
    final scale = (viewport.width / content.width).clamp(
      CanvasView.fitMinScale,
      1.0,
    );
    final dx = widget.direction == LayoutDirection.topDown
        ? viewport.width / 2 - top.center.dx * scale
        : 0.0;
    final dy = widget.direction == LayoutDirection.leftRight
        ? viewport.height / 2 - top.center.dy * scale
        : 0.0;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// The content grows and shrinks as nodes move. Keeps what is on screen
  /// still when its top-left corner shifts.
  void _keepStill(Offset origin) {
    final old = _origin;
    _origin = origin;
    if (old == null || old == origin) return;
    final shift = (origin - old) * _scale;
    _controller.value = Matrix4.translationValues(shift.dx, shift.dy, 0)
      ..multiply(_controller.value);
  }

  void _startDrag(String id, Offset global) {
    setState(() {
      _dragId = id;
      _dragStartGlobal = global;
      _dragDelta = Offset.zero;
      _dragMoved = false;
    });
  }

  void _updateDrag(Offset global) {
    if (_dragId == null) return;
    final moved = global - _dragStartGlobal;
    setState(() {
      _dragDelta = moved / _scale;
      _dragMoved = _dragMoved || moved.distance > CanvasView.dragSlop;
    });
  }

  /// Ends a drag. Returns false if the pointer never really moved.
  bool _endDrag(CanvasLayout layout) {
    final id = _dragId;
    final moved = _dragMoved;
    final delta = _dragDelta;
    setState(() {
      _dragId = null;
      _dragDelta = Offset.zero;
      _dragMoved = false;
    });
    if (id == null || !moved) return false;
    final dropped = layout.rects[id]!.shift(delta);
    final target = _dropTarget(layout, id, dropped);
    // Pin everything on screen, so only the dragged node moves.
    final positions = <String, NodePosition>{
      for (final e in layout.rects.entries)
        if (TreeOps.find(widget.root, e.key)?.position == null)
          e.key: NodePosition(e.value.left, e.value.top),
      id: NodePosition(dropped.left, dropped.top),
    };
    if (target != null) {
      widget.onDropOn(id, target, positions);
    } else {
      widget.onPlace(positions);
    }
    return true;
  }

  /// The node under the dragged one's centre, if it may become its parent.
  String? _dropTarget(CanvasLayout layout, String id, Rect dragged) {
    final allowed = {
      for (final n in TreeOps.moveTargets(widget.root, id)) n.id,
    };
    for (final e in layout.rects.entries) {
      if (e.key == id || !allowed.contains(e.key)) continue;
      if (e.value.contains(dragged.center)) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = CanvasView.specFor(MediaQuery.sizeOf(context).width);
        final full = CanvasLayout.compute(widget.root, widget.direction, spec);
        final layout = widget.shown.id == widget.root.id
            ? full
            : full.branch(widget.shown);
        final pad = spec.padding;
        final bounds = layout.bounds.inflate(pad);
        // Snap to the grid so the dots don't jump as the content grows.
        final origin = Offset(
          (bounds.left / CanvasView.gridStep).floor() * CanvasView.gridStep,
          (bounds.top / CanvasView.gridStep).floor() * CanvasView.gridStep,
        );
        final size = Size(bounds.right - origin.dx, bounds.bottom - origin.dy);
        _keepStill(origin);
        _centre(
          Offset.zero & size,
          layout.rects[widget.shown.id]!.shift(-origin),
          constraints.biggest,
        );

        final t = Tones.of(context);
        final look = Look.of(context);
        final nodes = {
          for (final e in TreeOps.walk(widget.root)) e.node.id: e.node,
        };
        final taken = <String>{
          for (final n in nodes.values)
            if (n.type == NodeType.decision) ...n.chosenChildIds,
        };
        final shownRects = {
          for (final e in layout.rects.entries)
            e.key: e.key == _dragId ? e.value.shift(_dragDelta) : e.value,
        };
        final target = _dragId != null && _dragMoved
            ? _dropTarget(layout, _dragId!, shownRects[_dragId]!)
            : null;
        // The dragged node is drawn last, above the others.
        final order = [
          for (final id in shownRects.keys)
            if (id != _dragId) id,
          ?_dragId,
        ];

        final viewer = InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: CanvasView.minScale,
          maxScale: CanvasView.maxScale,
          boundaryMargin: EdgeInsets.all(constraints.biggest.longestSide),
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EdgePainter(
                      rects: shownRects,
                      edges: layout.edges,
                      origin: origin,
                      direction: widget.direction,
                      color: t.wire,
                      takenColor: look.taken,
                      takenIds: taken,
                      fadedIds: {
                        for (final n in nodes.values)
                          if (n.status == NodeStatus.eliminated) n.id,
                      },
                    ),
                  ),
                ),
                for (final id in order)
                  Positioned.fromRect(
                    key: ValueKey(id),
                    rect: shownRects[id]!.shift(-origin),
                    child: _Draggable(
                      dragging: id == _dragId && _dragMoved,
                      target: id == target,
                      onStart: (g) => _startDrag(id, g),
                      onUpdate: _updateDrag,
                      onEnd: () => _endDrag(layout),
                      onHeld: () {
                        if (!_endDrag(layout)) {
                          widget.onLongPress(nodes[id]!);
                        }
                      },
                      onSecondaryTap: () => widget.onLongPress(nodes[id]!),
                      child: NodeCard(
                        node: nodes[id]!,
                        selected: id == widget.selectedId,
                        taken: taken.contains(id),
                        onTap: () => widget.onTap(nodes[id]!),
                        onLongPress: null,
                        onToggleCollapse: () =>
                            widget.onToggleCollapse(nodes[id]!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        return ColoredBox(
          color: t.canvas,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    transform: _controller,
                    color: t.gridDot,
                    step: CanvasView.gridStep,
                  ),
                ),
              ),
              viewer,
              Positioned(
                right: 16,
                bottom: 16,
                child: _ZoomControls(
                  transform: _controller,
                  onZoom: (f) => _zoomBy(f, constraints.biggest),
                  onFit: () => setState(() => _centeredFor = null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _zoomBy(double factor, Size viewport) {
    final next = (_scale * factor).clamp(
      CanvasView.minScale,
      CanvasView.maxScale,
    );
    final f = next / _scale;
    final c = viewport.center(Offset.zero);
    _controller.value = Matrix4.translationValues(c.dx, c.dy, 0)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(_controller.value);
  }
}

/// Mouse, trackpad and pen drag a node straight away. A finger holds the
/// node first, so a quick swipe still pans the board.
class _Draggable extends StatelessWidget {
  const _Draggable({
    required this.dragging,
    required this.target,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onHeld,
    required this.onSecondaryTap,
    required this.child,
  });

  final bool dragging;

  /// Another node is being held over this one and would attach here.
  final bool target;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  /// A finger lifted after holding: a drop if it moved, else the menu.
  final VoidCallback onHeld;
  final VoidCallback onSecondaryTap;
  final Widget child;

  static const _pointers = {
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      supportedDevices: _pointers,
      onPanStart: (d) => onStart(d.globalPosition),
      onPanUpdate: (d) => onUpdate(d.globalPosition),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      onSecondaryTap: onSecondaryTap,
      child: GestureDetector(
        supportedDevices: const {PointerDeviceKind.touch},
        onLongPressStart: (d) => onStart(d.globalPosition),
        onLongPressMoveUpdate: (d) => onUpdate(d.globalPosition),
        onLongPressEnd: (_) => onHeld(),
        onLongPressCancel: onEnd,
        child: AnimatedScale(
          scale: dragging ? 1.04 : 1,
          duration: const Duration(milliseconds: 120),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Look.of(context).radius),
              border: target
                  ? Border.all(color: scheme.primary, width: 2.5)
                  : null,
              boxShadow: dragging
                  ? [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Dots behind the board that pan and zoom with it.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.transform,
    required this.color,
    required this.step,
  }) : super(repaint: transform);

  final TransformationController transform;
  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final m = transform.value;
    final scale = m.getMaxScaleOnAxis();
    // Too dense when zoomed far out: skip every other dot.
    final gap = step * scale * (scale < 0.5 ? 2 : 1);
    final dx = m.getTranslation().x % gap;
    final dy = m.getTranslation().y % gap;
    final paint = Paint()..color = color;
    final r = (1.1 * scale).clamp(0.7, 1.4);
    for (var x = dx; x < size.width; x += gap) {
      for (var y = dy; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.color != color || old.step != step;
}

/// Zoom out, zoom level, zoom in, and fit, in one small pill.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.transform,
    required this.onZoom,
    required this.onFit,
  });

  final TransformationController transform;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    Widget button(String tip, IconData icon, VoidCallback onTap) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: t.secondary),
        ),
      ),
    );
    return Material(
      color: t.card.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: t.hairline, width: 0.5),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('Zoom out', Icons.remove_rounded, () => onZoom(1 / 1.25)),
          ValueListenableBuilder(
            valueListenable: transform,
            builder: (context, m, _) => SizedBox(
              width: 42,
              child: Text(
                '${(m.getMaxScaleOnAxis() * 100).round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: t.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          button('Zoom in', Icons.add_rounded, () => onZoom(1.25)),
          Container(width: 0.5, height: 18, color: t.hairline),
          button('Fit to screen', Icons.fit_screen_outlined, onFit),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.rects,
    required this.edges,
    required this.origin,
    required this.direction,
    required this.color,
    required this.takenColor,
    required this.takenIds,
    required this.fadedIds,
  });

  final Map<String, Rect> rects;
  final List<(String, String)> edges;
  final Offset origin;
  final LayoutDirection direction;
  final Color color;
  final Color takenColor;
  final Set<String> takenIds;
  final Set<String> fadedIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (parentId, childId) in edges) {
      final a = rects[parentId]!.shift(-origin);
      final b = rects[childId]!.shift(-origin);
      final faded = fadedIds.contains(childId);
      final taken = takenIds.contains(childId);
      final paint = Paint()
        ..color = taken
            ? takenColor
            : faded
            ? color.withValues(alpha: 0.45)
            : color
        ..strokeWidth = taken ? 1.6 : 1.1
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = wire(a, b, direction);
      canvas.drawPath(path, paint);
      // A small port where the wire leaves the parent.
      final start = path.computeMetrics().first.getTangentForOffset(0)!;
      canvas.drawCircle(start.position, 2.8, Paint()..color = paint.color);
    }
  }

  /// A smooth curve between two nodes, leaving from whichever sides face
  /// each other, so it reads well wherever the nodes were dragged. When the
  /// nodes are clear of each other along the board's direction, that
  /// direction wins.
  static Path wire(Rect a, Rect b, LayoutDirection direction) {
    const clear = 8.0;
    final below = b.top >= a.bottom + clear;
    final above = b.bottom <= a.top - clear;
    final right = b.left >= a.right + clear;
    final left = b.right <= a.left - clear;
    final vertical = direction == LayoutDirection.topDown
        ? (below || above)
        : !(right || left) && (below || above);
    final Offset start, end, bend;
    if (vertical) {
      final down = b.center.dy >= a.center.dy;
      start = down ? a.bottomCenter : a.topCenter;
      end = down ? b.topCenter : b.bottomCenter;
      bend =
          Offset(0, math.max((end.dy - start.dy).abs() / 2, 24)) *
          (down ? 1 : -1);
    } else {
      final toRight = b.center.dx >= a.center.dx;
      start = toRight ? a.centerRight : a.centerLeft;
      end = toRight ? b.centerLeft : b.centerRight;
      bend =
          Offset(math.max((end.dx - start.dx).abs() / 2, 24), 0) *
          (toRight ? 1 : -1);
    }
    final c1 = start + bend;
    final c2 = end - bend;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}
