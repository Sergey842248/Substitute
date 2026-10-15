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

    /// Der Schlüssel, unter dem der aktive Schulbereich steht.
    ///
    /// **Ohne** den Schulbereich einbezogen – und genau das ist hier der
    /// wichtigste Satz dieser Datei.
    ///
    /// Dieser Wert **sagt**, welcher Schulbereich gilt. Er kann deshalb nicht
    /// selbst in einem Schlüssel stehen, der den Schulbereich einbezieht: Um
    /// ihn zu lesen, müsste man ihn zuerst wissen.
    ///
    /// Das ist keine Feinheit, sondern ein Absturz: Ein `key("activeSchoolId")`
    /// hier drin – also [key] – rief wiederum `activeSchoolId` auf, und das
    /// wiederum [key]. Endlose Wiederholung, Stapelüberlauf, und die App stürzte
    /// **beim Start** ab, noch bevor ein Bild gezeichnet war. Das ist auf iOS
    /// geschehen und auf Android nicht, weil dort nur Dart läuft und Dart
    /// denselben Fehler nicht macht.
    ///
    /// `SchoolStorage` schreibt ihn aus demselben Grund ohne Vorspann: siehe
    /// `_activeSchoolKey` dort.
    private static let activeSchoolKey = "activeSchoolId"

    /// Die Kennung des Schulbereichs, für den gerade gespeichert wird.
    ///
    /// Für die erste Schule ist das `default`, und dann tragen die Schlüssel
    /// **keinen** Vorspann. Das ist keine Vereinfachung, sondern dieselbe
    /// Regel wie in `SchoolStorage.scopedKey`: Eine bestehende Installation hat
    /// ihre Werte ohne Vorspann, und mit einem Vorspann geschrieben, wären sie
    /// unsichtbar – die App erschiene frisch installiert.
    static var activeSchoolId: String {
        defaults.string(forKey: prefix + activeSchoolKey) ?? "default"
    }

    /// Der Schlüssel einer Einstellung, so wie Flutter sie schreibt.
    ///
    /// Hier wird der Schulbereich einbezogen. **Nur** für Werte, die einem
    /// Bereich gehören – für den Bereich selbst nimmt man [activeSchoolKey].
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

    /// Wird ein anderer Schulbereich verwendet, gilt er ab sofort – für beide
    /// Seiten.
    ///
    /// ## Warum hier [didWrite] steht
    ///
    /// Ein Schulwechsel ändert, was **alles** bedeutet: die Leiste (hat der
    /// neue Bereich Zugangsdaten?), die Listen in den Einstellungen und der
    /// Inhalt jedes Flutter-Abschnitts. Ohne diese Meldung bliebe die Leiste so,
    /// wie sie war, und die Abschnitte zeigten weiter die Daten der alten Schule –
    /// bis zum nächsten Neustart.
    static func setActiveSchool(_ schoolId: String) {
        // Siehe [activeSchoolKey]: Auch beim Schreiben **ohne** den
        // Schulbereich einbezogen. Über [key] ginge es nicht – der Aufruf
        // müsste erst den Bereich lesen, den man gerade setzt.
        defaults.set(schoolId, forKey: prefix + activeSchoolKey)
        didWrite()
    }

    /// Entfernt einen Wert ganz – statt ihn auf einen Leerwert zu setzen.
    ///
    /// Nötig, weil „nicht gesetzt" und „leer" für `shared_preferences` zwei
    /// verschiedene Dinge sind: `getBool` gibt bei einem gespeicherten `false`
    /// `false` zurück, bei einem **fehlenden** Schlüssel `null`. Wer statt des
    /// Entfernens `false` schriebe, könnte den Unterschied zwischen „nie
    /// eingestellt" und „eingestellt und aus" nicht mehr unterscheiden – und
    /// genau den unterscheidet die Dart-Seite bei mehreren Werten.
    static func remove(_ name: String) {
        defaults.removeObject(forKey: key(name))
    }

    // -------------------------------------------- Schlüssel **ohne** Bereich

    /// Der Schlüssel eines Wertes, der **keinem** Schulbereich gehört.
    ///
    /// ## Warum es das überhaupt gibt
    ///
    /// Der weitaus größte Teil der Einstellungen gehört zur aktiven Schule –
    /// zwei Schulen auf demselben Gerät haben verschiedene Stundenzeiten.
    /// Einige Werte sind aber **gerätelokal** und für alle Bereiche gleich:
    /// etwa „zusätzliche Sync-Anzeigen", das eine Frage dieser Bildschirme ist
    /// und keine Eigenschaft der Kette.
    ///
    /// Diese Werte stehen in Dart **ohne** `scopedKey` – siehe
    /// `SyncEngine.showDetailsStorageKey` und `DeveloperOptions.dart`. Würde man
    /// sie hier über [key] schreiben, bekämen sie einen `schools.`-Vorspann,
    /// den Dart nicht erwartet: Die native Seite zeigte den Wert, die
    /// Flutter-Seite nicht, und beide hätten für sich recht.
    ///
    /// Sie stehen deshalb bewusst **getrennt** von [key] – damit man beim
    /// Lesen sofort sieht, womit man es zu tun hat.
    static func plainKey(_ name: String) -> String { prefix + name }

    static func plainString(_ name: String) -> String? {
        defaults.string(forKey: plainKey(name))
    }

    static func setPlainString(_ value: String, for name: String) {
        defaults.set(value, forKey: plainKey(name))
    }

    static func plainBool(_ name: String) -> Bool? {
        guard let value = defaults.object(forKey: plainKey(name)) as? NSNumber
        else { return nil }
        return value.boolValue
    }

    static func setPlainBool(_ value: Bool, for name: String) {
        defaults.set(value, forKey: plainKey(name))
    }

    /// Entfernt **alle** Werte der App – wie `SharedPreferences.clear()` in Dart.
    ///
    /// Es werden nur die Schlüssel mit dem `flutter.`-Vorsatz entfernt:
    /// `UserDefaults.standard` gehört der App, aber nicht **für** die App.
    /// Andere Rahmen – die Flutter-Maschine, Hilfswerkzeuge von iOS – legen
    /// dort eigene Werte ab, und die zu löschen wäre ein Fehler, der nichts mit
    /// „alle Einstellungen zurücksetzen" zu tun hat.
    static func removeAll() {
        // `dictionaryRepresentation()` liefert eine **Kopie**. Zu löschen, während
        // man ihre Schlüssel durchläuft, wäre deshalb gefahrlos – aber die
        // Schlüssel werden hier bewusst erst eingesammelt: Das bleibt auch dann
        // richtig, wenn sich das Verhalten von `UserDefaults` ändert.
        let zuEntfernen = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix)
        }
        for name in zuEntfernen {
            defaults.removeObject(forKey: name)
        }
    }

    // ---------------------------------------------------------- Rohwerte
    //
    // Alles, was **ohne** Namen des Schulbereichs gebraucht wird: der
    // Sicherungs-Bildschirm liest und schreibt die ganze Ablage auf einmal,
    // und weiss dabei nicht im Voraus, welche Schlüssel darin liegen.

    /// Die Schlüssel, unter denen **alle** Werte der App liegen.
    ///
    /// ## Warum die Namen hier schon fertig sind
    ///
    /// Diese Methode hängt den Schulbereich **nicht** an – anders als [key].
    /// Sie liefert die Schlüssel so, wie sie in der Datei stehen, also mit dem
    /// `flutter.`-Vorsatz und **mit** dem `schools.<id>.`-Teil, falls es einen
    /// gibt.
    ///
    /// Genau das braucht die Sicherung: Sie nimmt **jeden** Wert der App mit,
    /// aus **jedem** Schulbereich. Wer hier [key] aufriefe, bekäme nur den
    /// gerade aktiven Bereich – und eine Sicherung, die den Namen einer
    /// anderen Schule mitnimmt, wäre wertlos.
    static func alleSchluessel() -> [String] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .sorted()
    }

    /// Alle Werte der App, mit ihren Schlüsseln.
    static func alleWerte() -> [String: Any] {
        var ergebnis: [String: Any] = [:]
        for name in alleSchluessel() {
            if let wert = defaults.object(forKey: name) { ergebnis[name] = wert }
        }
        return ergebnis
    }

    /// Schreibt einen Wert unter einem Schlüssel, der **schon fertig** ist.
    ///
    /// Das Gegenstück zu [alleSchluessel], nicht zu [setString]: Auch hier wird
    /// nichts ergänzt, weil der Aufrufer den Schlüssel aus einer Datei oder aus
    /// [alleSchluessel] hat und nicht weiß, zu welchem Bereich er gehört.
    static func setzeRoh(_ wert: Any, fuer name: String) {
        defaults.set(wert, forKey: name)
    }

    /// Entfernt einen Wert, dessen Schlüssel **schon fertig** ist.
    static func entferneRoh(_ name: String) {
        defaults.removeObject(forKey: name)
    }

    /// Das Datum als Text – so, wie Dart es schreibt.
    ///
    /// Siehe [datumFormatter]: Ohne Zeitzone und in lokaler Zeit, weil ein `Date`
    /// in Swift immer ein Zeitpunkt **mit** Ort ist und Dart einen solchen Wert
    /// nicht lesen könnte.
    static func isoText(_ datum: Date) -> String {
        datumFormatter.string(from: datum)
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
    ///
    /// ## Warum hier steht „was gespeichert ist", nicht „was folgt"
    ///
    /// [AppearanceTheme] kennt nur hell und dunkel, und diese Datei hält sich
    /// daran. Ein Wert, den es nicht gibt – etwa von einer Hand in den Speicher
    /// geschrieben –, ergibt deshalb `nil` und wird zu **dunkel**. Es gibt hier
    /// bewusst kein „wie das Gerät": Flutter bietet dieselben zwei an, und ein
    /// dritter Wert erzeugte einen Zustand, den die Flutter-Seite nicht kennt.
    static var theme: AppearanceTheme {
        guard let gespeichert = string(AppAppearanceKeys.theme) else {
            return .dark
        }
        return AppearanceTheme(rawValue: gespeichert) ?? .dark
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

    /// Steht unter einer Stunde keine Uhrzeit?
    ///
    /// ## Warum hier `true` und nicht `false`
    ///
    /// So sah der Plan aus, **bevor** es diese Einstellung gab: Die Zeiten
    /// waren ausgeblendet. Wer sie zum ersten Mal öffnet, bekommt deshalb das
    /// gewohnte Bild und nicht ein anderes.
    ///
    /// Es stand hier früher `false` und trug eine Beschreibung, die zu
    /// [showsWeekView] gehörte – beides zusammen hiess: derselbe Wert, aber je
    /// nach Seite ein anderer Vorgabewert. Dart liest `true` (`LessonInfoSettings`),
    /// und der Speicher hat nur **eine** Vorgabe; die native Seite nähme sich
    /// sonst die andere, und dieselbe Einstellung stünde auf demselben Gerät
    /// einmal hell und einmal dunkel.
    static var hidesLessonTimes: Bool {
        bool(AppAppearanceKeys.hideLessonTimes) ?? true
    }

    static func setHidesLessonTimes(_ value: Bool) {
        setBool(value, for: AppAppearanceKeys.hideLessonTimes)
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

    /// Der Schlüssel der Profilliste – und zwar **ohne** den Schulbereich.
    ///
    /// ## Warum ausgerechnet dieser Wert keinem Bereich gehört
    ///
    /// Die Profilliste **ist** die Liste aller Bereiche. Hinge sie an einem
    /// davon, wäre sie nur noch für **diesen einen** lesbar: Sobald eine zweite
    /// Schule aktiv wäre, suchte man sie unter `schools.<id>.schoolProfiles` –
    /// und fände dort nichts.
    ///
    /// Das ist keine theoretische Überlegung, sondern der gemeldete Fehler:
    /// Nach dem Anlegen einer Schule wurde diese sofort aktiv, und schon beim
    /// nächsten Aufbau der Liste suchte der Bildschirm nach einem Schlüssel,
    /// den niemand geschrieben hatte. Ergebnis: „Noch keine Schule angelegt",
    /// obwohl eben eine angelegt worden war – und eine zweite Schule war
    /// ebenfalls nicht anzulegen, weil das Anlegen in genau diese leere Liste
    /// schrieb und sie danach wieder verschwand.
    ///
    /// Dart schreibt denselben Text ohne Vorspann – siehe `_profilesKey` in
    /// `SchoolStorage.dart`. Siehe auch [plainKey].
    static let schoolProfilesKey = "schoolProfiles"

    /// Die angelegten Schulbereiche, in der Reihenfolge, in der sie
    /// gespeichert wurden.
    ///
    /// Gelesen wird derselbe JSON-Text, den `SchoolStorage` schreibt – und
    /// ausdrücklich **ohne** den Schulbereich, siehe [schoolProfilesKey]. Ein
    /// beschädigter Text liefert **keine** Profile statt erfundener – eine
    /// leere Liste zeigt das als "keine Schulen", und das ist ehrlicher als ein
    /// Bereich, den es nicht gibt.
    static func schoolProfiles() -> [SchoolProfile] {
        guard let raw = plainString(schoolProfilesKey),
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

    /// Schreibt die Profilliste zurück.
    ///
    /// Ohne [didWrite] – das ruft der Aufrufer am Ende seiner Änderung auf.
    /// Diese Funktion wird auch von [deleteSchool] benutzt, das danach noch den
    /// aktiven Bereich umsetzt; eine Meldung mitten drin würde die Leiste
    /// zweimal neu bauen.
    static func saveSchoolProfiles(_ profiles: [SchoolProfile]) {
        let encoded = profiles.map { ["id": $0.id, "name": $0.name] }
        guard let data = try? JSONSerialization.data(withJSONObject: encoded),
              let text = String(data: data, encoding: .utf8)
        else { return }
        setPlainString(text, for: schoolProfilesKey)
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
        didWrite()
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
        didWrite()
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
            // Ohne [didWrite] hier: Das Löschen meldet unten **einmal** – und
            // der aktive Bereich gehört zu derselben Änderung.
            defaults.set(profiles[0].id, forKey: prefix + activeSchoolKey)
        }
        didWrite()
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

    /// Die vier Felder der Anmeldung, wie sie gespeichert sind.
    ///
    /// Als ein Bündel und nicht als vier einzelne Zugriffe, weil sie immer
    /// gemeinsam gelesen und immer gemeinsam geschrieben werden: Es gibt keine
    /// Lage, in der nur drei davon gültig wären.
    struct Credentials {
        var schoolNumber = ""
        var username = ""
        var password = ""
        var customUrl = ""

        static func lesen() -> Credentials {
            Credentials(
                schoolNumber: string("vplanSchoolnumber") ?? "",
                username: string("vplanUsername") ?? "",
                password: string("vplanPassword") ?? "",
                customUrl: string("customUrl") ?? "")
        }

        /// Schreibt alle vier und sagt beiden Seiten Bescheid.
        ///
        /// Der Hinweis ist hier **nicht** optional: An dieser Stelle entscheidet
        /// sich, ob die Leiste überhaupt steht – sie erscheint mit dem ersten
        /// Benutzernamen, und ohne die Meldung bliebe sie bis zum nächsten Start
        /// weg. Siehe [hasCredentials].
        func schreiben() {
            setString(schoolNumber, for: "vplanSchoolnumber")
            setString(username, for: "vplanUsername")
            setString(password, for: "vplanPassword")
            setString(customUrl, for: "customUrl")
            didWrite()
        }
    }

    // ------------------------------------------- Angaben, die der Plan zeigt

    /// Steht unter einer Stunde kein Lehrername?
    static var hidesTeacher: Bool { bool("hideTeacher") ?? false }
    static func setHidesTeacher(_ value: Bool) {
        setBool(value, for: "hideTeacher")
    }

    /// Ist der Personenbereich ausgeblendet?
    static var hidesPersons: Bool { bool("hidePersons") ?? false }
    static func setHidesPersons(_ value: Bool) {
        setBool(value, for: "hidePersons")
    }

    /// Die einmalige Umstellung von „Personen ausblenden".
    ///
    /// Ältere Versionen hatten dort **aus** als Vorgabe. Einmal wird der alte
    /// Wert entfernt, damit die neue Vorgabe gilt – sonst hätte ein Gerät, das
    /// nie etwas eingestellt hat, auf ewig den alten Stand.
    ///
    /// Wird beim **Öffnen** der Seite gemacht und nicht beim Start der App: Es
    /// ist eine einmalige Sache, und sie gehört zu dem Bildschirm, der sie
    /// auslöst – nicht in den Start, der sie bei jedem Aufruf prüfen müsste.
    static func hidePersonsMigrationspruefung() {
        guard bool("hidePersonsMigrated") != true else { return }
        remove("hidePersons")
        setBool(true, for: "hidePersonsMigrated")
    }

    // ---------------------------------------------------- Die „Nächste Stunde"

    /// Steht die „Nächste Stunde"-Vorschau unter den Klassen?
    ///
    /// Bei Klassen standardmäßig **an**: Sie gehört dort zum Bild, das man
    /// vom Plan erwartet.
    static var hidesPreviewClasses: Bool { bool("hidePreviewClasses") ?? false }
    static func setHidesPreviewClasses(_ value: Bool) {
        setBool(value, for: "hidePreviewClasses")
    }

    /// Steht die Vorschau unter den Personen?
    ///
    /// Standardmäßig **aus**, und der Grund ist derselbe wie in Dart: Eine
    /// Person zeigt sonst sehr schnell nur noch die nächste Stunde des einen
    /// Kurses, den sie gerade ausgewählt hat – und die Liste der Personen
    /// verliert ihren eigentlichen Zweck.
    static var hidesPreviewPersons: Bool { bool("hidePreviewPersons") ?? true }
    static func setHidesPreviewPersons(_ value: Bool) {
        setBool(value, for: "hidePreviewPersons")
    }

    // ---------------------------------------------------------- Planmodi

    /// Der Standard-Planmodus – für **eine** der vier Gruppen.
    ///
    /// Der Name des Schlüssels steht hier, statt ihn an vier Aufrufstellen zu
    /// wiederholen: Es sind vier Zeilen, die sonst viermal dieselbe Frage
    /// beantworten müssten – und viermal unterschiedlich ausfallen könnten.
    enum PlanModeKey {
        case person
        case klasse
        case vorschauKlasse
        case vorschauPerson

        var name: String {
            switch self {
            case .person: return "defaultPlanModePerson"
            case .klasse: return "defaultPlanModeClass"
            case .vorschauKlasse: return "defaultPlanModePreviewClass"
            case .vorschauPerson: return "defaultPlanModePreviewPerson"
            }
        }

        /// Gilt für die beiden Vorschauen der alte gemeinsame Schlüssel?
        ///
        /// Vorher gab es nur einen Wert für beide. Wer ihn gesetzt hat, hat ihn
        /// auch heute noch – und soll ihn nicht verlieren, nur weil es inzwischen
        /// zwei getrennte gibt. Siehe `PlanModePreferences.read`.
        var nutztAltenWert: Bool {
            self == .vorschauKlasse || self == .vorschauPerson
        }
    }

    /// Der gespeicherte Standard-Planmodus einer Gruppe.
    static func planMode(_ key: PlanModeKey) -> PlanMode {
        if let raw = string(key.name), let modus = PlanMode(rawValue: raw) {
            return modus
        }
        if key.nutztAltenWert,
            let raw = string("defaultPlanModePreview"),
            let modus = PlanMode(rawValue: raw)
        {
            return modus
        }
        return .automatisch
    }

    static func setPlanMode(_ modus: PlanMode, for key: PlanModeKey) {
        setString(modus.rawValue, for: key.name)
    }

    // ------------------------------------------------------- Stundenzeiten

    /// Die festen Zeiten der einzelnen Unterrichtsstunden.
    ///
    /// Gespeichert wird derselbe JSON-Text, den `Lessons.dart` schreibt – sonst
    /// hätte man zwei Listen, und die des Geräts wäre nach einem Wechsel zur
    /// anderen Seite leer.
    static var lessons: [LessonTime] {
        guard let raw = string("lessontimes"),
            let daten = raw.data(using: .utf8),
            let eingelesen = try? JSONSerialization.jsonObject(
                with: daten) as? [[String: Any]]
        else { return [] }

        // Die Nummern werden beim Lesen **neu vergeben** und nicht gelesen:
        // Gespeichert ist zwar auch `count`, aber es ist eine Ableitung – sie
        // ergibt sich aus der Position. Ein Gerät, auf dem eine Lücke entstanden
        // ist (eine Stunde gelöscht), zeigte sonst zwei gleich nummerierte
        // Zeilen, und der Plan käme durcheinander.
        return eingelesen.enumerated().map { position, eintrag in
            LessonTime(
                count: position + 1,
                start: (eintrag["start"] as? String) ?? "",
                end: (eintrag["end"] as? String) ?? "")
        }
    }

    static func setLessons(_ liste: [LessonTime]) {
        let eingelesen = liste.enumerated().map { position, stunde in
            [
                "count": position + 1,
                "start": stunde.start,
                "end": stunde.end,
            ] as [String: Any]
        }
        // `[]` statt des Weglassens: So steht im Speicher ausdrücklich „keine
        // Zeiten" und nicht „noch nie eingestellt". Die Dart-Seite liest beides
        // gleich, aber der Unterschied taucht beim Export wieder auf.
        let text =
            (try? String(
                data: JSONSerialization.data(withJSONObject: eingelesen),
                encoding: .utf8)) ?? "[]"
        setString(text, for: "lessontimes")
    }

    // -------------------------------------------------------- Entwickler

    /// Zeigt die Sync-Seite ihre zusätzlichen Angaben?
    ///
    /// **Gerätelokal** und nicht vom Schulbereich abhängig – es ist eine Frage
    /// des Bildschirms auf **diesem** Gerät. Siehe [plainKey].
    static var showsSyncDetails: Bool {
        plainBool(AppDeviceKeys.showSyncDetails) ?? false
    }

    static func setShowsSyncDetails(_ value: Bool) {
        setPlainBool(value, for: AppDeviceKeys.showSyncDetails)
    }

    /// Die leere Liste der offline gespeicherten Pläne.
    static func removeOfflinePlans() {
        defaults.set([String](), forKey: key("offlineVPData"))
    }

    static func removeTeacherShorts() {
        setString("", for: "teacherShorts")
    }

    static func clearNewsFeeds() {
        setPlainString("[]", for: AppDeviceKeys.newsFeeds)
    }

    static func markFirstTimeSeen() {
        setPlainBool(true, for: AppDeviceKeys.firstTime)
    }

    static var materialYouEnabled: Bool {
        plainBool(AppDeviceKeys.materialYou) ?? false
    }

    static func setMaterialYouEnabled(_ value: Bool) {
        setPlainBool(value, for: AppDeviceKeys.materialYou)
    }

    /// Die überschriebene Uhrzeit – oder `nil`, wenn keine gesetzt ist.
    ///
    /// Gespeichert wird **derselbe Text**, den `AppClock.setOverriddenNow`
    /// schreibt: `DateTime.toIso8601String()` ohne Zeitzone, in **lokaler**
    /// Zeit. Ein `Date` in Swift ist dagegen immer ein Zeitpunkt mit Ort – wenn
    /// man ihn mit `ISO8601DateFormatter` schriebe, stünde hinten ein `Z`, und
    /// Dart würde daraus eine andere Stunde machen als gemeint.
    ///
    /// Siehe [AppStore.datumFormatter].
    static var overriddenNow: Date? {
        guard let raw = string("overriddenNow") else { return nil }
        return datumFormatter.date(from: raw)
    }

    static func setOverriddenNow(_ wert: Date?) {
        guard let wert else {
            remove("overriddenNow")
            return
        }
        setString(datumFormatter.string(from: wert), for: "overriddenNow")
    }

    /// Die Zeit, unter der die App gerade läuft.
    ///
    /// Dieselbe Frage wie `AppClock.now()`: Mit Überschreibung, sonst die
    /// wirkliche Uhr. Ohne das würde eine neu angelegte Stunde in den
    /// Entwickleroptionen eine echte anfangen statt der überschriebenen – und
    /// man würde die Wirkung der Überschreibung an der Stelle suchen, an der
    /// sie hingehört.
    static var aktuelleZeit: Date { overriddenNow ?? Date() }

    /// Das Format, in dem `overriddenNow` liegt.
    ///
    /// Feste Locale und **lokale** Zeit: `en_US_POSIX` verhindert, dass ein
    /// Gerät mit anderer Locale Ziffern anders schreibt, und die Uhrzone wird
    /// nicht mitgeschrieben – siehe [overriddenNow].
    private static let datumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    // ------------------------------------------------------ Benachrichtigen

    /// Sagt beiden Seiten, dass sich etwas geändert hat.
    ///
    /// ## Warum das nach **jedem** Schreiben aus der nativen Seite nötig ist
    ///
    /// Dart liest aus dem **Cache** von `SharedPreferences`, und der kennt nur,
    /// was Dart **selbst** geschrieben hat. Ein Wert, den diese Seite setzt,
    /// existiert für die Flutter-Seite erst dann, wenn der Cache neu gelesen
    /// wird – und der tut das nur, wenn er darauf hingewiesen wird.
    ///
    /// Ohne diesen Aufruf bliebe der alte Wert stehen, **ohne** dass irgendwo ein
    /// Fehler erschiene: Man hätte die Einstellung umgestellt, sie wäre aber
    /// nirgends in Wirkung getreten.
    ///
    /// `AppearanceBridge` hängt [appearanceChanged] an dieselbe Meldung, und
    /// darüber holt Dart seine Werte neu.
    static func didWrite() {
        AppearanceObserver.settingsDidChange()
        NotificationCenter.default.post(name: settingsDidChange, object: nil)
    }
}

/// Die drei festen Planmodi.
///
/// Dieselben drei Werte wie `PlanModePreferences` in Dart, und mit denselben
/// Zeichenketten: Der gespeicherte Text **ist** der Wert, und ein umbenanntes
/// `auto` hätte stille Fehler zur Folge – der Plan fiele auf seinen eigenen
/// Standard zurück, ohne dass jemand sähe, warum.
enum PlanMode: String {
    /// Heute – ausser der Schultag ist vorbei.
    ///
    /// Der Name ist nicht `auto`, obwohl der **Wert** `auto` ist: Der Wert ist
    /// das, was gespeichert wird und was Dart liest – der Name ist der, den
    /// Swift benutzt. Die beiden dürfen auseinanderfallen, sonst müsste man
    /// `PlanMode(rawValue: "automatisch")` schreiben, und Dart fände nichts.
    case automatisch = "auto"
    /// Immer den neuesten verfügbaren Plan.
    case latest
    /// Immer nur den heutigen.
    case today
}

/// Eine festgelegte Unterrichtszeit.
///
/// Entspricht einem Eintrag in `lessons` in `Lessons.dart`: Nummer, Beginn und
/// Ende. Die Nummer wird beim Schreiben neu vergeben – siehe [AppStore.lessons].
struct LessonTime {
    var count = 0
    var start = ""
    var end = ""

    /// Die beiden Zeiten als Text, wie sie gespeichert werden: `HH:mm`.
    ///
    /// Auf englische Art zusammengesetzt und **nicht** mit `DateFormatter`:
    /// Eine Formatierung nach der eingestellten Sprache ergäbe in manchen
    /// Gebieten `08 Uhr 00`, und das wäre kein Wert mehr, den Dart lesen kann.
    static func zeit(_ components: DateComponents) -> String {
        String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    /// Die beiden Zeiten aus Text lesen.
    ///
    /// Ein Text, der nichts Brauchbares enthält, ergibt `0:00` und keine
    /// Ausnahme: Der Wert steht in einer gespeicherten Liste, die ein Downgrade
    /// oder ein Import mit einem anderen Format hinterlassen haben kann – und
    /// eine leere Zeile ist ein Fehler, den man sieht. Eine Abstürzung wäre es
    /// nicht.
    static func components(aus text: String) -> DateComponents {
        let teile = text.split(separator: ":", omittingEmptySubsequences: false)
        let stunde = teile.count > 0 ? Int(teile[0].trimmingCharacters(in: .whitespaces)) : nil
        let minute = teile.count > 1 ? Int(teile[1].trimmingCharacters(in: .whitespaces)) : nil
        guard let stunde, let minute,
            (0...23).contains(stunde), (0...59).contains(minute)
        else { return DateComponents(hour: 0, minute: 0) }
        return DateComponents(hour: stunde, minute: minute)
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

/// Die Schlüssel, die **keinem** Schulbereich gehören.
///
/// Aus demselben Grund wie [AppAppearanceKeys] hier ausgeschrieben: Swift
/// kennt die Dart-Seite nicht, und ein Schlüssel, den es auf **beiden** Seiten
/// gibt, steht in beiden ausgeschrieben – damit man ihn beim Ändern nur an
/// **einer** Stelle suchen muss und nicht an zwei.
///
/// Zugriff läuft über [AppStore.plainKey] und nicht über [AppStore.key]:
/// Letzterer hängt den Schulbereich an, und diese Werte haben keinen.
enum AppDeviceKeys {
    static let showSyncDetails = "sync.showDetails"
    static let newsFeeds = "newsfeeds"
    static let materialYou = "materialyou"
    static let firstTime = "firstTime"
}