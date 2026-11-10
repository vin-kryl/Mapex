import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/node.dart';
import '../settings/app_settings.dart';
import '../state/providers.dart';
import 'theme.dart';

/// Settings that already do something. The rest of the brief's settings
/// list joins as the features they control are built.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Metrics.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(Metrics.gutter),
            children: [
              _Section(
                title: 'Theme',
                child: SegmentedButton<ThemeChoice>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeChoice.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeChoice.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment(value: ThemeChoice.dark, label: Text('Dark')),
                  ],
                  selected: {s.theme},
                  onSelectionChanged: (v) =>
                      notifier.update(s.copyWith(theme: v.first)),
                ),
              ),
              _Section(
                title: 'Text size',
                trailing: '${(s.fontScale * 100).round()}%',
                child: Slider(
                  min: AppSettings.fontScaleRange.min,
                  max: AppSettings.fontScaleRange.max,
                  divisions: 8,
                  value: s.fontScale,
                  onChanged: (v) => notifier.update(s.copyWith(fontScale: v)),
                ),
              ),
              _Section(
                title: 'New boards start as',
                child: SegmentedButton<NodeType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: NodeType.task, label: Text('Task')),
                    ButtonSegment(
                      value: NodeType.decision,
                      label: Text('Decision'),
                    ),
                  ],
                  selected: {s.defaultNodeType},
                  onSelectionChanged: (v) =>
                      notifier.update(s.copyWith(defaultNodeType: v.first)),
                ),
              ),
              _Section(
                title: 'Versions kept per board',
                subtitle: 'Older versions are removed past this number.',
                child: _NumberField(
                  value: s.historyCap,
                  min: AppSettings.historyCapRange.min,
                  max: AppSettings.historyCapRange.max,
                  onChanged: (v) => notifier.update(s.copyWith(historyCap: v)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gutter * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: TextStyle(color: muted)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: muted)),
          ],
          const SizedBox(height: Metrics.gap),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final v = int.tryParse(text);
    if (v == null || v < widget.min || v > widget.max) {
      setState(() => _error = 'Enter ${widget.min} to ${widget.max}');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(errorText: _error),
        onChanged: _onChanged,
      ),
    );
  }
}
