import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../theme.dart';

/// Shared look for a node in the canvas and the outline.
abstract final class NodeStyle {
  /// How faded eliminated nodes are.
  static const eliminatedOpacity = 0.45;

  static Color? parseColor(String? hex) {
    if (hex == null) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  static String toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
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

  static Color statusColor(Node n, ColorScheme scheme) => switch (n.status) {
    NodeStatus.done => Palette.done,
    NodeStatus.notYet => Palette.notYet,
    NodeStatus.eliminated => scheme.onSurfaceVariant,
    NodeStatus.pending =>
      n.type == NodeType.decision ? Palette.lavender : scheme.onSurfaceVariant,
  };
}
