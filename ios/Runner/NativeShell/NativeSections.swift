import Flutter
import UIKit

/// Die gemeinsame Grundlage der beiden nativen Reiter „Plan" und „Sync & Teilen".
///
/// ## Was sich hier ändert – und was ausdrücklich nicht
///
/// Beide Reiter waren bis eben Flutter-Ansichten: eine eigene Maschine, ein
/// eigener Bildschirm, und die Seite stand in Dart. Jetzt steht an ihrer Stelle
/// eine Bildschirmreihe aus `UIKit`.
///
/// Der **Inhalt** ist nicht umgezogen. Das Lesen des VPlan-XML, das Rechnen der
/// nächsten Stunde, der Abgleich mit anderen Geräten, die Kryptografie – das steht
/// unverändert in Dart. Was umgezogen ist, ist die Darstellung: Liste, grosser
/// Titel, Wischen, Symbole.
///
/// ## Warum gerade diese beiden
///
/// Es geht hier **nicht** um den Plan einer Klasse – der ist weiterhin Flutter,
/// weil dort das Wochenraster steht ([PlanDetailRoute]). Es geht um die
/// **Übersicht**: eine Liste von Klassen und Personen.
///
/// Die ist etwas anderes als ein Raster. Sie hat Zeilen, sie hat Zustände, sie
/// lässt sich antippen – und für genau das ist eine `UITableView` gemacht, seit
/// dreissig Jahren. Der Plan einer Woche ist etwas anderes, und dort wäre eine
/// Liste ein Rückschritt.
///
/// ## Der Preis, und wie er bezahlt wird
///
/// Die Übersicht ist jetzt **Daten, die aus Dart kommen** (`ScreenBridge`). Damit
/// braucht die native Seite eine Maschine, von der sie ihre Werte bekommt – auch
/// dann, wenn gerade nichts von ihr zu sehen ist. Dafür steht [NativeScreenEngine].
///
/// Es steht dafür **eine** weniger im Speicher: Vorher gab es je Reiter eine
/// sichtbare Flutter-Maschine, jetzt gibt es eine rechnende ohne Bildschirm und
/// je aufgetappten Plan eine eigene. Das ist weniger, nicht mehr.
///
/// ## Die eine Sache, die hier geregelt wird: die Kopfzeile
///
/// Beide Reiter fangen mit einem Bildschirm aus `UIKit` an, der seine **eigene**
/// Kopfzeile hat – den grossen Titel, den das System beim Scrollen ein- und
/// ausblendet. Tippt man eine Zeile an, kommt ein Bildschirm aus **Flutter**, der
/// wiederum seine eigene Kopfzeile mitbringt (`ListPage`).
///
/// Ohne diese Regel stünden **zwei** übereinander: die der Reihe oben, und
/// darunter – mit einem Abstand von mehreren Punkten, weil Flutter seinen
/// Bildschirm für eine Leiste oben einrechnet, die es gar nicht gibt. Das ist
/// genau der Fehler, den die Seite `SyncShareHub` einst mitbrachte; siehe die
/// Beschreibung dort.
///
/// Deshalb gilt hier eine Regel, und sie ist die denkbar einfachste:
///
/// * Steht eine **Flutter**-Ansicht oben, ist die Leiste weg.
/// * Steht ein **eigener** Bildschirm oben, ist sie da.
///
/// ## Warum `didShow` und nicht `pushViewController`
///
/// Weil man auch ohne Code zurückgehen kann: mit dem Finger von links. Dieser
/// Wisch ruft `popViewController` **nicht** auf – er arbeitet über einen
/// Delegate. Eine Regel, die nur `push` und `pop` kennt, würde beim Wischen
/// also eine Leiste stehen lassen, die nicht mehr dazugehört.
///
/// `didShow` wird bei **jedem** Ergebnis aufgerufen, auf welchem Weg man
/// ankommt. Es ist damit die einzige Stelle, an der nicht zu überlegen ist,
/// welcher Weg gerade passiert.
class NativeSectionHost: UINavigationController, UINavigationControllerDelegate {

    init(root: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        // Grosse Titel: Sie sind der Grund, warum die Leiste in iOS wie in iOS
        // aussieht – siehe `MoreSectionController`.
        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = Appearance.accent
        setViewControllers([root], animated: false)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    /// Steht gerade eine Flutter-Ansicht oben?
    private var zeigtFlutter: Bool { viewControllers.last is FlutterViewController }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Ohne Prüfung würde die Leiste bei **jedem** Schritt neu gesetzt –
        // auch dort, wo sich nichts geändert hat. Das sieht man nicht, aber es
        // ist eine Layout-Rechnung ohne Not, und die kostet.
        guard navigationBar.isHidden == zeigtFlutter else { return }
        setNavigationBarHidden(zeigtFlutter, animated: animated)
    }
}

