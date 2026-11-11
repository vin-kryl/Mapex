import 'node.dart';

/// Pure edits on a node tree. Each returns a new root; the input is never
/// changed, so old roots can be kept for undo.
abstract final class TreeOps {
  static Node? find(Node root, String id) {
    if (root.id == id) return root;
    for (final child in root.children) {
      final hit = find(child, id);
      if (hit != null) return hit;
    }
    return null;
  }

  static Node? parentOf(Node root, String id) {
    for (final child in root.children) {
      if (child.id == id) return root;
      final hit = parentOf(child, id);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Ids from the root down to [id], inclusive. Empty when not found.
  static List<String> pathTo(Node root, String id) {
    if (root.id == id) return [root.id];
    for (final child in root.children) {
      final sub = pathTo(child, id);
      if (sub.isNotEmpty) return [root.id, ...sub];
    }
    return const [];
  }

  static bool contains(Node root, String id) => find(root, id) != null;

  /// Every node, depth first, with its depth.
  static Iterable<({Node node, int depth})> walk(
    Node root, [
    int depth = 0,
  ]) sync* {
    yield (node: root, depth: depth);
    for (final child in root.children) {
      yield* walk(child, depth + 1);
    }
  }

  /// Replaces the node [id] with `edit(node)`.
  static Node update(Node root, String id, Node Function(Node) edit) {
    if (root.id == id) return edit(root);
    var changed = false;
    final kids = <Node>[];
    for (final child in root.children) {
      final next = update(child, id, edit);
      if (!identical(next, child)) changed = true;
      kids.add(next);
    }
    return changed ? root.copyWith(children: kids) : root;
  }

  static Node addChild(Node root, String parentId, Node child, {int? index}) {
    return update(root, parentId, (p) {
      final kids = [...p.children];
      kids.insert((index ?? kids.length).clamp(0, kids.length), child);
      return p.copyWith(children: kids, collapsed: false);
    });
  }

  /// Removes [id] and everything below it. The root cannot be removed.
  static Node remove(Node root, String id) {
    if (root.id == id) throw ArgumentError('the root cannot be removed');
    final parent = parentOf(root, id);
    if (parent == null) return root;
    return update(
      root,
      parent.id,
      (p) => p.copyWith(
        children: [
          for (final c in p.children)
            if (c.id != id) c,
        ],
        chosenChildIds: [
          for (final c in p.chosenChildIds)
            if (c != id) c,
        ],
      ),
    );
  }

  /// Moves [id] one place up (`delta = -1`) or down (`delta = 1`) among its
  /// siblings.
  static Node reorder(Node root, String id, int delta) {
    final parent = parentOf(root, id);
    if (parent == null) return root;
    final kids = [...parent.children];
    final from = kids.indexWhere((c) => c.id == id);
    final to = (from + delta).clamp(0, kids.length - 1);
    if (from == to) return root;
    kids.insert(to, kids.removeAt(from));
    return update(root, parent.id, (p) => p.copyWith(children: kids));
  }

  /// Nodes that [id] may be moved under: not itself, not its own branch,
  /// not its current parent.
  static List<Node> moveTargets(Node root, String id) {
    final moving = find(root, id);
    final parent = parentOf(root, id);
    if (moving == null || parent == null) return const [];
    return [
      for (final e in walk(root))
        if (!contains(moving, e.node.id) && e.node.id != parent.id) e.node,
    ];
  }

  /// Moves [id] (with its branch) to the end of [newParentId]'s children.
  static Node move(Node root, String id, String newParentId) {
    final moving = find(root, id);
    if (moving == null) return root;
    if (contains(moving, newParentId)) {
      throw ArgumentError('a node cannot move inside its own branch');
    }
    return addChild(remove(root, id), newParentId, moving);
  }

  /// Switches a node between task and decision. Turning a decision into a
  /// task clears its picks and brings eliminated children back to pending,
  /// since a task has no alternatives to eliminate.
  static Node changeType(Node root, String id, NodeType type, DateTime now) {
    return update(root, id, (n) {
      if (n.type == type) return n;
      if (type == NodeType.task) {
        return n.copyWith(
          type: type,
          chosenChildIds: const [],
          updatedAt: now,
          children: [
            for (final c in n.children)
              c.status == NodeStatus.eliminated
                  ? c.copyWith(status: NodeStatus.pending, updatedAt: now)
                  : c,
          ],
        );
      }
      return n.copyWith(type: type, updatedAt: now);
    });
  }

  /// Records the outcome of a decision. One, several or no children can be
  /// picked.
  ///
  /// - Picked children become the taken paths (and are reopened if they had
  ///   been eliminated).
  /// - Children not picked are eliminated and collapsed. They are kept.
  /// - Picking none leaves every child pending and the decision unanswered.
  static Node decide(
    Node root,
    String decisionId,
    Set<String> picked,
    DateTime now, {
    bool autoDone = true,
  }) {
    var next = update(root, decisionId, (d) {
      if (d.type != NodeType.decision) {
        throw ArgumentError('only decision nodes can be decided');
      }
      final ids = {for (final c in d.children) c.id};
      final chosen = [
        for (final c in d.children)
          if (picked.contains(c.id)) c.id,
      ];
      if (picked.any((p) => !ids.contains(p))) {
        throw ArgumentError('picked ids must be children of the decision');
      }
      final kids = [
        for (final c in d.children)
          if (picked.isEmpty)
            c.status == NodeStatus.eliminated
                ? c.copyWith(status: NodeStatus.pending, updatedAt: now)
                : c
          else if (picked.contains(c.id))
            c.status == NodeStatus.eliminated
                ? c.copyWith(
                    status: NodeStatus.pending,
                    collapsed: false,
                    updatedAt: now,
                  )
                : c
          else
            c.copyWith(
              status: NodeStatus.eliminated,
              collapsed: true,
              updatedAt: now,
            ),
      ];
      return d.copyWith(
        chosenChildIds: chosen,
        status: picked.isEmpty ? NodeStatus.pending : NodeStatus.done,
        updatedAt: now,
        children: kids,
      );
    });
    if (autoDone && picked.isNotEmpty) {
      next = _autoDoneAbove(next, decisionId, now);
    }
    return next;
  }

  /// Brings an eliminated node back into play.
  static Node reopen(Node root, String id, DateTime now) {
    return update(
      root,
      id,
      (n) => n.status == NodeStatus.eliminated
          ? n.copyWith(
              status: NodeStatus.pending,
              collapsed: false,
              updatedAt: now,
            )
          : n,
    );
  }

  /// Sets a node's status. Marking a node done can tick its parent tasks
  /// done too, see [_autoDoneAbove].
  static Node setStatus(
    Node root,
    String id,
    NodeStatus status,
    DateTime now, {
    bool autoDone = true,
  }) {
    var next = update(
      root,
      id,
      (n) => n.copyWith(status: status, updatedAt: now),
    );
    if (autoDone && status == NodeStatus.done) {
      next = _autoDoneAbove(next, id, now);
    }
    return next;
  }

  /// Children that count towards a parent being done. Eliminated
  /// alternatives do not count.
  static bool countsForParent(Node child) =>
      child.status != NodeStatus.eliminated;

  /// Walks up from [id]: each task parent whose counted children are all
  /// done is marked done. This only runs when something becomes done, so a
  /// parent that was unticked by hand stays unticked until a child changes.
  static Node _autoDoneAbove(Node root, String id, DateTime now) {
    var current = root;
    var childId = id;
    while (true) {
      final parent = parentOf(current, childId);
      if (parent == null || parent.type != NodeType.task) return current;
      final counted = parent.children.where(countsForParent).toList();
      final allDone =
          counted.isNotEmpty &&
          counted.every((c) => c.status == NodeStatus.done);
      if (!allDone || parent.status == NodeStatus.done) return current;
      current = update(
        current,
        parent.id,
        (p) => p.copyWith(status: NodeStatus.done, updatedAt: now),
      );
      childId = parent.id;
    }
  }

  static Node setCollapsed(Node root, String id, bool collapsed) =>
      update(root, id, (n) => n.copyWith(collapsed: collapsed));

  /// Puts each listed node at its new spot on the canvas. Only positions
  /// change; who is connected to whom stays the same.
  static Node place(Node root, Map<String, NodePosition> positions) {
    if (positions.isEmpty) return root;
    Node walk(Node n) {
      final kids = [for (final c in n.children) walk(c)];
      final spot = positions[n.id];
      final changed = spot != null && spot != n.position;
      final kidsChanged = !_same(kids, n.children);
      if (!changed && !kidsChanged) return n;
      return n.copyWith(
        position: changed ? () => spot : null,
        children: kidsChanged ? kids : null,
      );
    }

    return walk(root);
  }

  /// Forgets every position, so the canvas lines the whole tree up again.
  static Node clearPositions(Node root) {
    final kids = [for (final c in root.children) clearPositions(c)];
    if (root.position == null && _same(kids, root.children)) return root;
    return root.copyWith(position: () => null, children: kids);
  }

  static bool _same(List<Node> a, List<Node> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}
