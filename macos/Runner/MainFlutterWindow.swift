import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let windowFrame = self.frame
    let controller = MacOSWindowUtilsViewController()
    self.contentViewController = controller
    self.setFrame(windowFrame, display: true)

    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    let flutterViewController = controller.flutterViewController
    RegisterGeneratedPlugins(registry: flutterViewController)

    let files = FlutterMethodChannel(
      name: "sortle/files",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    (NSApp.delegate as? AppDelegate)?.attachFilesChannel(files)

    super.awakeFromNib()
  }
}
