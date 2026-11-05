import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }

    super.scene(scene, willConnectTo: session, options: connectionOptions)
    let controller = appDelegate.flutterEngine.viewController
      ?? FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
    let sceneWindow = window ?? UIWindow(windowScene: windowScene)
    sceneWindow.rootViewController = controller
    window = sceneWindow
    appDelegate.window = sceneWindow
    sceneWindow.makeKeyAndVisible()

    forwardURLs(connectionOptions.urlContexts, to: appDelegate, notifyDart: false)
    for activity in connectionOptions.userActivities {
      self.scene(scene, continue: activity)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      super.scene(scene, openURLContexts: URLContexts)
      return
    }
    forwardURLs(URLContexts, to: appDelegate, notifyDart: true)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    _ = appDelegate.application(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
       appDelegate.window === window {
      appDelegate.window = nil
    }
    window = nil
  }

  private func forwardURLs(_ contexts: Set<UIOpenURLContext>, to appDelegate: AppDelegate, notifyDart: Bool) {
    for context in contexts {
      if !notifyDart && appDelegate.handleBitcoinUri(context.url, notifyDart: false) {
        continue
      }
      var options: [UIApplication.OpenURLOptionsKey: Any] = [.openInPlace: context.options.openInPlace]
      if let source = context.options.sourceApplication { options[.sourceApplication] = source }
      if let annotation = context.options.annotation { options[.annotation] = annotation }
      if let attribution = context.options.eventAttribution { options[.eventAttribution] = attribution }
      _ = appDelegate.application(UIApplication.shared, open: context.url, options: options)
    }
  }
}
