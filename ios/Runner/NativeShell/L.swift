import Foundation

/// Die Beschriftungen der **nativen** Bildschirme.
///
/// ## Warum hier und nicht in `Localizable.strings`
///
/// Beides wäre möglich, und beides wird hier **nicht** deshalb vermieden, weil
/// es unbequemer wäre: Es gibt einen sachlichen Grund.
///
/// Die Texte in `Localizable.strings` stehen dort, weil **Flutter** sie
/// braucht – die Flutter-Bildschirme greifen über `AppLocalizations` darauf
/// zu, und nur die wissen, welche Sprache gerade gilt. Eine native Ansicht, die
/// denselben Text anzeigen will, muss sich diese Sprache erst beschaffen.
///
/// Das hier ist der direkte Weg: Eine Swift-Funktion, die den Text nach der
/// eingestellten Sprache liefert. Sie steht bewusst **neben** den Übersetzungen
/// und nicht darin, und sie ist an einer Stelle gesammelt – so dass man sieht,
/// welche Bildschirme noch Text von Flutter brauchen.
///
/// ## Dieselben Wörter wie dort
///
/// Die deutschen und englischen Texte sind wortgleich mit denen in
/// `app_localizations_de.dart` und `_en.dart`. Das ist Absicht: Wer die App auf
/// Deutsch benutzt, soll auf beiden Seiten dasselbe lesen, und zwei leicht
/// abweichende Formulierungen wären genau der Unterschied, den niemand bemerkt
/// und alle stört.
enum L {
    // ------------------------------------------------------------ Tab-Leiste

    static var vplanStudents: String {
        pick("Vertretungsplan Schüler", "vplan students")
    }

    static var search: String { pick("Suche", "Search") }

    static var syncShare: String { pick("Sync & Share", "Sync & Share") }

    static var dashboard: String { pick("Dashboard", "dashboard") }

    // ------------------------------------------------------------ Bildschirme

    static var settings: String { pick("Einstellungen", "Settings") }

    static var settingsSubtitle: String {
        pick(
            "Weitere Einstellungen zur Personalisierung Ihrer Erfahrung",
            "More Settings to personalize your experience")
    }

    static var appearance: String { pick("Aussehen", "Appearance") }

    static var appearanceSubtitle: String {
        pick(
            "Hell oder dunkel, und was in der Navigationsleiste steht",
            "Light or dark, and what the navigation bar shows")
    }

    static var appearanceTheme: String {
        pick("Erscheinungsbild", "Theme")
    }

    static var appearanceThemeSubtitle: String {
        pick("Schaltet zwischen Hell und Dunkel um", "Switches between light and dark")
    }

    static var dark: String { pick("Dunkel", "Dark") }

    static var light: String { pick("Hell", "Light") }

    static var showSyncTab: String { pick("Synchronisations-Menü", "Sync menu") }

    static var showSyncTabSubtitle: String {
        pick(
            "Blendet das Synchronisations-Menü in der Navigationsleiste am unteren Rand ein oder aus",
            "Shows or hides the Sync menu in the navigation bar at the bottom of the screen")
    }

    static var showWeekView: String { pick("Wochenansicht", "Weekly view") }

    static var showWeekViewSubtitle: String {
        pick(
            "Beim Antippen einer Klasse oder Person den Plan der gesamten Woche anzeigen",
            "Show the plan for the entire week when tapping a class or person")
    }

    static var language: String { pick("Sprache", "Language") }

    static var languageSubtitle: String {
        pick("Sprache der App ändern", "Change the language of the app")
    }

    static var languageSystem: String { pick("Systemsprache", "System language") }

    static var languageSystemSubtitle: String {
        pick(
            "Die Sprache deines Handys verwenden. Ist sie nicht Deutsch oder Englisch, wird Deutsch verwendet.",
            "Use your phone's language. If it is neither German nor English, German is used.")
    }

    static var languageGermanSubtitle: String {
        pick(
            "Immer Deutsch, unabhängig vom Handy.",
            "Always German, regardless of your phone.")
    }

    static var languageEnglishSubtitle: String {
        pick(
            "Immer Englisch, unabhängig vom Handy.",
            "Always English, regardless of your phone.")
    }

    static var schools: String { pick("Schulen", "Schools") }

    static var credentials: String { pick("Anmeldeinformationen", "Credentials") }

    static var credentialsSubtitle: String {
        pick("stundenplan24 Anmeldeinformationen", "stundenplan24 credentials")
    }

