import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets reminders show while Sortle is in front.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    BoardFiles.shared.attach(
      FlutterMethodChannel(
        name: "sortle/files",
        binaryMessenger: engineBridge.applicationRegistrar.messenger()))
  }
}

/// Board files opened from Files, AirDrop or the share sheet, handed to the
/// Dart side on the "sortle/files" channel.
final class BoardFiles {
  static let shared = BoardFiles()

  private var channel: FlutterMethodChannel?
  private var queued: [[String: Any]] = []
  private var dartReady = false
  private static let maxBytes = 1024 * 1024 * 1024

  func attach(_ channel: FlutterMethodChannel) {
    self.channel = channel
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

  func open(_ contexts: Set<UIOpenURLContext>) {
    for context in contexts {
      guard let file = BoardFiles.read(context.url) else { continue }
      if dartReady, let channel = channel {
        channel.invokeMethod("opened", arguments: file)
      } else {
        queued.append(file)
      }
    }
  }

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