/// Der Reiter „Plan" – siehe [NativeSectionHost].
final class PlanSectionHost: NativeSectionHost {
    init() { super.init(root: PlanOverviewScreen()) }
}

/// Der Reiter „Sync & Teilen" – siehe [NativeSectionHost].
final class SyncSectionHost: NativeSectionHost {
    init() { super.init(root: SyncHubScreen()) }
}

// MARK: - Die Maschine, die rechnet, während niemand hinsieht

/// Die Flutter-Maschine, die im Hintergrund arbeitet – ohne sichtbaren Bildschirm.
///
/// ## Wozu das hier ist
///
/// `NativeShell.runsBackgroundWork` sagt: Genau **eine** Ansicht holt beim Start
/// die Pläne und hängt sich an den Sync. Vorher war das die Plan-Ansicht, weil
/// sie als einzige sichtbar war und nebenbei rechnen konnte.
///
/// Jetzt ist der Plan-Abschnitt nativ – es gibt dort keine Flutter-Ansicht
/// mehr, die rechnen könnte. Ohne diese Maschine würde also beim Start gar
/// nichts passieren: keine Pläne, kein Sync, und die Vorschauen in der Liste
/// stünden auf dem Stand von gestern, ohne dass irgendwo ein Fehler stünde.
///
/// Genau das ist der Fall, der am schwersten zu finden ist, weil **alles
/// funktioniert**: Die Klassen stehen da, die Pläne sind da – nur eben alt.
///
/// ## Warum die Ansicht nicht zu sehen ist
///
/// Weil sie nichts anzuzeigen hat. Sie baut ihren Bildschirm, lädt die Klassen,
/// schickt sie über `publish` (dort drüben) an [PlanOverviewScreen] – und was sie
/// selbst malt, sieht niemand. Das ist Absicht: Eine zweite, unsichtbare Liste
/// mit den Klassen wäre genau die doppelte Wahrheit, die diese ganze Aufteilung
/// vermeiden soll.
///
/// ## Warum trotzdem [FlutterEngine.run()] und nicht nur `init`
///
/// Weil eine Maschine erst **läuft**, wenn jemand das sagt. `FlutterViewController`
/// sagt es beim Anlegen – und diese Maschine hat keinen, weil niemand ihren
/// Bildschirm zu sehen bekommt. Ohne den Aufruf hier stünde die Maschine da und
/// wartete, und das Warten fiele niemandem auf: Sie ist unsichtbar, und es
/// passiert nichts.
///
/// ## Warum sie für die ganze Zeit lebt
///
/// Weil der Auftrag einmal läuft und danach von selbst weitergeht – der Sync
/// richtet sich selbst aus und holt in Abständen nach. Eine Maschine, die nach
/// dem ersten Frame wieder verschwände, würde ihn mitnehmen.
final class NativeScreenEngine {

    static let shared = NativeScreenEngine()

    private let engine: FlutterEngine
    private let group = FlutterEngineGroup(name: "substitute-hintergrund", project: nil)

    private init() {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Die Rolle **plan**, und das ist der ganze Grund für diese Klasse:
        // Sie ist die eine Ansicht, die den Hintergrundauftrag macht
        // (`NativeShell.runsBackgroundWork`). Jede andere Rolle würde ihn
        // auslassen, und jede zweite solche Maschine würde ihn wiederholen.
        options.entrypointArgs = ["--substitute-role=plan"]
        options.initialRoute = "/abschnitt/plan"

        engine = group.makeEngine(with: options)
        // Siehe [FlutterEngines.registerPlugins]: Ohne das hätte diese Maschine
        // kein Programm und damit auch keinen Speicher – und es gäbe weder die
        // Pläne noch die Zugangsdaten noch das Theme.
        FlutterEngines.registerPlugins(on: engine)

        // Beide Bildschirme hängen an **dieser** einen Maschine.
        //
        // Sie ist die einzige, die die Werte kennt: Sie liest den Speicher, sie
        // fragt den VPlan, sie holt die Texte aus der Übersetzung. Die beiden
        // anderen Reiter haben eigene Maschinen, aber die wissen nichts über
        // den Plan – sie zu fragen hieße, sie zu einem Plan zu zwingen, den sie
        // nicht haben, und sie würden sich einen aus dem Speicher zusammensuchen,
        // der **älter** ist als der hier.
        ScreenBridge.setzeKanal(.plan, auf: engine)
        ScreenBridge.setzeKanal(.sync, auf: engine)

        // Und hier wird sie **gestartet** – siehe die Beschreibung oben.
        engine.run()
    }

