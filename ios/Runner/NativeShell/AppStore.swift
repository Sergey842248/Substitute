import Foundation

/// Die Speicherwerte der App – gelesen und geschrieben von **beiden** Seiten.
///
/// ## Warum es das gibt
///
/// Auf iOS besteht die App aus zwei Teilen: einer nativen Schale aus `UIKit`
/// (Tab-Leiste, Kopfzeilen, Einstellungen) und den Flutter-Ansichten, die den
/// Inhalt liefern. Beide brauchen dieselben Einstellungen, und beide müssen
/// sich geeignet verstehen, wenn die andere sie ändert.
///
/// Der naheliegende Weg wäre, der nativen Seite eigene Felder zu geben. Das
/// wäre aber genau die Falle, in die man hier fast tappt: Zwei Ablagen, in die
/// derselbe Wert geschrieben werden kann, stimmen irgendwann nicht mehr
/// überein, und das fällt erst auf, wenn jemand auf einem Gerät einmal das eine
/// und einmal das andere benutzt hat.
///
/// Deshalb wird hier **kein** Wert gehalten. Es gibt nur eine Ablage:
/// `UserDefaults.standard`, und die Schlüssel sind dieselben, die Flutter
/// schreibt. Damit ist es unmöglich, dass die beiden Seiten auseinanderlaufen.
///
/// ## Das `flutter.` – und warum es hier hingesetzt wird
///
/// `shared_preferences` legt auf iOS jeden Schlüssel mit dem Vorsatz `flutter.`
/// in `UserDefaults.standard` ab. Das ist eine Entscheidung des Pakets, keine
/// der App – aber es ist die Entscheidung, an der sich alles ausrichtet.
///
/// Wer den Vorsatz weglässt, schreibt in dieselbe Datei, aber unter einem
/// anderen Namen: `appearance.theme` und `flutter.appearance.theme` stehen dann
/// nebeneinander, und es sieht aus, als wäre die Einstellung verloren
/// gegangen. Deshalb steht der Vorsatz hier an **einer** Stelle – [prefix] – und
/// nirgends sonst im Code.
///
/// ## Dasselbe gilt für den Schulbereich
///
/// Die Werte sind nach Schule getrennt: `schools.<id>.showWeekView`. Auch das
/// bildet [AppStore] ab, mit derselben Regel wie in `SchoolStorage.dart`.
enum AppStore {
    /// Der Vorsatz, den `shared_preferences` auf iOS setzt.
    ///
    /// Siehe die Beschreibung oben: Weglassen wäre kein Detail, sondern ein
    /// stiller Datenverlust – die native Seite schriebe dann in andere
    /// Schlüssel als Flutter und beide zeigten ihren eigenen Stand.
    private static let prefix = "flutter."

    private static var defaults: UserDefaults { .standard }

    // ---------------------------------------------------------- Schulbereich

    /// Die Kennung des Schulbereichs, für den gerade gespeichert wird.
    ///
    /// Für die erste Schule ist das `default`, und dann tragen die Schlüssel
    /// **keinen** Vorspann. Das ist keine Vereinfachung, sondern dieselbe
    /// Regel wie in `SchoolStorage.scopedKey`: Eine bestehende Installation hat
    /// ihre Werte ohne Vorspann, und mit einem Vorspann geschrieben, wären sie
    /// unsichtbar – die App erschiene frisch installiert.
    static var activeSchoolId: String {
        defaults.string(forKey: key("activeSchoolId")) ?? "default"
    }

    /// Der Schlüssel einer Einstellung, so wie Flutter sie schreibt.
    ///
    /// Hier wird der Schulbereich einbezogen; siehe [scoped].
    static func key(_ name: String) -> String {
        let schoolId = activeSchoolId
        guard schoolId != "default" else {
            return prefix + name
        }
        return prefix + "schools.\(schoolId).\(name)"
    }

    /// Wie [key], aber für einen **bestimmten** Schulbereich.
    ///
    /// Nötig für alles, was über alle Schulen hinweg etwas in Ordnung bringen
    /// soll. [key] sieht immer nur nach dem gerade aktiven, und wer nur ihn
    /// repariert, lässt die anderen unverändert stehen.
    static func key(_ name: String, schoolId: String) -> String {
        guard schoolId != "default" else { return prefix + name }
        return prefix + "schools.\(schoolId).\(name)"
    }

    // -------------------------------------------------------------- Schreiben

    static func setString(_ value: String, for name: String) {
        defaults.set(value, forKey: key(name))
    }

    static func setBool(_ value: Bool, for name: String) {
        defaults.set(value, forKey: key(name))
    }

