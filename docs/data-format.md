# Data format

Everything is stored in the app's private folder. Nothing leaves the device
unless you export it.

```text
sortle/
  settings.json
  boards/<board id>/
    board.json          the board itself
    audio/              voice notes, referenced from board.json by relative path
    history/            one full copy of board.json per change
  trash/<board id>/     boards moved to the trash, same layout, plus trashed.json
```

- The `sortle` folder sits in the app's private folder: the app's files
  directory on Android, the sandboxed Application Support folder on iOS and
  macOS, `%APPDATA%\Vineet Khankriyal\Sortle` on Windows and
  `~/.local/share/com.apeaxis.sortle` on Linux.
- `board.json` is written to a temporary file first and then renamed, so a
  crash mid-save never leaves a half-written board.
- `history/` keeps the newest copies up to the **Versions kept per board**
  setting (default 200). Reverting to an old copy is saved as a new change, so
  a revert can itself be reverted.

## board.json

The full schema is in [schema/board.v2.schema.json](schema/board.v2.schema.json).
In short:

- A board has `schemaVersion`, `id`, `title`, `createdAt`, `updatedAt` and one
  `root` node.
- Every node has a `title`, a `type` (`task` or `decision`), a `status`
  (`pending`, `done`, `notYet`, `eliminated`), notes, optional date, time and
  reminder, voice notes, colour, tags and its ordered `children`.
- `position` is where the node sits on the canvas (`{"x": 120, "y": 40}`,
  in logical pixels), or `null` if it has not been placed yet, in which case
  the app arranges it next to its parent.
- On a decision node, `chosenChildIds` lists the children that were picked.
  One, several or none can be picked. Children that were not picked get the
  `eliminated` status. They are kept, never deleted.
- Times are stored in UTC, ISO 8601. A node's `date` (`YYYY-MM-DD`) and `time`
  (`HH:mm`) are the user's local calendar values.

## Versions

`schemaVersion` is bumped whenever the format changes. Opening an older file
runs each migration in `lib/model/schema.dart` in turn until the file is at the
current version. A file from a newer app is refused with a message asking to
update.

- Format 2 added `position` to every node. Format 1 boards open with every
  node unplaced and get arranged automatically.

## Export files

- `.sortle` is a zip with `board.json` at the top and the voice notes'
  audio in `audio/`, at the same relative paths `board.json` uses.
- `.json` is `board.json` on its own. Voice notes are left out, since their
  audio is not in the file.

On import the file is checked and migrated to the current schema version.
Anything in the zip other than `board.json` and the audio files it points
at is ignored. If a board with the same id is already there, the app asks
whether to replace it (the old one goes to the trash) or keep both (the
import gets a new id).
