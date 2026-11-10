# Data format

Everything is stored in the app's private folder. Nothing leaves the device
unless you export it.

```text
mapex/
  settings.json
  boards/<board id>/
    board.json          the board itself
    audio/              voice notes, referenced from board.json by relative path
    history/            one full copy of board.json per change
  trash/<board id>/     boards moved to the trash, same layout, plus trashed.json
```

- On Android the `mapex` folder sits in the app's files directory, on macOS in
  the app's sandboxed Application Support folder.
- `board.json` is written to a temporary file first and then renamed, so a
  crash mid-save never leaves a half-written board.
- `history/` keeps the newest copies up to the **Versions kept per board**
  setting (default 200). Reverting to an old copy is saved as a new change, so
  a revert can itself be reverted.

## board.json

The full schema is in [schema/board.v1.schema.json](schema/board.v1.schema.json).
In short:

- A board has `schemaVersion`, `id`, `title`, `createdAt`, `updatedAt` and one
  `root` node.
- Every node has a `title`, a `type` (`task` or `decision`), a `status`
  (`pending`, `done`, `notYet`, `eliminated`), notes, optional date, time and
  reminder, voice notes, colour, tags and its ordered `children`.
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