    // ------------------------------------------------------------ Werkzeuge
    //
    // Diese vier stehen weiterhin in Flutter, werden aber **hier** aufgeführt –
    // siehe [FlutterRoute]. Vorher waren sie über das Flutter-Dashboard zu
    // erreichen, und das gibt es als Reiter nicht mehr. Ohne diese Zeilen wären
    // sie auf iOS spurlos verschwunden.

    static var planSettings: String { pick("Plan-Einstellungen", "Plan Settings") }

    static var planSettingsSubtitle: String {
        pick("Einstellungen für den Vertretungsplan", "Settings for the substitution plan")
    }

    static var teacherShorts: String {
        pick("Lehrerkürzel festlegen", "Set Teacher abbreviations")
    }

    static var teacherShortsSubtitle: String {
        pick("Lehrerkürzel durch echte Namen ersetzen", "Replace teacher abbreviations with Real ones")
    }

    static var backup: String { pick("Sichern & Wiederherstellen", "Backup & Restore") }

    static var backupSubtitle: String {
        pick(
            "Einstellungen, Klassen, Personen und gespeicherte Vertretungspläne exportieren und importieren",
            "Export and import settings, classes, persons and cached substitution plans")
    }

    static var developerOptions: String {
        pick("Entwickleroptionen", "Developer options")
    }

    static var developerOptionsSubtitle: String {
        pick("Einstellungen für Entwickler ändern", "Change Settings meant for developers")
    }

    static var schoolsSubtitle: String {
        pick("Schulbereiche und Zugangsdaten wechseln", "Switch school areas and credentials")
    }

    static var sickTrack: String { pick("Krankheitstracker", "Sick-Track") }

    static var sickTrackSubtitle: String {
        pick(
            "Verpasste Stunden verfolgen und Unterschriften holen",
            "Track missed lessons and get signatures for them")
    }

    // --------------------------------------------------------------- Werkzeuge

    static var addSchool: String { pick("Schule hinzufügen", "Add School") }

    static var renameSchool: String { pick("Schule umbenennen", "Rename School") }

    static var deleteSchool: String { pick("Schule löschen", "Delete School") }

    static var schoolNamePlaceholder: String {
        pick("Name der Schule", "School name")
    }

    static var cancel: String { pick("Abbrechen", "Cancel") }

    static var save: String { pick("Speichern", "Save") }

    static var done: String { pick("Fertig", "Done") }

    static var delete: String { pick("Löschen", "Delete") }

    /// Der Satz, der beim Löschen einer Schule erklärt, was passiert.
    ///
    /// Er sagt bewusst, dass die Daten **bleiben**: Wer löscht, erwartet sonst,
    /// dass alles weg ist, und später nach einer Schulart zu suchen, die nicht
    /// mehr da ist, ist ärgerlicher als ein ungenutzter Rest.
    static var deleteSchoolMessage: String {
        pick(
            "Die Schule wird aus der Auswahl entfernt. Ihre gespeicherten Bereichsdaten bleiben auf dem Gerät unangetastet.",
            "The school will be removed from the list. Its stored data stays on this device untouched.")
    }

    static var deleteSchoolTitle: String { pick("Schule löschen?", "Delete school?") }

    static var keepFirstSchool: String {
        pick(
            "Die erste Schule bleibt als Standard erhalten.",
            "The first school is kept as the default.")
    }

    static var noSchoolsYet: String {
        pick("Noch keine Schule angelegt", "No school added yet")
    }

    // ------------------------------------------------------------------ Logik

    /// Liefert den passenden Text für die gerade eingestellte Sprache.
    ///
    /// ## Die Regel hinter der Auswahl
    ///
    /// Bei `system` zählt die Sprache des Geräts. Ist sie **weder** Deutsch
    /// **noch** Englisch, wird Deutsch genommen – und nicht Englisch: Die App
    /// gibt es auf diesen beiden Sprachen, und eine französische Oberfläche
    /// durch Englisch zu ersetzen wäre es nicht.
    ///
    /// Dieselbe Regel steht in `AppLanguage.resolve`.
    static func pick(_ german: String, _ english: String) -> String {
        switch AppStore.language {
        case .deutsch:
            return german
        case .english:
            return english
        case .system:
            let code = Locale.preferredLanguages.first.map {
                Locale(identifier: $0).languageCode ?? ""
            }
            return code == "en" ? english : german
        }
    }
}