import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A board file tapped while Sortle was closed.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    BoardFiles.shared.open(connectionOptions.urlContexts)
  }

  /// A board file tapped while Sortle was running.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    BoardFiles.shared.open(URLContexts)
  }
}
