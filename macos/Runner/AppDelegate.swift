import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Board files opened from Finder before the Dart side was ready.
  private var queued: [[String: Any]] = []
  private var dartReady = false
  var filesChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Double-clicking a .mapex file in Finder, or dropping it on the Dock icon.
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      guard let file = AppDelegate.read(url) else { continue }
      if dartReady, let channel = filesChannel {
        channel.invokeMethod("opened", arguments: file)
      } else {
        queued.append(file)
      }
    }
  }

  /// The "mapex/files" channel, set up by the main window.
  func attachFilesChannel(_ channel: FlutterMethodChannel) {
    filesChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "takeQueued" {
        self.dartReady = true
        result(self.queued)
        self.queued.removeAll()
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static let maxBytes = 1024 * 1024 * 1024

  private static func read(_ url: URL) -> [String: Any]? {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      size <= maxBytes,
      let data = try? Data(contentsOf: url)
    else { return nil }
    return ["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: data)]
  }
}
