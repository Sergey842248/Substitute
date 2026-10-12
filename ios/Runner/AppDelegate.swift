import Flutter
import UIKit

/// Der Einstiegspunkt – und der Ort, an dem die native Schale entsteht.
///
/// ## Was sich hier geändert hat
///
/// Vorher war das Fenster von `Main.storyboard` vorgegeben, und darin stand ein
/// `FlutterViewController`: Die Flutter-App füllte den Bildschirm, Kopfzeile und
/// Tab-Leiste selbst.
///
/// Jetzt steht hier ein `RootTabBarController` – eine echte, native Leiste mit
/// grossen Titeln, SF-Symbolen und dem Material, das iOS dafür vorsieht.
/// Flutter liefert nur noch den **Inhalt**.
///
/// ## Das Fenster wird hier erzeugt, nicht mehr von der Geschichte
///
/// Eine Geschichte, die das Fenster liefert, und ein Bildschirm, der es
/// ersetzt, können sich nicht beide durchsetzen – und welcher gewinnt, hängt
/// davon ab, wer zuletzt geladen wurde. Deshalb ist `UIMainStoryboardFile`
/// aus `Info.plist` entfernt: Es gibt jetzt nur noch eine Stelle, an der das
/// Fenster entsteht, und das ist diese.
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var tabBarController: RootTabBarController?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Vor der Leiste: die Brücke. Sie muss hören können, wenn Flutter etwas
        // ändert – und die Leiste muss dann schon stehen, damit sie es
        // entgegennehmen kann.
        AppearanceBridge.install()

        let controller = RootTabBarController()
        tabBarController = controller
        NativeShellBridge.setHost(controller)

        // Das Fenster wird von hier erzeugt und **nicht** über `makeKeyAndVisible`
        // von iOS gesetzt – es ist ein eigenes, damit seine Wurzel die Leiste
        // ist und nicht eine Geschichte.
        let fenster = UIWindow(frame: UIScreen.main.bounds)
        fenster.rootViewController = controller
        fenster.overrideUserInterfaceStyle = Appearance.current == .dark ? .dark : .light
        fenster.backgroundColor = Appearance.background
        fenster.makeKeyAndVisible()
        self.window = fenster

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}