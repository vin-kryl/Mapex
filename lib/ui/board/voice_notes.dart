import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/tree_ops.dart';
import '../../model/voice_note.dart';
import '../../state/board_editor.dart';
import '../../state/providers.dart';
import '../../voice/voice_recorder.dart';
import '../dialogs.dart';
import '../theme.dart';

/// The voice notes part of a node's edit sheet: record, play, re-record and
/// delete. Changes apply straight away, each as its own undo step.
class VoiceNotesSection extends ConsumerStatefulWidget {
  const VoiceNotesSection({
    super.key,
    required this.boardId,
    required this.nodeId,
  });

  final String boardId;
  final String nodeId;

  @override
  ConsumerState<VoiceNotesSection> createState() => _VoiceNotesSectionState();
}

class _VoiceNotesSectionState extends ConsumerState<VoiceNotesSection> {
  AudioPlayer? _player;
  StreamSubscription<void>? _done;
  String? _playingId;
  bool _busy = false;

  BoardEditor get _editor =>
      ref.read(boardEditorProvider(widget.boardId).notifier);

  @override
  void dispose() {
    _done?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(VoiceNote note) async {
    final player = _player ??= AudioPlayer();
    _done ??= player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    if (_playingId == note.id) {
      await player.stop();
      setState(() => _playingId = null);
      return;
    }
    final file = ref
        .read(boardRepositoryProvider)
        .audioFile(widget.boardId, note.path);
    if (!await file.exists()) {
      if (mounted) showMessage(context, 'This recording is missing');
      return;
    }
    try {
      await player.stop();
      await player.play(DeviceFileSource(file.path));
      if (mounted) setState(() => _playingId = note.id);
    } on Object catch (e) {
      if (mounted) showMessage(context, 'Could not play it: $e');
    }
  }

  Future<void> _record({String? replaceId}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _player?.stop();
    setState(() => _playingId = null);
    final recorder = ref.read(voiceRecorderProvider)();
    try {
      if (!await recorder.requestPermission()) {
        if (mounted) {
          showMessage(
            context,
            'Microphone access is off. Turn it on for Mapex in your '
            'system settings.',
          );
        }
        return;
      }
      final target = _editor.newVoicePath(await recorder.extension());
      final file = ref
          .read(boardRepositoryProvider)
          .audioFile(widget.boardId, target.path);
      await file.parent.create(recursive: true);
      await recorder.start(file.path);
      final watch = Stopwatch()..start();
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      final keep = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _RecordingDialog(),
      );
      watch.stop();
      if (keep != true) {
        await recorder.cancel();
        return;
      }
      await recorder.stop();
      final note = VoiceNote(
        id: target.id,
        path: target.path,
        createdAt: DateTime.now().toUtc(),
        durationMs: watch.elapsedMilliseconds,
      );
      if (replaceId == null) {
        _editor.addVoiceNote(widget.nodeId, note);
      } else {
        _editor.replaceVoiceNote(widget.nodeId, replaceId, note);
      }
    } on Object catch (e) {
      if (mounted) showMessage(context, 'Could not record: $e');
    } finally {
      await recorder.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(VoiceNote note) async {
    final ok = await confirm(
      context,
      heading: 'Delete voice note?',
      message: 'You can bring it back with undo.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    if (_playingId == note.id) {
      await _player?.stop();
      setState(() => _playingId = null);
    }
    _editor.removeVoiceNote(widget.nodeId, note.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boardEditorProvider(widget.boardId)).value;
    final node = state == null
        ? null
        : TreeOps.find(state.board.root, widget.nodeId);
    final notes = node?.voiceNotes ?? const <VoiceNote>[];
    final loc = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, note) in notes.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: IconButton(
              tooltip: _playingId == note.id ? 'Stop' : 'Play',
              icon: Icon(
                _playingId == note.id
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
              ),
              onPressed: () => _togglePlay(note),
            ),
            title: Text('Voice note ${i + 1}'),
            subtitle: Text(
              [
                if (note.durationMs != null) formatClip(note.durationMs!),
                loc.formatShortDate(note.createdAt.toLocal()),
              ].join(' · '),
            ),
            trailing: PopupMenuButton<bool>(
              tooltip: 'Voice note options',
              onSelected: (rerecord) =>
                  rerecord ? _record(replaceId: note.id) : _delete(note),
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Re-record')),
                PopupMenuItem(value: false, child: Text('Delete')),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: _busy || node == null ? null : _record,
          icon: const Icon(Icons.mic_none),
          label: const Text('Record voice note'),
        ),
      ],
    );
  }
}

/// 0:07, 1:42, 12:05.
String formatClip(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _RecordingDialog extends StatefulWidget {
  const _RecordingDialog();

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  final _watch = Stopwatch()..start();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Recording'),
      content: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: scheme.error),
          const SizedBox(width: Metrics.gap),
          Text(
            formatClip(_watch.elapsedMilliseconds),
            style: const TextStyle(
              fontSize: 28,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