    /// Bittet Dart, den Stand eines Bildschirms neu zu schicken.
    ///
    /// ## Warum das eine **Aktion** ist und kein eigener Aufruf
    ///
    /// Es ist dasselbe wie ein Tipp: „Zeig mir deinen Stand noch einmal." Dart
    /// entscheidet dann, ob es etwas Neues gibt, und schickt den Stand – durch
    /// denselben Weg wie sonst. Ein eigener Kanalaufruf dafür wäre eine zweite
    /// Tür in dieselben Daten, und durch sie käme irgendein Tag ein Stand herein,
    /// der nicht durch `publish` (dort drüben) gegangen ist.
    func fordereDatenAn(screen: ScreenBridge.Screen) {
        ScreenBridge.action(screen, "needsData")
    }
}

// MARK: - Der Plan einer Klasse

/// Die Bildschirme, die hinter der nativen Übersicht liegen.
///
/// ## Warum sie Flutter bleiben
///
/// Weil dort gearbeitet wird: Das Wochenraster aus [WeekPlan], die Stundenliste
/// mit ihren Ausblendungen, der Plan des Tages mit dem Wechsel auf den nächsten
/// Tag. Das sind keine Zeilen, sondern Raster mit eigenen Gesten – und für sie
/// wäre eine Tabelle ein Rückschritt.
///
/// Es sind also **echte** Bildschirme: eigene Leiste oben, eigener Bildschirm,
/// eigener Zustand. Nur die Tab-Leiste bleibt, weil man in einem Reiter
/// weitergeht – das ist die übliche iOS-Art, und der Reiter ist nicht das
/// Ziel dieser Navigation.
///
/// ## Warum eine **eigene** Maschine je Aufruf
///
/// Weil der Bildschirm seinen Zustand behalten soll, solange man ihn sieht.
/// Eine gemeinsame Maschine für alle Klassen hieße: Eine Klasse ansehen, zurück,
/// eine andere ansehen – und in derselben Ansicht stünde noch das Bild der
/// ersten. Genau das ist der Grund, warum `RootTabBarController` je Reiter eine
/// eigene Maschine angelegt hat.
///
/// Der Preis ist eine neue Isolate je Aufruf. Der ist hier vertretbar, weil ein
/// Plan **selten** geöffnet wird – anders als die Reiter, die man oft wechselt.
enum PlanDetailRoute {

    /// Öffnet den Plan einer Klasse – oder einer Person, wenn [personId] gesetzt ist.
    ///
    /// ## Warum nur die **Kennung** und nicht die ganze Person
    ///
    /// Eine Person ist ein Datensatz mit Namen, Klasse und Kursliste, und der
    /// kommt aus dem Speicher, in dem die native Seite ihn **nicht** kennt.
    /// Ihn zu übertragen hieße, ihn zu kopieren – und die Kopie wäre stale,
    /// sobald jemand in Flutter den Namen ändert.
    ///
    /// Deshalb geht nur die Kennung, und Dart sucht den Datensatz selbst. Was
    /// die native Seite nicht kennt, kann sie auch nicht falsch weitergeben.
    ///
    /// ## Ob Tag oder Woche
    ///
    /// Das entscheidet `showWeekView` – gesetzt in den Plan-Einstellungen. Die
    /// Einstellung wird hier **gelesen**, nicht mitgeschickt: Sie ist eine
    /// Einstellung, und Einstellungen stehen an einer Stelle ([AppStore]).
    static func present(
        classId: String,
        personId: String?,
        from navigation: UINavigationController?
    ) {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"

        var args = ["--substitute-role=tool"]
        args.append("--plan-class-id=\(classId)")
        if let personId, !personId.isEmpty {
            args.append("--plan-person-id=\(personId)")
        }
        options.entrypointArgs = args

        // Die Route entscheidet **nicht** über Tag oder Woche – das tut die
        // Einstellung, und die wird in Dart gelesen. Sie sagt nur, welcher von
        // beiden Bildschirmen geöffnet wird, und das entscheidet derselbe Wert.
        // Deshalb wird hier **nicht** geraten: Fiel `showWeekView` aus, nähme man
        // den Tagesplan, und wer die Woche eingestellt hat, bekäme sie nicht zu
        // sehen – ohne Fehler, ohne Erklärung.
        options.initialRoute = AppStore.showsWeekView ? "/plan/woche" : "/plan/tag"

        let group = FlutterEngineGroup(name: "substitute-plan", project: nil)
        let engine = group.makeEngine(with: options)
        // Siehe [FlutterEngines.registerPlugins].
        FlutterEngines.registerPlugins(on: engine)
        NativeShellBridge.register(on: engine)

        let controller = FlutterViewController(
            engine: engine, nibName: nil, bundle: nil)
        controller.view.backgroundColor = Appearance.background
        controller.title = classId

        navigation?.pushViewController(controller, animated: true)
    }
}
// MARK: - Die Werkzeuge, die hinter der Übersicht liegen

