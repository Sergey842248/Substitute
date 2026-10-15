import Flutter
import UIKit

/// Der Einstiegspunkt für Prozess-Ereignisse.
///
/// Die sichtbare Oberfläche und das Fenster gehören seit der UIScene-Migration
/// in `SceneDelegate`. Das ist wichtig, weil ein Prozess mehrere Szenen haben
/// kann und iOS UI-bezogene `AppDelegate`-Callbacks dann nicht mehr aufruft.
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Flutter initialisiert einen impliziten Engine erst nach dem Start des
    /// Prozesses. Die hier verwendeten Engine-Gruppen registrieren ihre Plugins
    /// weiterhin direkt beim jeweiligen Engine; dieser Callback ist für einen
    /// möglichen impliziten Engine notwendig.
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
