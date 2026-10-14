import UIKit

/// Das Zuhause der App – und der Grund, warum die Kopfzeile jetzt nativ ist.
///
/// ## Was dieser Bildschirm ersetzt
///
/// In `main.dart` stand ein Rahmen um **jeden** Abschnitt: ein Container, der
/// 20 % der Bildschirmhöhe einnahm, mit dem Wort „Substitute", dem Logo links
/// und einem Knopf rechts, der ein Modal mit Version und Links öffnete. Das war
/// das, woran man die App als Flutter-App erkannte – nicht an den Listen,
/// sondern an diesem Rahmen, der auf **jedem** Bildschirm hing.
///
/// Unter der nativen Schale gibt es diesen Rahmen nicht mehr. Die Kopfzeile
/// macht die Leiste von `UINavigationController`, mit grossem Titel, mit dem
/// Knopf oben rechts und mit allem, was iOS beim Scrollen damit macht.
///
/// Was bleibt, ist der **Inhalt** des Knopfes: Version, GitHub, ein Problem
/// melden. Er ist jetzt [HomeScreen] – eine Seite mit Zeilen und einer Fußnote,
/// wie jede andere Einstellungsseite auf dem Gerät.
///
/// ## Warum eine Seite und kein Dialog
///
/// Das Modal in Flutter war ein [ModalBottomSheet] mit zentriertem Text und
/// unterstrichenen Links. Unterstrichene Links sind ein **Web**-Muster: Sie
/// sagen „hier kann man nichts tun, nur weitersuchen". Auf iOS sind das Zeilen
/// mit einem Pfeil daneben, und die Seite, auf der sie stehen, hat einen Titel.
///
/// Der Knopf wird außerdem nicht mehr gebraucht, um zu dieser Seite zu kommen:
/// Das **Logo** in der Leiste führt hierher – dieselbe Geste wie vorher, nur
/// ohne den Umweg über ein Blatt, das man erst wegschieben muss.
final class HomeScreen: ListScreen {

    init() {
        super.init(title: L.appName, largeTitle: true)
    }

    /// Die Abschnitte der App, in der Reihenfolge der Leiste.
    ///
    /// ## Warum hier und nicht aus der Leiste **gelesen**
    ///
    /// `RootTabBarController` hält seine Abschnitte **absichtlich** für sich
    /// (`Tab` ist `private`, siehe dort). Das ist die richtige Entscheidung:
    /// Die Leiste entscheidet, welche Abschnitte es gibt – das Sync steht hinter
    /// einer Einstellung, und der Schulbereich kann sie alle verschieben.
    ///
    /// Diese Seite baut deshalb ihre **eigene** Liste und fragt die Leiste nur
    /// danach, **wo** sie steht. Ein Eintrag, den es gerade nicht gibt, wird
    /// übersprungen statt als Zeile angeboten, die ins Leere führt.
    override func makeSections() -> [Section] {
        var abschnitte: [Row] = []

        // Der Plan ist immer da und ist immer der erste Abschnitt.
        abschnitte.append(zeileZuReiter(0, titel: L.vplanStudents, symbol: "calendar"))

        // Die Suche steht immer an zweiter Stelle, solange der Sync-Eintrag
        // ausgeschaltet ist – deshalb wird nicht geraten, sondern **geprüft**:
        // Sonst stünde hier „Suche" zweimal, sobald der Sync-Eintrag da ist.
        let syncStehtDrin = AppStore.showsSyncShareTab
        let suchenReiter = syncStehtDrin ? 2 : 1
        abschnitte.append(
            zeileZuReiter(suchenReiter, titel: L.search, symbol: "magnifyingglass"))

        if syncStehtDrin {
            abschnitte.append(zeileZuReiter(2, titel: L.syncShare, symbol: "arrow.triangle.2.circlepath"))
        }

        abschnitte.append(
            zeileZuReiter(syncStehtDrin ? 3 : 2, titel: L.dashboard, symbol: "ellipsis.circle"))

        let info: [Row] = [
            .choice(title: L.github, symbol: "chevron.left.forwardslash.chevron.right") {
                AppInfo.oeffne("https://www.github.com/Sergey842248/Substitute")
            },
            .choice(title: L.openIssue, symbol: "exclamationmark.bubble") {
                AppInfo.oeffne(
                    "https://www.github.com/Sergey842248/Substitute/issues/new?template=bug_report.yml")
            },
        ]

        return [
            Section(header: L.sections, footer: nil, rows: abschnitte),
            // Die Version steht **in** der Fußnote und nicht als eigene Zeile.
            //
            // Als Zeile wäre sie ein Eintrag, den man antippen könnte – und es
            // passiert nichts, wenn man es tut. Sie ist aber die Angabe, die man
            // beim Melden eines Problems braucht; deshalb steht sie dort, wo sie
            // gelesen wird, statt einen Knopf zu behaupten.
            //
            // Und `nil` statt einer leeren Fussnote, wenn keine Version im
            // Bündel steht: Eine leere Fussnote ist kein leerer Raum, sondern
            // eine Zeile Höhe mit nichts darin – und das sieht aus wie ein Fehler
            // in der Liste, den man nicht findet.
            Section(
                header: L.about,
                footer: AppInfo.version.isEmpty ? nil : L.version(AppInfo.version),
                rows: info),
        ]
    }
}

