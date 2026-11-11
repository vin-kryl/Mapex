import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/json_read.dart';
import '../state/providers.dart';
import '../storage/board_package.dart';
import '../storage/board_repository.dart';
import 'board/board_screen.dart';
import 'dialogs.dart';
import 'theme.dart';

/// Asks which format, then saves the board where the user picks.
Future<void> exportBoard(
  BuildContext context,
  WidgetRef ref, {
  required String boardId,
}) async {
  final withAudio = ref.read(settingsProvider).exportWithAudio;
  final format = await _pickFormat(context, withAudio: withAudio);
  if (format == null || !context.mounted) return;
  final repo = ref.read(boardRepositoryProvider);
  try {
    final board = await repo.loadBoard(boardId);
    final bytes = await BoardPackager.export(
      board,
      format,
      readAudio: (path) => repo.readAudio(boardId, path),
    );
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export board',
      fileName: '${fileSafe(board.title)}.${format.extension}',
      bytes: bytes,
      mimeType: format == ExportFormat.sortle
          ? 'application/zip'
          : 'application/json',
    );
    if (saved != null && context.mounted) {
      showMessage(context, 'Exported "${board.title}"');
    }
  } on Object catch (e) {
    if (context.mounted) showMessage(context, 'Could not export: $e');
  }
}

/// Picks a .sortle or .json file, checks it, and adds it to the board list.
Future<void> importBoard(BuildContext context, WidgetRef ref) async {
  final Uint8List bytes;
  try {
    final file = await FilePicker.pickFile(dialogTitle: 'Import a board');
    if (file == null) return;
    bytes = await file.readAsBytes();
  } on Object catch (e) {
    if (context.mounted) showMessage(context, 'Could not open the file: $e');
    return;
  }
  if (context.mounted) await importBytes(context, ref, bytes);
}

/// Checks a board file's contents and adds it to the board list, asking
/// first if a board with the same id is already there.
Future<void> importBytes(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  final repo = ref.read(boardRepositoryProvider);
  final BoardPackage package;
  try {
    package = BoardPackager.read(bytes);
  } on SchemaException catch (e) {
    if (context.mounted) {
      await _explain(context, 'This file could not be imported: ${e.message}.');
    }
    return;
  }
  if (!context.mounted) return;
  var conflict = ImportConflict.keepBoth;
  if (await repo.hasBoard(package.board.id)) {
    if (!context.mounted) return;
    final choice = await _askConflict(context, package.board.title);
    if (choice == null) return;
    conflict = choice;
  }
  final board = await repo.importBoard(package, conflict: conflict);
  ref.invalidate(boardListProvider);
  ref.invalidate(trashListProvider);
  ref.invalidate(boardProvider(board.id));
  ref.invalidate(historyProvider(board.id));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Imported "${board.title}"'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BoardScreen(boardId: board.id),
            ),
          ),
        ),
      ),
    );
}

/// A file name that every platform accepts.
String fileSafe(String title) {
  final t = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final short = t.length > 80 ? t.substring(0, 80).trim() : t;
  return short.isEmpty || short.startsWith('.') ? 'Board' : short;
}

Future<ExportFormat?> _pickFormat(
  BuildContext context, {
  required bool withAudio,
}) {
  Widget tile(BuildContext c, ExportFormat f) {
    final sortle = f == ExportFormat.sortle;
    return ListTile(
      leading: Icon(sortle ? Icons.folder_zip_outlined : Icons.data_object),
      title: Text(sortle ? 'Sortle file (.sortle)' : 'Plain JSON (.json)'),
      subtitle: Text(
        sortle
            ? 'The board with its voice notes'
            : 'The board without voice notes',
      ),
      onTap: () => Navigator.of(c).pop(f),
    );
  }

  final order = withAudio
      ? [ExportFormat.sortle, ExportFormat.json]
      : [ExportFormat.json, ExportFormat.sortle];
  return showModalBottomSheet<ExportFormat>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in order) tile(c, f),
        const SizedBox(height: Metrics.gap),
      ],
    ),
  );
}

Future<ImportConflict?> _askConflict(BuildContext context, String title) {
  return showDialog<ImportConflict>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('This board is already here'),
      content: Text(
        '"$title" is already in your boards. Replace it, or keep both? '
        'If you replace it, the one here moves to the trash.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(ImportConflict.replace),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(ImportConflict.keepBoth),
          child: const Text('Keep both'),
        ),
      ],
    ),
  );
}

Future<void> _explain(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
