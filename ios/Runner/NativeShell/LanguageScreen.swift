import UIKit

/// Die Sprachauswahl.
///
/// Drei Möglichkeiten, und die dritte ist die wichtigste: **der Systemsprache
/// folgen**. Sie steht deshalb oben – wer nichts tut, bekommt die Sprache
/// seines Handys, und zwar auch dann noch, wenn er sie am Gerät später
/// umstellt.
///
/// Ist die Systemsprache eine, für die es keine Übersetzung gibt, nimmt die App
/// Deutsch. Nicht Englisch, und nicht „nichts anzeigen": Sie kann nur auf
/// Deutsch und Englisch.
final class LanguageScreen: ListScreen {
    init() {
        super.init(title: L.language)
    }

    override func makeSections() -> [Section] {
        let gewaehlt = AppStore.language
        return [
            Section(
                rows: [
                    .choice(
                        title: L.languageSystem,
                        subtitle: L.languageSystemSubtitle,
                        symbol: "globe",
                        accessory: gewaehlt == .system ? .checkmark : .none
                    ) { self.wahl(.system) },
                    .choice(
                        title: "Deutsch",
                        subtitle: L.languageGermanSubtitle,
                        symbol: "textformat.abc",
                        accessory: gewaehlt == .deutsch ? .checkmark : .none
                    ) { self.wahl(.deutsch) },
                    .choice(
                        title: "English",
                        subtitle: L.languageEnglishSubtitle,
                        symbol: "textformat",
                        accessory: gewaehlt == .english ? .checkmark : .none
                    ) { self.wahl(.english) },
                ])
        ]
    }

    /// Speichert die Wahl und sagt beiden Seiten Bescheid.
    ///
    /// Der Weg nach **Flutter** ist derselbe wie in [AppearanceScreen.speichern]
    /// und aus demselben Grund: Flutter merkt sich nur, was es selbst
    /// geschrieben hat, und der Wert kam von der anderen Seite.
    private func wahl(_ choice: AppLanguageChoice) {
        AppStore.setLanguage(choice)
        neuLaden()
        //// Siehe [AppStore.didWrite]didWrite] –– und aus demselben Grund wie in
        // [AppearanceScreen.speichern].
        AppStore.didWrite(und aus demselben Grund wie in
        // [AppearanceScreen.speichern].
        AppStore.didWrite()
    }
}