    /// Wie [setBool], aber für einen bestimmten Schulbereich.
    static func setBool(_ value: Bool, for name: String, schoolId: String) {
        defaults.set(value, forKey: key(name, schoolId: schoolId))
    }

    static func setActiveSchool(_ schoolId: String) {
        defaults.set(schoolId, forKey: key("activeSchoolId"))
    }

    // -------------------------------------------------------- Benachrichtigungen

    /// Es hat sich eine **Darstellungs**-einstellung geändert.
    ///
    /// Gesendet von den nativen Bildschirmen und von `NativeShellBridge`, wenn
    /// die Änderung aus Flutter kam – in beide Richtungen, damit es nur einen
    /// Weg gibt und nicht zwei, die man sich merken müsste.
    static let settingsDidChange = Notification.Name("AppStore.settingsDidChange")

    /// Der Eintrag für Sync & Teilen soll in der Leiste stehen oder verschwinden.
    ///
    /// Ein eigener Name und nicht [settingsDidChange]: Die Leiste muss den
    /// Eintrag **entfernen** und nicht nur neu einfärben. Das ist eine andere
    /// Arbeit, und sie soll nicht bei jeder Hell-Dunkel-Umstellung mitlaufen.
    static let syncTabDidChange = Notification.Name("AppStore.syncTabDidChange")

    /// Es wurde ein anderer Schulbereich gewählt.
    ///
    /// Danach muss die Leiste ihren Abschnitt neu aufbauen: Die alten Werte
    /// gehören zum vorherigen Bereich, und sie still weiterzuzeigen hieße, das
    /// Falsche zu zeigen.
    static let activeSchoolDidChange = Notification.Name(
        "AppStore.activeSchoolDidChange")

    // --------------------------------------------------------------- Lesen

    static func string(_ name: String) -> String? {
        defaults.string(forKey: key(name))
    }

    static func bool(_ name: String) -> Bool? {
        guard let value = defaults.object(forKey: key(name)) as? NSNumber else {
            return nil
        }
        return value.boolValue
    }

    static func bool(_ name: String, schoolId: String) -> Bool? {
        guard let value = defaults.object(forKey: key(name, schoolId: schoolId))
            as? NSNumber
        else { return nil }
        return value.boolValue
    }

    // ------------------------------------------------------------ Darstellung

    /// Die gespeicherte Helligkeit: `dark` oder `light`.
    ///
    /// **Dunkel ist der Standard**, und das ist Absicht: So sah die App aus,
    /// bevor es diese Einstellung gab. Wer sie zum ersten Mal öffnet, bekommt
    /// das gewohnte Bild – und nicht ein helles, das er nie gesehen hat.
    static var theme: AppearanceTheme {
        switch string(AppAppearanceKeys.theme) {
        case AppAppearanceTheme.light: return .light
        default: return .dark
        }
    }

    static func setTheme(_ value: AppearanceTheme) {
        setString(value.rawValue, for: AppAppearanceKeys.theme)
    }

    /// Steht der Eintrag für Sync & Teilen in der Leiste?
    ///
    /// `true`, solange nichts eingestellt ist: Die drei Funktionen gehören zu
    /// den wenigen, für die man die App braucht. Wer sie nicht braucht,
    /// schaltet sie ab – dann verschwindet der Eintrag, die Funktionen selbst
    /// bleiben aber erreichbar.
    static var showsSyncShareTab: Bool {
        bool(AppAppearanceKeys.showSyncShareTab) ?? true
    }

    static func setShowsSyncShareTab(_ value: Bool) {
        setBool(value, for: AppAppearanceKeys.showSyncShareTab)
    }

    /// Zeigt ein Klick auf eine Klasse die ganze Woche statt eines Tages?
    static var showsWeekView: Bool {
        bool(AppAppearanceKeys.showWeekView) ?? false
    }

    static func setShowsWeekView(_ value: Bool) {
        setBool(value, for: AppAppearanceKeys.showWeekView)
    }

    /// Wird die ganze Woche gezeigt? – als Zahl, für den gleichnamigen Wert in
    /// den Flutter-Bildschirmen.
    static var hidesLessonTimes: Bool {
        bool(AppAppearanceKeys.hideLessonTimes) ?? false
    }

    // -------------------------------------------------------------- Sprache

    /// Die eingestellte Sprache: `system`, `de` oder `en`.
    ///
    /// **`system` ist der Standard**, und der ist nicht beliebig: Die App folgt
    /// dann der Sprache des Geräts – auch dann noch, wenn sie dort später
    /// umgestellt wird. Wer stattdessen `de` speichert, hat ausdrücklich Deutsch
    /// gewählt.
    static var language: AppLanguageChoice {
        let stored = string(AppLanguageKeys.code) ?? AppLanguageChoice.system.rawValue
        if stored == AppLanguageChoice.system.rawValue { return .system }
        if stored == "de" { return .deutsch }
        if stored == "en" { return .english }
        // Ein unerwarteter Wert fällt auf die Systemsprache zurück – nicht auf
        // eine Sprache, die es vielleicht gar nicht gibt.
        return .system
    }

