# Sortle

An offline mind-mapping and decision tracker. Build your thoughts as a tree,
branch by branch, then track which paths you took and what comes next.

- Fully offline. No accounts, no cloud, no sync, no analytics.
- Boards are plain JSON files you can export and import.
- Android, macOS, Windows and Linux from one Flutter codebase.

## Status

Boards (create, rename, duplicate, trash, restore, revert to an earlier
version), the tree canvas and outline view, task and decision nodes,
undo/redo, reminders with repeats, the "Which one did you do?" decision
prompt, the Today screen, voice notes, .sortle / JSON export and import, and
a configurable look work on all four platforms.

## Download

Get the latest build from [Releases](https://github.com/vin-kryl/Sortle/releases).
The apps are not signed with paid certificates, so the system asks once
before opening them.

- **Android**: download the `.apk` on your phone and open it. Allow
  installing from your browser or files app when asked. Android 10 or newer.
- **macOS**: open the `.dmg` and drag Sortle onto Applications, then open
  it. The first time, macOS says it could not verify Sortle: click **Done**,
  open **System Settings**, go to **Privacy & Security**, scroll down and
  click **Open Anyway** next to the Sortle message, then confirm. After that
  Sortle opens normally. macOS 13 or newer.
- **Windows**: unzip anywhere and run `sortle.exe`. If SmartScreen says
  "Windows protected your PC", click **More info**, then **Run anyway**.
- **Linux**: unpack the `.tar.gz` and run `./sortle` (or `./sortle board.sortle` to open a file). Voice notes need
  `pulseaudio-utils` and `ffmpeg` to record and GStreamer to play (on Ubuntu:
  `sudo apt install pulseaudio-utils ffmpeg gstreamer1.0-plugins-good gstreamer1.0-libav`).
  Reminders on Linux pop up only while Sortle is open.

On Android, macOS and Windows reminders fire even when Sortle is closed.

## Building

Uses the Flutter version in [.flutter-version](.flutter-version).

```sh
flutter pub get
flutter test
flutter run -d macos     # or windows, linux, or an Android device
```

Linux builds also need `ninja-build libgtk-3-dev libgstreamer1.0-dev
libgstreamer-plugins-base1.0-dev`.

To publish a release, run the **Release** workflow from the Actions tab and
type the version. It builds all four apps and attaches them to a GitHub
Release. The Android APK is signed with the key stored in the
`ANDROID_KEYSTORE` and `ANDROID_KEYSTORE_PASSWORD` repository secrets (key
alias `upload`).

- [Data format](docs/data-format.md)

## Licence

MIT. The Funnel Display font is under the SIL Open Font Licence, see
[assets/fonts/OFL.txt](assets/fonts/OFL.txt).
