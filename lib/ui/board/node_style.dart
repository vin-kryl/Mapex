import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../reminders/timing.dart';
import '../format.dart';
import '../theme.dart';

/// Shared look for a node in the canvas and the outline.
abstract final class NodeStyle {
  /// How faded eliminated nodes are.
  static const eliminatedOpacity = 0.42;

  /// "2 of 5 done" over every step below the top of [root].
  static String progress(Node root) {
    final all = [
      for (final e in TreeOps.walk(root))
        if (e.depth > 0 && e.node.status != NodeStatus.eliminated) e.node,
    ];
    if (all.isEmpty) return 'No steps yet';
    final done = all.where((n) => n.status == NodeStatus.done).length;
    return '$done of ${all.length} done';
  }

  /// The one quiet line under a node's title, or null for none.
  static ({String text, DetailTone tone})? detail(
    Node n,
    DateTime now, {
    bool taken = false,
  }) {
    if (n.status == NodeStatus.eliminated) {
      return (text: 'Not picked', tone: DetailTone.plain);
    }
    final day = Timing.day(n);
    if (day != null && Timing.isOpen(n)) {
      final due = Timing.dueAt(n);
      final late = (due ?? day.add(const Duration(days: 1))).isBefore(now);
      final when = shortDay(day, now);
      return (
        text: n.time == null ? when : '$when ${n.time}',
        tone: late ? DetailTone.late : DetailTone.plain,
      );
    }
    if (n.type == NodeType.decision) {
      final picked = n.chosenChildIds.length;
      return (
        text: picked == 0
            ? 'Decision · ${n.children.length} options'
            : 'Decision · $picked picked',
        tone: DetailTone.plain,
      );
    }
    if (taken) return (text: 'Picked', tone: DetailTone.taken);
    if (n.status == NodeStatus.notYet) {
      return (text: 'Not yet', tone: DetailTone.plain);
    }
    return null;
  }

  static Color? parseColor(String? hex) {
    if (hex == null) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  static IconData statusIcon(Node n) => switch (n.status) {
    NodeStatus.done =>
      n.type == NodeType.decision ? Icons.call_split : Icons.check_circle,
    NodeStatus.notYet => Icons.schedule,
    NodeStatus.eliminated => Icons.block,
    NodeStatus.pending =>
      n.type == NodeType.decision
          ? Icons.call_split
          : Icons.radio_button_unchecked,
  };

  static String statusLabel(NodeStatus s) => switch (s) {
    NodeStatus.pending => 'Pending',
    NodeStatus.done => 'Done',
    NodeStatus.notYet => 'Not yet',
    NodeStatus.eliminated => 'Eliminated',
  };

  static String typeLabel(NodeType t) =>
      t == NodeType.task ? 'Task' : 'Decision';

  static Color statusColor(Node n, BuildContext context) {
    final look = Look.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return switch (n.status) {
      NodeStatus.done => look.done,
      NodeStatus.notYet => look.notYet,
      NodeStatus.eliminated => muted,
      NodeStatus.pending => n.type == NodeType.decision ? look.decision : muted,
    };
  }
}

enum DetailTone { plain, late, taken }
