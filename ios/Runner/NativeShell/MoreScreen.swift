import UIKit

/// Die Einstellungen – der Abschnitt „Mehr“.
///
/// ## Was hier steht und was nicht
///
/// Hier stehen die Dinge, die man **nicht** jeden Tag braucht – und alleallealle
/// Bildschirme, die auf iOS **nativ** sind. Sie stehen deshalb hier und nicht in
/// Flutter: Sie brauchen keine Dart-Isolate, und sie sehen dadurch aus wie die
/// übrigen Apps auf dem Gerät. Die Zeilen, die es über die Leiste gibt, sind
/// dieselben wie auf Android – siehe [MoreScreen.makeSections].
///
/// Der Krankheitstracker ist von hier in die **Suche** gewandert. Er sucht
/// genauso wie die beiden anderen dort – nach der Klasse, der Stunden gefehlt
/// haben –, und die Suche ist auch auf iOS ein Reiter.
///
/// ## Fast alles hier ist jetzt nativ
///
/// Aussehen, Sprache, Schulen, Anmeldedaten, Plan-Einstellungen mit ihren vier
/// Untermenüs,,, die Entwickleroptionen, **Lehrerkürzel** und **Sichern &
/// Wiederherstellen** sind in `UIKit` gebaut, nicht in Flutter. Nicht, weil
/// Flutter das nicht könnte, sondern weil sie es nicht brauchen:
///
/// * Sie brauchen keine Dart-Isolate. Ein Bildschirm, der ein paar Werte liest
///   und schreibt, wäre in Flutter eine ganze laufende Umgebung, die es am
///   Anfang hochfährt und danach den Platz belegt.
/// * Sie sehen dadurch aus wie die übrigen Apps auf dem Gerät. Das ist der
///   Punkt der Umstellung: grosse Titel, Listen in Gruppen, Schalter wie von
///   iOS.
///
/// ## WasWasWas dasdasdas fürfürfür diediedie beidenbeidenbeiden letztenletztenletzten gekostetgekostetgekostet hathathat
///
/// BeideBeideBeide brauchtenbrauchtenbrauchten anfangsanfangsanfangs fremde Frameworks, und genau das war ihr Grund, in
/// Flutter zuzuzu bleiben:
///
/// * **Lehrerkürzel** brauchte den Vertretungsplan. Jetzt holt
///   [TeacherShortsStore] die Kürzel selbst – mit `URLSession` und einem
///   `XMLParser`. Das ist **nicht** derselbe Umfang wie `VPlanAPI` und soll auch
///   keiner werden: Plankonvertierung, Cache und Plandatei liegen weiterhin in
///   Flutter, und sie werden hier nicht ein zweites Mal gebaut.
/// * **Sichern & Wiederherstellen** brauchte `file_picker`, `share_plus` und
///   `ConfigBackup`. Die ersten beiden sind dünne Hüllen um
///   [UIDocumentPickerViewController] und [UIActivityViewController]; das dritte
///   ist dieselbe Schlüsselliste, um die es in [AppStore] geht. Die Rechenarbeit
///   steht jetzt in [ConfigBackupStore].
///
/// Das Dateiformat ist auf **beiden** Plattformen dasselbe. Das ist keine
/// Nebensache, sondern die Bedingung dafür, dass eine Datei vom Handy auf dem
/// iPhone etwas wiederherstellt – und umgekehrt.
final class MoreScreen: ListScreen {
    /// „Einstellungen“ als **Titel der Seite** – und nirgends sonst.
    ///
    /// ## Warum es derselbe Wortlaut ist wie früher die Zeile über der Liste
    ///
    /// Das Wort stand als Überschrift **innerhalb** der Liste („Settings“ über
    /// den Zeilen). Dort ist es am falschen Ort: Es steht *zwischen* der Leiste
    /// und dem ersten Eintrag, ist also weder eine Kopfzeile der Seite noch ein
    /// Name für etwas darin – und beim Scrollen läuft es weg, während der
    /// Bildschirm namenlos zurückbleibt.
    ///
    /// Als Titel der Seite sagt es dasselbe und zusätzlich, **was man geöffnet
    /// hat**: Es bleibt beim Scrollen als kleiner Titel in der Leiste stehen und
    /// klappt erst mit ihr zusammen, ganz so wie auf jeder anderen Seite dieser
    /// Bildschirmreihe.
    ///
    /// ## Warum das auch den leeren Platz vom letzten Mal behebt
    ///
    /// Damals wurde die Überschrift entfernt – und der Platz, den sie
    /// eingenommen hatte, blieb als leere Fläche unter der Leiste stehen (die
    /// Leiste reserviert die Höhe eines grossen Titels, auch wenn keiner da
    /// ist). Der Platz ist jetzt wieder **besetzt**: von genau diesem Titel.
    init() {
        super.init(title: L.settings)
    }

