import Flutter
import UIKit

/// Eigentümer der sichtbaren Oberfläche einer App-Szene.
///
/// Die App verwendet eine native Tab-Schale und erzeugt ihre Flutter-Engines
/// selbst. Deshalb wird das Fenster hier programmgesteuert aufgebaut und jeder
/// dieser Engines beim Erzeugen beim Flutter-Szenen-Lifecycle angemeldet.
final class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        AppearanceBridge.install()

        let controller = RootTabBarController { [weak self] engine in
            self?.registerSceneLifeCycle(with: engine)
        }
        NativeShellBridge.setHost(controller)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = Appearance.current == .dark ? .dark : .light
        window.backgroundColor = Appearance.background
        self.window = window
        window.makeKeyAndVisible()

        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
