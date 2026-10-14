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

    // ------------------------------------------------------------ Bildschirme

    /// Der Name des rechsten Reiters – und der Bildschirmes dahinter.
    ///
    /// Vorher stand hier „Dashboard“: ein Wort, das nichts ueber den Inhalt
    /// sagt. Der Reiter zeigt die Einstellungen, also heisst er jetzt auch so.
    static var settings: String { pick("Einstellungen", "Settings") }

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
            "Die Sprache deines Handys verwenden. Ist sie eine andere, gilt Deutsch.",
            "Use your phone's language. German is used for any other language.")
    }

    static var languageGermanSubtitle: String {
        pick(
            "Immer Deutsch, unabhängig vom Handy.",
            "Always German, whatever the phone says.")
    }

    static var languageEnglishSubtitle: String {
        pick(
            "Immer Englisch, unabhängig vom Handy.",
            "Always English, whatever the phone says.")
    }

    static var schools: String { pick("Schulen", "Schools") }

    static var credentials: String { pick("Anmeldeinformationen", "Credentials") }

    static var credentialsSubtitle: String {
        pick("stundenplan24 Anmeldeinformationen", "stundenplan24 credentials")
    }

    // ------------------------------------------------------------ Werkzeuge
    //
    // Diese beiden stehen weiterhin in Flutter, werden aber **hier** aufgeführt
    // – siehe [FlutterRoute]. Vorher waren sie über das Flutter-Dashboard zu
    // erreichen, und das gibt es als Reiter nicht mehr. Ohne diese Zeilen wären
    // sie auf iOS spurlos verschwunden.
    //
    // Der Krankheitstracker steht hier **nicht** mehr: Er ist in die Suche
    // gewandert (`SearchMenu.dart`), und die Suche ist auch auf iOS ein Reiter.

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

    // ------------------------------------------------- Plan-Einstellungen
    //
    // Vier Untermenüs, die früher in Flutter lagen. Die Texte sind wortgleich mit
    // `app_localizations_de.dart` und `_en.dart` – siehe die Beschreibung dieser
    // Datei oben.

    static var lessonInfoSettings: String {
        pick("Stunden-Informationen", "Lesson information")
    }

    static var lessonInfoSettingsSubtitle: String {
        pick("Was im Vertretungsplan angezeigt wird", "What is shown in the substitution plan")
    }

    static var hideLessonTimes: String {
        pick("Stundenzeiten ausblenden", "Hide lesson times")
    }

    static var hideLessonTimesSubtitle: String {
        pick(
            "Zeiten der einzelnen Stunden im Vertretungsplan ausblenden",
            "Hide times for individual lessons in the plan")
    }

    static var hideTeacher: String { pick("Lehrer ausblenden", "Hide Teacher") }

    static var hideTeacherSubtitle: String {
        pick(
            "Lehrernamen im Vertretungsplan ausblenden",
            "Hide teacher names in the substitution plan")
    }

    static var hidePersons: String { pick("Personen ausblenden", "Hide Persons") }

    static var hidePersonsSubtitle: String {
        pick("Den Personenbereich ausblenden", "Hide the persons section")
    }

    static var previewSettings: String { pick("Vorschau", "Preview") }

    static var previewSettingsSubtitle: String {
        pick(
            "Die „Nächste Stunde“-Vorschau ein- und ausblenden",
            "Show or hide the next lesson preview")
    }

    static var hidePreviewClasses: String {
        pick("Vorschau bei Klassen ausblenden", "Hide preview for classes")
    }

    static var hidePreviewClassesSubtitle: String {
        pick(
            "Die „Nächste Stunde“-Vorschau unterhalb der Klassen ausblenden",
            "Hide the next lesson preview below the classes")
    }

    static var hidePreviewPersons: String {
        pick("Vorschau bei Personen ausblenden", "Hide preview for persons")
    }

    static var hidePreviewPersonsSubtitle: String {
        pick(
            "Die „Nächste Stunde“-Vorschau unterhalb der Personen ausblenden",
            "Hide the next lesson preview below the persons")
    }

    static var defaultPlanModeEntry: String {
        pick("Standard-Planmodus", "Default plan mode")
    }

    static var defaultPlanModeEntrySubtitle: String {
        pick(
            "Getrennt für Personen, Klassen und deren Vorschauen",
            "Separately for persons, classes and their previews")
    }

    static var modeAuto: String { pick("Automatisch", "Automatic") }
    static var modeLatest: String { pick("Neueste", "Latest") }
    static var modeToday: String { pick("Heute", "Today") }

    /// Die Beschriftung eines Planmodus.
    ///
    /// Über eine Funktion und nicht über drei Felder, weil der Wert durch die
    /// Bildschirme läuft und dort überall derselbe sein muss: `PlanMode.automatisch`
    /// ohne passenden Namen ergäbe einen Bildschirm mit „nil" in der Zeile.
    static func titel(for mode: PlanMode) -> String {
        switch mode {
        case .automatisch: return modeAuto
        case .latest: return modeLatest
        case .today: return modeToday
        }
    }

    /// Die Überschrift der Gruppen „Personen" und „Klassen".
    ///
    /// Eigene Felder und nicht dieselben wie `defaultPlanModePerson` /
    /// `defaultPlanModeClass` in Dart, weil sie dort zugleich **zwei** Dinge
    /// meinen: die Überschrift der Gruppe **und** die Beschriftung einer
    /// Option. Hier tragen die Zeilen ihre eigene Beschriftung aus
    /// [titel(for:)], und deshalb kann die Überschrift hier stehen, wo sie
    /// hingehört.
    static var planModePerson: String { pick("Personen", "Persons") }
    static var planModeClass: String { pick("Klassen", "Classes") }

    /// Die Überschriften der beiden Vorschau-Gruppen.
    static var defaultPlanModePreviewClass: String {
        pick("Vorschau der Klassen", "Preview of classes")
    }

    static var defaultPlanModePreviewPerson: String {
        pick("Vorschau der Personen", "Preview of persons")
    }

    /// Die drei Erklärtexte der Planmodi.
    ///
    /// Sie stehen hier **einmal** und nicht je Gruppe: In Dart sind es zwölf
    /// fast gleiche Texte, die auseinanderlaufen können – und die Gruppen sollen
    /// dasselbe meinen. Wer's nicht glaubt, soll in `PlanModeSettings.dart` nach
    ///sehen: Dort ist derselbe Satz viermal hingeschrieben, weil man ihn dort
    /// für jede Gruppe einzeln übersetzt hat.
    static func modeSubtitle(for mode: PlanMode) -> String {
        switch mode {
        case .automatisch:
            return pick(
                "Zeige heute, außer der Schultag ist vorbei",
                "Show today, unless the school day is over")
        case .latest:
            return pick(
                "Immer den neuesten verfügbaren Plan anzeigen",
                "Always show the latest available plan")
        case .today:
            return pick(
                "Immer nur den heutigen Plan anzeigen",
                "Always show only today's plan")
        }
    }

    static var lessonTimes: String { pick("Stundenzeiten", "Lesson times") }

    static var lessonTimesSubtitle: String {
        pick(
            "Zeiten der einzelnen Unterrichtsstunden manuell einstellen",
            "Manually set the times for each lesson")
    }

    static var lessonCount: String { pick("Stunde", "Lesson") }

    static var noLessonTimes: String {
        pick("Noch keine Stundenzeiten", "No lesson times yet")
    }

    static var deleteLessonTitle: String {
        pick("Unterrichtszeit löschen?", "Delete lesson time?")
    }

    /// Der Satz, der beim Löschen einer Unterrichtszeit erklärt, was passiert.
    static func deleteLessonMessage(_ count: Int) -> String {
        pick(
            "Die \(count). Unterrichtszeit wird entfernt. Das kann nicht rückgängig gemacht werden.",
            "The \(count). lesson time will be removed. This cannot be undone.")
    }

    static var edit: String { pick("Bearbeiten", "Edit") }

    /// Die Bestätigung, wenn eine einzelne Unterrichtszeit gelöscht wurde.
    ///
    /// Bewusst in der Einzahl: Die Meldung erscheint genau dann, wenn **eine**
    /// Stunde verschwunden ist. „Stundenzeiten gelöscht" (die Mehrzahl) wäre die
    /// Aussage für die Entwickleroptionen, die wirklich alle löschen.
    static func lessonDeleted(_ count: Int) -> String {
        pick(
            "\(count). Unterrichtszeit gelöscht", "\(count). lesson time deleted")
    }

    // ------------------------------------------------------- Anmeldedaten

    static var settingsCredentials: String {
        pick("Anmeldeinformationen", "Credentials")
    }

    static var schoolNumber: String { pick("Schulnummer", "School-number") }

    static var username: String { pick("Benutzername", "Username") }

    static var password: String { pick("Passwort", "Password") }

    static var selfHost: String { pick("Eigene URL", "Your own URL") }

    static var useOwnUrl: String {
        pick("Eigene URL verwenden", "Use your own URL")
    }

    static var useOwnUrlSubtitle: String {
        pick(
            "Für stundenplan24 nicht nötig – nur bei einer selbst gehosteten Instanz",
            "Not needed for stundenplan24 – only for a self-hosted instance")
    }

    /// Der Satz unter dem Knopf „Speichern".
    static var credentialsFooter: String {
        pick(
            "Die Zugangsdaten werden auf diesem Gerät gespeichert und nirgends sonst.",
            "The credentials are stored on this device and nowhere else.")
    }

    /// Der Hinweis, wenn ein gelesener Code keine Zugangsdaten enthält.
    static var qrNotReadable: String {
        pick(
            "Der gelesene Code enthält keine Zugangsdaten dieser App.",
            "The scanned code does not contain credentials of this app.")
    }

    static var useLogin: String {
        pick("oder nutze den offiziellen Login", "or use official Login")
    }

    static var useSelfHost: String {
        pick("oder nutze deine eigene URL", "or use your own URL")
    }

    static var credsSaved: String {
        pick("Zugangsdaten gespeichert!", "Credentials saved!")
    }

    static var shareCreds: String {
        pick("Zugangsdaten teilen", "Share credentials")
    }

    static var shareCredsSubtitle: String {
        pick(
            "Zugangsdaten als QR-Code weitergeben",
            "Pass the credentials on as a QR code")
    }

    static var scanCreds: String { pick("QR-Code scannen", "Scan QR code") }

    static var scanCredsSubtitle: String {
        pick(
            "Zugangsdaten eines anderen Geräts übernehmen",
            "Take over the credentials of another device")
    }

    static var share: String { pick("Teilen", "Share") }

    /// Der Satz über dem QR-Code der Zugangsdaten.
    static var credsQrHint: String {
        pick(
            "Mit einem zweiten Gerät scannen, um die Zugangsdaten zu übernehmen.",
            "Scan with a second device to take over these credentials.")
    }

    static var cameraUnavailable: String {
        pick("Die Kamera ist nicht verfügbar.", "The camera is not available.")
    }

    static var cameraDenied: String {
        pick(
            "Für das Scannen wird der Zugriff auf die Kamera benötigt. Er lässt sich in den Einstellungen erteilen.",
            "Scanning needs access to the camera. It can be granted in Settings.")
    }

    static var openSettings: String {
        pick("Einstellungen öffnen", "Open Settings")
    }

    // -------------------------------------------------- Entwickleroptionen

    static var customDate: String {
        pick("Eigenes Datum & Uhrzeit", "Custom date & time")
    }

    static var noOverride: String { pick("Keine Überschreibung", "No override") }

    static var clearOverride: String {
        pick("Überschreibung entfernen", "Remove override")
    }

    static var clearOverrideSubtitle: String {
        pick(
            "Die App rechnet wieder mit der wirklichen Uhrzeit",
            "The app goes back to using the real time")
    }

    /// Der Name der Zeile – bewusst kurz.
    ///
    /// „Zusätzliche Sync-Angaben zeigen" war eine Anweisung im Titel eines
    /// Schalters. Ein Schalter **ist** die Anweisung; im Titel wiederholt sie
    /// sie sich nur. Der Name sagt, **was** eingestellt wird, und der Schalter
    /// daneben sagt, dass es ein- und ausgeschaltet wird.
    static var showSyncDetails: String {
        pick("Sync-Details", "Sync details")
    }

    /// Die Erklärung darunter – das Detail, das im Namen keinen Platz hat.
    ///
    /// Kurz genug, um neben einem Schalter auf **einer** Zeile zu stehen.
    static var showSyncDetailsSubtitle: String {
        pick(
            "Serverstatus, automatischer Abgleich und übertragene Einträge",
            "Server status, automatic sync and transferred entries")
    }

    static var deleteOfflinePlans: String {
        pick("Offline gespeicherte Pläne löschen", "Delete offline substitution plan")
    }

    static var clearAllSettings: String {
        pick("Alle gespeicherten Einstellungen löschen", "Clear all SharedPreferences")
    }

    static var clearAllSettingsMessage: String {
        pick(
            "Damit werden alle gespeicherten Werte der App entfernt – Zugangsdaten, Einstellungen, Schulbereiche und Pläne. Das kann nicht rückgängig gemacht werden.",
            "This removes every stored value of the app – credentials, settings, school areas and plans. This cannot be undone.")
    }

    static var clearAllSettingsTitle: String {
        pick("Alle Einstellungen löschen?", "Clear all settings?")
    }

    static var removeTeacherShorts: String {
        pick("Lehrerkürzel entfernen", "Remove Teacher abbreviations")
    }

    static var clearNewsFeeds: String { pick("Neuigkeiten-Feeds leeren", "Clear news feeds") }

    static var materialYou: String { pick("Material You", "Material You") }

    /// Der Zustand von „Material You" – als Erklärung unter der Zeile.
    ///
    /// Über eine Funktion statt über zwei Felder, weil der Zustand an **einer**
    /// Stelle entschieden wird. Zwei Felder müssten an zwei Stellen gepflegt
    /// werden, und irgendwann stünde da „an", während die Einstellung aus war.
    static func materialYouSubtitle(_ an: Bool) -> String {
        an
            ? pick(
                "An – die Farben folgen dem System",
                "On – colours follow the system")
            : pick(
                "Aus – die Farben sind fest",
                "Off – colours are fixed")
    }

    static var developerData: String { pick("Daten", "Data") }

    static var developerDataSubtitle: String {
        pick(
            "Diese Handgriffe nehmen gespeicherte Werte weg. Sie lassen sich hier nicht rückgängig machen.",
            "These actions remove stored values. They cannot be undone from here.")
    }

    static var developerFlags: String { pick("Schalter", "Flags") }

    static var deleteLessonTimes: String {
        pick("Stundenzeiten löschen", "Delete lesson times")
    }

    static var markFirstTime: String {
        pick("Als „erster Start“ merken", "Set \"first time\" to true")
    }

    static var offlinePlansDeleted: String {
        pick("Offline gespeicherte Pläne gelöscht", "Offline substitution plans deleted")
    }

    static var allSettingsCleared: String {
        pick("Alle gespeicherten Werte gelöscht", "All stored values cleared")
    }

    static var teacherShortsRemoved: String {
        pick("Lehrerkürzel entfernt", "Teacher abbreviations removed")
    }

    static var newsFeedsCleared: String {
        pick("Neuigkeiten-Feeds geleert", "News feeds cleared")
    }

    static var lessonTimesDeleted: String {
        pick("Stundenzeiten gelöscht", "Lesson times deleted")
    }

    static var firstTimeSet: String {
        pick("Als „erster Start“ gemerkt", "Marked as first start")
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

    /// „Alles leeren" – eigens, weil es etwas anderes ist als [delete].
    ///
    /// Ein Knopf „Löschen" neben der Zeile „Alle gespeicherten Einstellungen"
    /// liest sich wie „diese eine Einstellung löschen". Gemeint ist aber, dass
    /// **alle** weggehen – und das steht so auch im Knopf.
    static var clear: String { pick("Leeren", "Clear") }

    /// „Löschen" in einem Dialog, in dem es **eine** Sache zu löschen gibt.
    ///
    /// Eigenes Feld und nicht [delete]: Der Knopf beim Löschen einer Schule ist
    /// ein reiner Aktionstext, der an einer Zeile hängt; der hier steht in einem
    /// Dialog, in dem **nichts** passiert, wenn man ihn verlässt. Dieselbe
    /// Beschriftung für beides liest sich, als wäre beides dasselbe.
    static var deleteAction: String { pick("Löschen", "Delete") }

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