    /// Baut die Abschnitte aus dem aktuellen Stand.
    ///
    /// Neu gelesen, weil eine Zeile von den Zugangsdaten abhängt, die es erst
    /// seit dem letzten Besuch geben kann.
    ///
    /// ## Die Reihenfolge ist auf beiden Plattformen **gleich**
    ///
    /// Dieselbe Liste steht in `Settings.dart`. Zwei Reihenfolgen an zwei
    /// Stellen laufen auseinander, sobald eine Zeile verschoben wird – und auf
    /// iOS merkt es niemand, weil dort nur eine der beiden Listen zu sehen ist.
    ///
    /// Von oben: was man beim ersten Öffnen sucht (Aussehen), was den Alltag
    /// betrifft (Plan, Sprache, Lehrerkürzel), was man ab und zu braucht
    /// (Zugangsdaten, Schulen) – und ganz unten die Dinge, die man nur anfasst,
    /// wenn etwas nicht stimmt (Sicherung, Entwickleroptionen).
    ///
    /// **Zugangsdaten und Schulen stehen unmittelbar untereinander:** Beide sagen,
    /// woher die Daten kommen. Wer den Schulbereich wechselt, fasst danach die
    /// Schulen an – sie gehören deshalb nicht an zwei getrennte Stellen der App.
    override func makeSections() -> [Section] {
        var einstellungen: [Row] = [
            .choice(
                title: L.appearance,
                subtitle: L.appearanceSubtitle,
                symbol: "paintpalette"
            ) { self.zeige(AppearanceScreen()) },

            .choice(
                title: L.planSettings,
                subtitle: L.planSettingsSubtitle,
                symbol: "calendar.badge.clock"
            ) { self.zeige(PlanSettingsScreen()) },

            .choice(
                title: L.language,
                subtitle: L.languageSubtitle,
                symbol: "globe"
            ) { self.zeige(LanguageScreen()) },

            .choice(
                title: L.teacherShorts,
                subtitle: L.teacherShortsSubtitle,
                symbol: "person.text.rectangle"
            ) { self.zeigezeigezeige(TeacherShortsScreen()) },
        ]

        // Die Zugangsdaten stehen **nur** da, wenn es welche gibt.
        //
        // Stehen sie immer, wäre die Zeile bei einer neuen Installation ein
        // Versprechen, das noch nicht eingelöst ist – und sie führt genau dann
        // ins Nichts, wenn jemand sie zuerst braucht. Deshalb erscheint sie
        // erst mit dem ersten Benutzernamen.
        //
        // Das ist dasselbe Kriterium, nach dem die Tab-Leiste erscheint
        // ([AppStore.hasCredentials]): Der Werkzeugkasten ohne Leiste ist genau
        // die Lage, in der es auch ohne Zugangsdaten nichts zu tun gäbe.
        //
        // Die Schulen folgen ihm unmittelbar – siehe die Beschreibung von
        // [MoreScreen.makeSections].
        if AppStore.hasCredentials {
            einstellungen.append(
                .choice(
                    title: L.credentials,
                    subtitle: L.credentialsSubtitle,
                    symbol: "lock"
                ) { self.zeige(CredentialsScreen()) })
        }

        einstellungen.append(
            .choice(
                title: L.schools,
                subtitle: L.schoolsSubtitle,
                symbol: "building.2"
            ) { self.zeige(SchoolsScreen()) })

        einstellungen.append(
            .choice(
                title: L.backup,
                subtitle: L.backupSubtitle,
                symbol: "externaldrive.badge.timemachine"
            ) { self.zeigezeigezeige(BackupScreen()) })

        einstellungen.append(
            .choice(
                title: L.developerOptions,
                subtitle: L.developerOptionsSubtitle,
                symbol: "hammer"
            ) { self.zeige(DeveloperOptionsScreen()) })

        // **Ohne** `header` und **ohne** `footer`: Beide waren ein zweiter
        // Wortlaut fuer dieselbe Sache. Der Titel der Seite sagt „Einstellungen“
        // – eine Ueberschrift ueber der Liste und eine Fussnote darunter
        // wiederholten es nur und nahmen Platz weg, den die Zeilen brauchen.
        return [Section(rows: einstellungen)]
    }

    // --------------------------------------------------------------- Wege

    /// Öffnet den nächsten Bildschirm.
    ///
    /// Es gibt nur **einen** Weg, und das ist Absicht. Als die beiden letzten
    /// Bildschirme noch in Flutter lagen, gab es zwei: `zeige` für die nativen
    /// und `zeigeFlutter` für die über einer eigenen Flutter-Maschine geöffneten.
    ///
    /// Der zweite ist mit ihnen weggefallen. Ein Weg, der nichts mehr öffnet, ist
    /// kein Feature, sondern eine zweite Art, sich zu irren: Ein neu hinzugefügter
    /// Bildschirm landet in der einen Hälfte der App und nicht in der anderen –
    /// und auf iOS merkt es niemand, weil dort nur eine der beiden Hälften zu
    /// sehen ist.
    private func zeige(_ screen: UIViewController) {
        navigationController?.pushViewController(screen, animated: true)
    }
}
