import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Cold-launch URL: the scene is being created in response to a tap on a
  // voidtunnel:// link. Forward the URL flagged as the initial one so the
  // Flutter side can pick it up via consumeInitial() as well as the event
  // stream.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      forwardIfVoidTunnel(url: context.url, isInitial: true)
    }
  }

  // Warm deep link: app is already running, OS hands us a new URL.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      forwardIfVoidTunnel(url: context.url, isInitial: false)
    }
  }

  private func forwardIfVoidTunnel(url: URL, isInitial: Bool) {
    guard let scheme = url.scheme, scheme.lowercased() == "voidtunnel" else {
      return
    }
    DeepLinkBridge.shared.emit(url: url.absoluteString, isInitial: isInitial)
  }
}
