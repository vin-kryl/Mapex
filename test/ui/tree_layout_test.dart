import 'package:flutter_test/flutter_test.dart';
import 'package:sortle/model/node.dart';
import 'package:sortle/settings/app_settings.dart';
import 'package:sortle/ui/board/tree_layout.dart';

final t0 = DateTime.utc(2026);

Node n(String id, [List<Node> children = const []]) => Node(
  id: id,
  title: id,
  type: NodeType.task,
  status: NodeStatus.pending,
  createdAt: t0,
  updatedAt: t0,
  children: children,
);

const spec = LayoutSpec(
  nodeWidth: 100,
  nodeHeight: 40,
  siblingGap: 10,
  levelGap: 20,
  padding: 0,
);

void main() {
  final tree = n('r', [
    n('a', [n('a1'), n('a2')]),
    n('b'),
  ]);

  test('top down: levels go down, parents sit over their children', () {
    final l = TreeLayout.compute(tree, LayoutDirection.topDown, spec);
    expect(l.rects['r']!.top, 0);
    expect(l.rects['a']!.top, 60);
    expect(l.rects['a1']!.top, 120);
    expect(
      l.rects['a']!.center.dx,
      (l.rects['a1']!.center.dx + l.rects['a2']!.center.dx) / 2,
    );
    expect(l.edges, hasLength(4));
    expect(l.size.width, 320);
  });

  test('no two nodes overlap', () {
    final l = TreeLayout.compute(tree, LayoutDirection.topDown, spec);
    final rects = l.rects.values.toList();
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
  });

  test('left to right: levels go right', () {
    final l = TreeLayout.compute(tree, LayoutDirection.leftRight, spec);
    expect(l.rects['r']!.left, 0);
    expect(l.rects['a']!.left, 120);
    expect(l.rects['a1']!.left, 240);
  });

  test('collapsed branches are hidden', () {
    final collapsed = tree.copyWith(
      children: [tree.children[0].copyWith(collapsed: true), tree.children[1]],
    );
    final l = TreeLayout.compute(collapsed, LayoutDirection.topDown, spec);
    expect(l.rects.keys, unorderedEquals(['r', 'a', 'b']));
  });

  group('free canvas', () {
    test('nothing placed looks like the automatic layout', () {
      final auto = TreeLayout.compute(tree, LayoutDirection.topDown, spec);
      final free = CanvasLayout.compute(tree, LayoutDirection.topDown, spec);
      expect(free.rects, auto.rects);
      expect(free.edges, auto.edges);
    });

    test('a placed node sits where it was put, alone', () {
      final moved = tree.copyWith(
        children: [
          tree.children[0],
          tree.children[1].copyWith(
            position: () => const NodePosition(-500, 90),
          ),
        ],
      );
      final before = CanvasLayout.compute(tree, LayoutDirection.topDown, spec);
      final after = CanvasLayout.compute(moved, LayoutDirection.topDown, spec);
      expect(after.rects['b']!.topLeft, const Offset(-500, 90));
      for (final id in ['r', 'a', 'a1', 'a2']) {
        expect(after.rects[id], before.rects[id]);
      }
      expect(after.bounds.left, -500);
    });

    test('unplaced children follow a moved parent', () {
      final moved = tree.copyWith(
        children: [
          tree.children[0].copyWith(
            position: () => const NodePosition(1000, 0),
          ),
          tree.children[1],
        ],
      );
      final before = CanvasLayout.compute(tree, LayoutDirection.topDown, spec);
      final after = CanvasLayout.compute(moved, LayoutDirection.topDown, spec);
      final shift = after.rects['a']!.topLeft - before.rects['a']!.topLeft;
      expect(after.rects['a1'], before.rects['a1']!.shift(shift));
      expect(after.rects['a2'], before.rects['a2']!.shift(shift));
    });

    test('focus keeps only the branch', () {
      final l = CanvasLayout.compute(tree, LayoutDirection.topDown, spec);
      final b = l.branch(tree.children[0]);
      expect(b.rects.keys, unorderedEquals(['a', 'a1', 'a2']));
      expect(b.edges, hasLength(2));
    });
  });
}