/// Die Bildschirme, die zum **Hinzufügen** nötig sind.
///
/// ## Warum sie Flutter sind und nicht die Übersicht auch
///
/// Weil Hinzufügen **tippen** heißt: Man braucht die Liste der Klassen aus dem
/// VPlan und ein Feld, in das man den Namen schreibt. Das sind zwei Dinge, die
/// man nur auf einem Bildschirm bedienen kann – und ein Bildschirm, auf dem man
/// tippt, ist in Flutter genau so gut aufgehoben wie die Klassenliste selbst.
///
/// Es sind also keine halben Bildschirme: Sie haben ihre eigene Leiste oben
/// und ihren eigenen Bildschirm. Die Tab-Leiste verschwindet dabei, denn man ist
/// gerade in einem Werkzeug und nicht auf einem anderen Reiter.
///
/// ## Warum **nicht** über [ScreenBridge.action]
///
/// Der Umweg über Dart wäre möglich und bräuchte einen Bildschirm in Dart, der
/// nur weiterreicht. Er wäre ein Schritt ohne Aussage: Die native Seite weiß
/// selbst, welches Werkzeug zu welchem Weg gehört, und Dart weiß es auch – aber
/// es ist eine **Entscheidung der Oberfläche**, und die gehört hierher.
///
/// Sobald Dart nicht antwortet – kein Kanal, kein Bildschirm –, wäre über diesen
/// Umweg **nichts** passiert. Ein Knopf, der manchmal tut, was er sagt und
/// manchmal gar nichts, ist schlimmer als einer, der immer das Richtige tut.
enum PlanWerkzeugRoute {

    /// Eine Klasse auswählen und eintragen.
    case klasseHinzufuegen

    /// Eine Person anlegen: Klasse wählen, Name eingeben, Kurse wählen.
    case personHinzufuegen

    /// Die Dart-Route, die dazu gehört.
    ///
    /// Englisch und ohne Umlaute, weil sie ein Schlüssel im Quelltext ist und
    /// nicht etwas, das jemand liest. Der angezeigte Titel kommt aus der
    /// Übersetzung in Dart – siehe `_werkzeug` dort.
    var dartRoute: String {
        switch self {
        case .klasseHinzufuegen: return "/werkzeug/klasse-hinzufuegen"
        case .personHinzufuegen: return "/werkzeug/person-hinzufuegen"
        }
    }

    /// Öffnet das Werkzeug **über** der nativen Reihe.
    static func present(
        _ route: PlanWerkzeugRoute, from navigation: UINavigationController?
    ) {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Die Rolle `tool` verhindert, dass Flutter den unteren Safe-Area-Bereich
        // als dauerhafte leere Schicht zeichnet – die Tab-Leiste ist hier
        // ausgeblendet, und unter dem Inhalt darf nichts leer bleiben.
        options.entrypointArgs = ["--substitute-role=tool"]
        options.initialRoute = route.dartRoute

        // Eine eigene Maschine: Das Werkzeug soll die Übersicht nicht zurücksetzen,
        // in der man vorher war.
        let group = FlutterEngineGroup(name: "substitute-plan-werkzeug", project: nil)
        let engine = group.makeEngine(with: options)
        // Siehe [FlutterEngines.registerPlugins]: Ohne das hätte diese Maschine
        // kein Programm und damit auch keinen Speicher.
        FlutterEngines.registerPlugins(on: engine)
        // Und an der Leiste anmelden – sonst wüsste diese Maschine nichts vom
        // Wechsel der Helligkeit, und der Bildschirm bliebe beim Umschalten in
        // der alten Farbe stehen. Siehe [NativeShellBridge.register(on:)].
        NativeShellBridge.register(on: engine)

        let controller = FlutterViewController(
            engine: engine, nibName: nil, bundle: nil)
        controller.view.backgroundColor = Appearance.background

        navigation?.pushViewController(controller, animated: true)
    }
}

// MARK: - Die drei Wege hinter „Sync & Teilen"

