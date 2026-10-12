import UIKit

/// Hell oder dunkel.
///
/// Nur zwei Werte, **kein** „wie das Gerät": Flutter bietet dieselben zwei an
/// ([AppAppearance]), und ein dritter Wert hier würde einen Zustand erzeugen,
/// den die Flutter-Seite nicht kennt – sie fiele auf ihren eigenen Standard
/// zurück und die App sähe in zwei Helligkeiten gleichzeitig aus.
enum AppearanceTheme: String {
    case dark = "dark"
    case light = "light"
}

/// Die drei Sprachmöglichkeiten.
///
/// [system] ist nicht eine Sprache, sondern die **Abwesenheit** einer Festlegung
/// – deshalb steht es auch hier zwischen den beiden Sprachen und nicht als
/// weiterer Sprachcode: Wer `de` speichert, meint Deutsch; wer `system`
/// speichert, meint „das, was das Gerät sagt".
enum AppLanguageChoice: String {
    case system = "system"
    case deutsch = "de"
    case english = "en"
}

/// Die Helligkeit, die gerade gelten soll.
///
/// ## Warum die Ermittlung hier und nicht beim Lesen passiert
///
/// `Appearance` ist die **einzige** Stelle, die entscheidet, ob gerade hell
/// oder dunkel gilt. Jede Ansicht fragt hier und kommt nicht selbst zu einem
/// Ergebnis.
///
/// Das ist mehr als Sauberkeit. Eine Ansicht, die selbst entscheidet, kommt zu
/// einem Ergebnis, das von einer anderen Ansicht um einen Frame abweichen kann –
/// und zwei Helligkeiten nebeneinander sehen nach einem Fehler aus, sind aber
/// zwei korrekt gerechnete Antworten auf dieselbe Frage.
///
/// ## Nur zwei Werte, und **kein** „wie das Gerät"
///
/// Hell und dunkel sind alles, was es gibt. Flutter bietet dieselben zwei an
/// (`AppAppearance`), und ein dritter Wert hier erzeugte einen Zustand, den die
/// Flutter-Seite nicht kennt – sie fiele auf ihren eigenen Standard zurück, und
/// die App sähe in zwei Helligkeiten gleichzeitig aus.
enum Appearance {
    /// Die eingestellte Helligkeit – und weil es nur zwei gibt, zugleich die
    /// geltende. Der Name [current] meint also nichts anderes als [stored].
    static var current: AppearanceTheme { AppStore.theme }

    /// Das `UITraitCollection`, das zum gewählten Bild gehört.
    ///
    /// Für die **Ansicht**, nicht für die ganze App: Eine Flutter-Ansicht
    /// bringt ihr eigenes Bild mit, und würde man ihr stattdessen das System
    /// aufzwingen, sähe man beim Umschalten kurz die falsche Helligkeit.
    static var traitCollection: UITraitCollection {
        UITraitCollection(userInterfaceStyle: current == .dark ? .dark : .light)
    }

    /// Der Akzent, wie Flutter ihn wählt.
    ///
    /// **Dunkler im Hellen, nicht heller** – dieselbe Regel wie in `main.dart`,
    /// und aus demselben Grund: Der helle Akzent ist auf dunklem Grund gut
    /// lesbar und auf Weiß verschwindet er. Eine Umkehrung an dieser Stelle
    /// hieße, dass die native Leiste in einem Bild eine andere Farbe zeigt als
    /// die Seite, die sie gerade ansieht.
    static var accent: UIColor {
        current == .dark
            ? UIColor(red: 0xAF / 255, green: 0x69 / 255, blue: 0xEE / 255, alpha: 1)
            : UIColor(red: 0x7D / 255, green: 0x43 / 255, blue: 0xC4 / 255, alpha: 1)
    }

    /// Die Oberfläche der Leiste – die Karte, auf der die Einträge stehen.
    static var surface: UIColor { .secondarySystemBackground }

    /// Der Grund hinter allem.
    static var background: UIColor { .systemBackground }
}

/// Merkt, dass sich die Einstellung geändert hat.
///
/// ## Warum es einen Beobachter braucht
///
/// Die Änderung kommt von zwei Seiten: von den nativen Einstellungen und aus
/// den Flutter-Bildschirmen. Ohne eine Stelle, die beide beobachtet, würde die
/// Leiste nach einer Änderung **innerhalb** von Flutter ihre Farbe behalten –
///
/// weil Flutter seinen Wert schreibt und niemandem davon erzählt.
///
/// Der Zähler löst genau das: Wer schreibt, erhöht ihn, und alle Ansichten, die
/// sich dafür angemeldet haben, lesen ihn neu.
enum AppearanceObserver {
    private static var listeners: [UUID: () -> Void] = [:]

    /// Meldet jede Änderung der Darstellungseinstellungen.
    ///
    /// Die Rückgabe ist das **Abmelde-Teil** – ohne es bliebe der Zuhörer
    /// nach dem Bildschirm hängen, würde bei jedem Aufbau mitgezählt und
    /// irgendwann eine Bildschirm, der es nicht mehr gibt, aufrufen.
    @discardableResult
    static func observe(_ callback: @escaping () -> Void) -> UUID {
        let token = UUID()
        listeners[token] = callback
        return token
    }

    static func removeObserver(_ token: UUID) {
        listeners.removeValue(forKey: token)
    }

    /// Wird gerufen, nachdem eine Einstellung geschrieben wurde.
    static func settingsDidChange() {
        for callback in listeners.values { callback() }
    }

    /// Wird gerufen, wenn die **Systemeinstellung** sich ändert.
    ///
    /// Nur relevant, wenn die App dem Gerät folgt – siehe [Appearance.followsSystem].
    /// Auch dann aber nicht für den Akzent: Der wird aus der **eingestellten**
    /// Helligkeit gebildet, damit native Leiste und Flutter-Seite zusammen
    /// bleiben.
    static func systemInterfaceStyleDidChange() {
        settingsDidChange()
    }
}