// MARK: - Die Zeilen, die einen Reiter ansteuern

extension HomeScreen {

    /// Eine Zeile, die zum Reiter an der Stelle `index` führt.
    ///
    /// ## Warum `index` geprüft wird und nicht nur „nimmt die Leiste"
    ///
    /// Ein Reiter, den es gerade nicht gibt, ist kein Fehler – er ist einer,
    /// den die Leiste absichtlich nicht zeigt. Eine Zeile, die ins Leere
    /// springt, ist schlimmer als eine, die fehlt: Sie **verspricht** einen Weg,
    /// den es nicht gibt, und tut dann so, als wäre nichts geschehen.
    ///
    /// Deshalb wird die Zeile nur gebaut, wenn der Reiter wirklich existiert.
    /// Die Prüfung ist deshalb **stillschweigend**: Ein Eintrag, den es nicht
    /// gibt, ist eine Entscheidung der Leiste – kein Fehler, den man dem
    /// Benutzer erklären müsste.
    private func zeileZuReiter(_ index: Int, titel: String, symbol: String) -> Row {
        .choice(title: titel, symbol: symbol) { [weak self] in
            guard let tabs = self?.tabBarController?.viewControllers,
                  index >= 0, index < tabs.count
            else { return }
            self?.tabBarController?.selectedIndex = index
            self?.navigationController?.popToRootViewController(animated: false)
        }
    }

}

// MARK: - Die Angaben, die vorher im Modal standen

/// Was früher das Blatt unter dem Knopf oben rechts war.
///
/// ## Warum das hier steht und nicht in [HomeScreen]
///
/// Weil es an **zwei** Stellen gebraucht wird: als Seite in der Bildschirmreihe
/// (über das Logo) und als kurzes Blatt (über den Knopf). Beide zeigen
/// dieselben zwei Angaben – und hätten sie je eine eigene Fassung, wäre es nur
/// eine Frage der Zeit, bis eine davon eine Zeile weniger hat.
enum AppInfo {

    /// Die Version der App.
    ///
    /// Aus dem Bündel, nicht aus dem Speicher: Sie wird von Apple gebaut und
    /// nicht von uns. Vorher stand sie in Dart und kam aus
    /// `package_info_plus` – dieselbe Zahl, aber auf einem Umweg über ein
    /// Zusatzprogramm, das hier gar nicht gebraucht wird.
    ///
    /// Steht keine Version im Bündel – etwa in einem Test –, wird nichts
    /// erfunden: `""`, und die Fußnote bleibt leer. Eine Zeile, die „0.0.0"
    /// behauptet, ist schlimmer als eine, die gar nichts sagt.
    static var version: String {
        let info = Bundle.main.infoDictionary
        guard let kurz = info?["CFBundleShortVersionString"] as? String,
              let lang = info?["CFBundleVersion"] as? String
        else { return "" }
        return "\(kurz) (\(lang))"
    }