    static func setLanguage(_ value: AppLanguageChoice) {
        setString(value.rawValue, for: AppLanguageKeys.code)
    }

    // ------------------------------------------------------------- Schulnamen

    /// Die angelegten Schulbereiche, in der Reihenfolge, in der sie
    /// gespeichert wurden.
    ///
    /// Gelesen wird derselbe JSON-Text, den `SchoolStorage` schreibt. Ein
    /// beschädigter Text liefert **keine** Profile statt erfundener – eine
    /// leere Liste zeigt das als "keine Schulen", und das ist ehrlicher als ein
    /// Bereich, den es nicht gibt.
    static func schoolProfiles() -> [SchoolProfile] {
        guard let raw = string("schoolProfiles"),
              let data = raw.data(using: .utf8)
        else { return [] }
        guard let entries = try? JSONSerialization.jsonObject(with: data)
            as? [[String: Any]]
        else { return [] }

        return entries.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let name = entry["name"] as? String ?? "Meine Schule"
            return SchoolProfile(id: id, name: name)
        }
    }

    static func saveSchoolProfiles(_ profiles: [SchoolProfile]) {
        let encoded = profiles.map { ["id": $0.id, "name": $0.name] }
        guard let data = try? JSONSerialization.data(withJSONObject: encoded),
              let text = String(data: data, encoding: .utf8)
        else { return }
        setString(text, for: "schoolProfiles")
    }

    static func addSchool(named name: String) -> SchoolProfile {
        var profiles = schoolProfiles()
        // Der Name ist ein Datum aus der aktuellen Zeit – dieselbe Idee wie in
        // `SchoolStorage.addSchool`, aber in der Länge, die `UserDefaults`
        // verträgt. Er muss nur eindeutig sein.
        let id = String(Int(Date().timeIntervalSince1970 * 1000))
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = SchoolProfile(
            id: id, name: trimmed.isEmpty ? "Neue Schule" : trimmed)
        profiles.append(profile)
        saveSchoolProfiles(profiles)
        return profile
    }

    static func renameSchool(_ id: String, to name: String) {
        var profiles = schoolProfiles()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles = profiles.map { profile in
            guard profile.id == id else { return profile }
            return SchoolProfile(
                id: profile.id, name: trimmed.isEmpty ? profile.name : trimmed)
        }
        saveSchoolProfiles(profiles)
    }

    static func deleteSchool(_ id: String) {
        // Die erste Schule bleibt: Sie ist der Anker, an dem die Werte hängen,
        // die noch kein `schools.`-Vorspann tragen.
        guard id != "default" else { return }
        var profiles = schoolProfiles().filter { $0.id != id }
        // Die letzte Schule zu löschen würde die Auswahl ins Leere zeigen
        // lassen, ohne dass klar wäre, warum.
        guard !profiles.isEmpty else { return }
        saveSchoolProfiles(profiles)
        if activeSchoolId == id {
            setActiveSchool(profiles[0].id)
        }
    }

    // ------------------------------------------------------- Anmeldedaten

    /// Gibt es für den aktiven Bereich hinterlegte Zugangsdaten?
    ///
    /// Nur der Benutzername zählt: Ein leeres Feld ist dasselbe wie keins, und
    /// ein Passwort ohne Benutzername ergibt ohnehin keinen Zugriff.
    static var hasCredentials: Bool {
        guard let username = string("vplanUsername") else { return false }
        return !username.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}

/// Ein angelegter Schulbereich.
///
/// Entspricht `SchoolProfile` in `SchoolStorage.dart` – gleiche zwei Felder,
/// gleiche Bedeutung.
struct SchoolProfile {
    let id: String
    let name: String
}

/// Die Schlüssel der Darstellungseinstellungen.
///
/// Ausgeschrieben statt in `AppAppearance` nachgeschlagen, weil Swift die
/// Dart-Klasse nicht kennt. Sie stehen hier so, wie sie dort heißen – und der
/// Test `AppStore` schlägt fehl, wenn jemand nur eine Seite ändert.
enum AppAppearanceKeys {
    static let theme = "appearance.theme"
    static let showSyncShareTab = "appearance.showSyncShareTab"
    static let showWeekView = "showWeekView"
    static let hideLessonTimes = "hideLessonTimes"
}

/// Die Schlüssel der Sprache – siehe [AppAppearanceKeys].
enum AppLanguageKeys {
    static let code = "languageCode"
}