/// Die Bildschirme, die hinter dem Sync-Bildschirm liegen.
///
/// ## Warum sie Flutter sind
///
/// Weil dort gearbeitet wird: `ShareManager` verschlüsselt und überträgt,
/// `SyncMerge` gleicht zwei Stände ab, `SyncKeys` verwahrt die Schlüssel. Das
/// ist die eigentliche Arbeit der App, und sie bleibt in Dart.
///
/// Der Bildschirm davor ist eine Liste aus drei Zeilen – und genau deshalb ist
/// er nativ. Es gibt also **keinen** Bildschirm, der die Hälfte wäre: Entweder
/// die Liste ist eine Liste, oder die Arbeit dahinter ist Arbeit.
///
/// ## Warum **nicht** über [ScreenBridge.action]
///
/// Aus demselben Grund wie bei [PlanWerkzeugRoute]: Der Weg von einer Zeile zu
/// ihrem Bildschirm ist eine Entscheidung der Oberfläche, und die gehört hierher.
/// Über Dart ginge es auch – aber nur, solange Dart antwortet. Ein Eintrag, der
/// manchmal öffnet und manchmal nicht, ist schlimmer als einer, der immer öffnet.
enum SyncRoute {

    /// Die eigenen Geräte: einrichten und abgleichen.
    case sync

    /// Mit anderen Geräten teilen.
    case share

    /// Die Angebote anderer durchsuchen und übernehmen.
    case browse

    /// Die Dart-Route, die dazu gehört.
    var dartRoute: String {
        switch self {
        case .sync: return "/sync/sync"
        case .share: return "/sync/teilen"
        case .browse: return "/sync/angebote"
        }
    }

    /// Der Schlüssel, unter dem Dart diesen Weg schickt.
    ///
    /// **Englisch** und ohne Punkte, weil er ein Schlüssel im Quelltext ist und
    /// nicht etwas, das jemand liest. Er steht hier und in `PlanNativeBridge`
    /// (`publishSync`) – und an **beiden** Stellen, weil es keinen gemeinsamen Ort
    /// für Quelltext zweier Sprachen gibt.
    ///
    /// Der Schlüssel steht auch in [SyncHubScreen.symbolFuer(_:)]. Auch das
    /// ist Absicht: Wer einen Weg umbenennt, muss es an drei Stellen tun, und
    /// eine davon ist die, an der das Zeichen ausgewählt wird.
    var id: String {
        switch self {
        case .sync: return "sync"
        case .share: return "share"
        case .browse: return "browse"
        }
    }

    /// Öffnet den Bildschirm **innerhalb** der Reihe des Sync-Reiters.
    ///
    /// ## Warum hier nicht `PlanWerkzeugRoute`
    ///
    /// Weil hier die Tab-Leiste **stehen bleibt**. Man geht dabei in einem
    /// Reiter weiter, und die Leiste ist der Weg zurück – sie zu verstecken
    /// hieße, ihn suchen zu müssen.
    ///
    /// Deshalb auch nicht über `/werkzeug/…`: Diese Routen lassen die Leiste in
    /// `main.dart` verschwinden, weil sie über der Reihe stehen. Hier geht es in
    /// der Reihe weiter, und die Leiste gehört dazu.
    static func present(
        _ route: SyncRoute, from navigation: UINavigationController?
    ) {
        let options = FlutterEngineGroupOptions()
        options.entrypoint = "main"
        // Die Rolle `tool` nur gegen den **unteren** Rand: Die Tab-Leiste bleibt
        // da, aber Flutter soll keinen dauerhaften Safe-Area-Abstand als leere
        // Schicht zeichnen – der Platz steht am Ende der Liste
        // (`NativeShellScrollEndInset`).
        options.entrypointArgs = ["--substitute-role=tool"]
        options.initialRoute = route.dartRoute

        // Eine eigene Maschine: Die drei Wege sollen einander nicht zurücksetzen,
        // und wer sie offen lässt, soll sie beim Zurückkommen wiederfinden.
        let group = FlutterEngineGroup(name: "substitute-sync", project: nil)
        let engine = group.makeEngine(with: options)
        // Siehe [FlutterEngines.registerPlugins].
        FlutterEngines.registerPlugins(on: engine)
        NativeShellBridge.register(on: engine)

        let controller = FlutterViewController(
            engine: engine, nibName: nil, bundle: nil)
        controller.view.backgroundColor = Appearance.background
        // Ohne eigenen Titel stünde hier der der Bildschirmreihe – also der der
        // Liste. Der Bildschirm holt sich seinen Titel selbst, sobald er steht.
        controller.title = nil

        navigation?.pushViewController(controller, animated: true)
    }
}
