# Mapex

An offline mind-mapping and decision tracker. Build your thoughts as a tree,
branch by branch, then track which paths you took and what comes next.

- Fully offline. No accounts, no cloud, no sync, no analytics.
- Boards are plain JSON files you can export and import.
- Android and macOS from one Flutter codebase.

## Status

Early development. Boards (create, rename, duplicate, trash, restore, revert
to an earlier version), the tree canvas and outline view, task and decision
nodes, and undo/redo work. Reminders and the Today view are next.

## Building

Uses the Flutter version in [.flutter-version](.flutter-version).

```sh
flutter pub get
flutter test
flutter run -d macos     # or an Android device
```

- [Data format](docs/data-format.md)
- [Android signing key](docs/signing.md)

## Licence

MIT. The Funnel Display font is under the SIL Open Font Licence, see
[assets/fonts/OFL.txt](assets/fonts/OFL.txt).
