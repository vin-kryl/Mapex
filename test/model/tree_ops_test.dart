import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/model/tree_ops.dart';

final t0 = DateTime.utc(2026, 11, 10);
final t1 = DateTime.utc(2026, 11, 11);

Node n(
  String id, {
  NodeType type = NodeType.task,
  NodeStatus status = NodeStatus.pending,
  List<Node> children = const [],
}) => Node(
  id: id,
  title: id,
  type: type,
  status: status,
  createdAt: t0,
  updatedAt: t0,
  children: children,
);

NodeStatus statusOf(Node root, String id) => TreeOps.find(root, id)!.status;

void main() {
  // root (task)
  // ├─ a (task): a1, a2
  // └─ d (decision): x, y, z
  late Node tree;
  setUp(() {
    tree = n(
      'root',
      children: [
        n('a', children: [n('a1'), n('a2')]),
        n('d', type: NodeType.decision, children: [n('x'), n('y'), n('z')]),
      ],
    );
  });

  group('basic edits', () {
    test('add puts the child last and expands the parent', () {
      final collapsed = TreeOps.setCollapsed(tree, 'a', true);
      final next = TreeOps.addChild(collapsed, 'a', n('a3'));
      final a = TreeOps.find(next, 'a')!;
      expect(a.children.map((c) => c.id), ['a1', 'a2', 'a3']);
      expect(a.collapsed, isFalse);
    });

    test('edits leave the original tree untouched', () {
      TreeOps.remove(tree, 'a');
      expect(TreeOps.find(tree, 'a'), isNotNull);
    });

    test('remove takes the whole branch and clears picks', () {
      var next = TreeOps.decide(tree, 'd', {'x'}, t1);
      next = TreeOps.remove(next, 'x');
      expect(TreeOps.find(next, 'x'), isNull);
      expect(TreeOps.find(next, 'd')!.chosenChildIds, isEmpty);
      expect(() => TreeOps.remove(tree, 'root'), throwsArgumentError);
    });

    test('reorder moves within siblings and stops at the ends', () {
      var next = TreeOps.reorder(tree, 'a2', -1);
      expect(TreeOps.find(next, 'a')!.children.map((c) => c.id), ['a2', 'a1']);
      next = TreeOps.reorder(next, 'a2', -1);
      expect(TreeOps.find(next, 'a')!.children.first.id, 'a2');
    });

    test('move re-parents a branch, never into itself', () {
      final next = TreeOps.move(tree, 'a', 'x');
      expect(TreeOps.parentOf(next, 'a')!.id, 'x');
      expect(TreeOps.find(next, 'a1'), isNotNull);
      expect(() => TreeOps.move(tree, 'a', 'a1'), throwsArgumentError);
      final targets = TreeOps.moveTargets(tree, 'a').map((t) => t.id);
      expect(targets, isNot(contains('a')));
      expect(targets, isNot(contains('a1')));
      expect(targets, isNot(contains('root')));
      expect(targets, contains('x'));
    });

    test('pathTo lists ancestors in order', () {
      expect(TreeOps.pathTo(tree, 'a2'), ['root', 'a', 'a2']);
      expect(TreeOps.pathTo(tree, 'nope'), isEmpty);
    });
  });

  group('decisions', () {
    test('picking one eliminates and collapses the others', () {
      final next = TreeOps.decide(tree, 'd', {'y'}, t1);
      final d = TreeOps.find(next, 'd')!;
      expect(d.chosenChildIds, ['y']);
      expect(d.status, NodeStatus.done);
      expect(statusOf(next, 'y'), NodeStatus.pending);
      for (final id in ['x', 'z']) {
        final c = TreeOps.find(next, id)!;
        expect(c.status, NodeStatus.eliminated);
        expect(c.collapsed, isTrue);
      }
    });

    test('several can be picked', () {
      final next = TreeOps.decide(tree, 'd', {'x', 'z'}, t1);
      expect(TreeOps.find(next, 'd')!.chosenChildIds, ['x', 'z']);
      expect(statusOf(next, 'y'), NodeStatus.eliminated);
    });

    test('picking none leaves everything pending', () {
      var next = TreeOps.decide(tree, 'd', {'x'}, t1);
      next = TreeOps.decide(next, 'd', {}, t1);
      final d = TreeOps.find(next, 'd')!;
      expect(d.chosenChildIds, isEmpty);
      expect(d.status, NodeStatus.pending);
      for (final id in ['x', 'y', 'z']) {
        expect(statusOf(next, id), NodeStatus.pending);
      }
    });

    test('changing your mind brings an eliminated child back', () {
      var next = TreeOps.decide(tree, 'd', {'x'}, t1);
      next = TreeOps.decide(next, 'd', {'y'}, t1);
      expect(statusOf(next, 'x'), NodeStatus.eliminated);
      expect(statusOf(next, 'y'), NodeStatus.pending);
      expect(TreeOps.find(next, 'y')!.collapsed, isFalse);
    });

    test('reopen un-eliminates one node', () {
      var next = TreeOps.decide(tree, 'd', {'x'}, t1);
      next = TreeOps.reopen(next, 'y', t1);
      expect(statusOf(next, 'y'), NodeStatus.pending);
      expect(TreeOps.find(next, 'y')!.collapsed, isFalse);
    });

    test('only decision nodes can be decided', () {
      expect(() => TreeOps.decide(tree, 'a', {'a1'}, t1), throwsArgumentError);
      expect(() => TreeOps.decide(tree, 'd', {'a1'}, t1), throwsArgumentError);
    });

    test('a decision turned into a task drops picks and eliminations', () {
      var next = TreeOps.decide(tree, 'd', {'x'}, t1);
      next = TreeOps.changeType(next, 'd', NodeType.task, t1);
      final d = TreeOps.find(next, 'd')!;
      expect(d.type, NodeType.task);
      expect(d.chosenChildIds, isEmpty);
      expect(statusOf(next, 'y'), NodeStatus.pending);
    });
  });

  group('auto-done', () {
    test('a task ticks done when all its children are done', () {
      var next = TreeOps.setStatus(tree, 'a1', NodeStatus.done, t1);
      expect(statusOf(next, 'a'), NodeStatus.pending);
      next = TreeOps.setStatus(next, 'a2', NodeStatus.done, t1);
      expect(statusOf(next, 'a'), NodeStatus.done);
    });

    test('it carries up the tree, counting a decided decision as done', () {
      var next = TreeOps.setStatus(tree, 'a1', NodeStatus.done, t1);
      next = TreeOps.setStatus(next, 'a2', NodeStatus.done, t1);
      expect(statusOf(next, 'root'), NodeStatus.pending);
      next = TreeOps.decide(next, 'd', {'x'}, t1);
      expect(statusOf(next, 'root'), NodeStatus.done);
    });

    test('eliminated children do not block a parent', () {
      var t = TreeOps.changeType(tree, 'a', NodeType.task, t1);
      t = TreeOps.update(
        t,
        'a2',
        (n) => n.copyWith(status: NodeStatus.eliminated),
      );
      t = TreeOps.setStatus(t, 'a1', NodeStatus.done, t1);
      expect(statusOf(t, 'a'), NodeStatus.done);
    });

    test('a parent unticked by hand stays unticked', () {
      var next = TreeOps.setStatus(tree, 'a1', NodeStatus.done, t1);
      next = TreeOps.setStatus(next, 'a2', NodeStatus.done, t1);
      next = TreeOps.setStatus(next, 'a', NodeStatus.pending, t1);
      expect(statusOf(next, 'a'), NodeStatus.pending);
    });

    test('decision parents are never auto-done by their children', () {
      final next = TreeOps.setStatus(tree, 'x', NodeStatus.done, t1);
      expect(statusOf(next, 'd'), NodeStatus.pending);
    });
  });
}