    /// Öffnet einen Link.
    ///
    /// ## Warum hier und nicht [UIApplication.shared.open]
    ///
    /// Weil beides dasselbe tut und nur eines davon **beprüft** werden kann:
    /// Ob überhaupt etwas zum Öffnen da ist. `open(_:)` gibt nichts zurück und
    /// meldet nichts – ein Tipp auf „GitHub" ohne Netz wäre danach ein Tipp
    /// auf nichts, ohne jede Rückmeldung.
    static func oeffne(_ url: String) {
        guard let ziel = URL(string: url) else { return }
        UIApplication.shared.open(ziel, options: [:], completionHandler: nil)
    }

    /// Das kurze Blatt, das der Knopf oben rechts öffnet.
    ///
    /// ## Warum ein Blatt und keine ganze Seite
    ///
    /// Der Knopf steht **auf** einem Bildschirm, und was er öffnet, gehört zu
    /// diesem Bildschirm – nicht zu einem eigenen. Das ist der Unterschied
    /// zwischen einer Seite und einem Blatt: Eine Seite hat einen Ort in der
    /// Bildschirmreihe und einen Zurück-Pfeil; ein Blatt gehört zu dem, worüber
    /// es liegt.
    ///
    /// [HomeScreen] bekommt trotzdem einen Platz in der Reihe, weil das Logo
    /// dorthin führt – und dort ist es dieselbe Seite, nur mit dem Weg zurück.
    static func presentSheet(from presenter: UIViewController) {
        let blatt = UIAlertController(
            title: L.appInfo, message: version.isEmpty ? nil : L.version(version),
            preferredStyle: .actionSheet)

        blatt.addAction(
            UIAlertAction(title: L.github, style: .default) { _ in
                oeffne("https://www.github.com/Sergey842248/Substitute")
            })
        blatt.addAction(
            UIAlertAction(title: L.openIssue, style: .default) { _ in
                oeffne(
                    "https://www.github.com/Sergey842248/Substitute/issues/new?template=bug_report.yml")
            })
        blatt.addAction(
            UIAlertAction(title: L.close, style: .cancel))

        // Ohne das stünde das Blatt auf einem iPad mittig über allem und wäre
        // dort ein Popover mit Pfeil, der ins Leere zeigt.
        if let popover = blatt.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.maxX - 1, y: 0, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }

        presenter.present(blatt, animated: true)
    }
}

// MARK: - Der Knopf, der von der Leiste in die Seite führt

/// Der Knopf oben rechts: die drei Punkte.
///
/// ## Warum das Symbol und kein Text
///
/// iOS setzt an diese Stelle ein Symbol, und ein Wort daneben („Info") wäre an
/// jedem Bildschirm eine zweite, konkurrierende Benennung. Der Name steht in
/// `accessibilityLabel` – sichtbar wird er nie, gesprochen aber schon.
enum AppInfoBarButton {
    static func make(target: Any?, action: Selector) -> UIBarButtonItem {
        let knopf = UIBarButtonItem(
            image: UIImage(
                systemName: "ellipsis.circle",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
            style: .plain, target: target, action: action)
        knopf.accessibilityLabel = L.appInfo
        return knopf
    }
}

/// Der Knopf links, über den die Seite [HomeScreen] aufgerufen wird.
///
/// Das Logo, das vorher in der Flutter-Kopfzeile stand – nur mit dem Ziel, das
/// vorher ein Blatt war und jetzt eine Seite ist.
enum LogoBarButton {
    static func make(target: Any?, action: Selector) -> UIBarButtonItem {
        let bild = UIImage(named: "AppLogo") ?? UIImage(systemName: "app.dashed")
        let knopf = UIBarButtonItem(
            image: UIImage(
                image: bild,
                withConfiguration: UIImage.SymbolConfiguration(scale: .medium)),
            style: .plain, target: target, action: action)
        // Der Knopf ist 24 Punkte breit – so breit wie die Symbole der Leiste
        // sind 28. Er ist ein Erkennungszeichen, kein Gegenstand der Anzeige;
        // größer geklebt klebt er am Rand und zieht die Aufmerksamkeit vom Titel
        // weg.
        knopf.accessibilityLabel = L.home
        return knopf
    }
}