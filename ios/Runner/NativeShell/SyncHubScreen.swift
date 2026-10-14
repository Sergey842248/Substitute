import UIKit

/// „Sync & Teilen" – die drei Wege, auf denen Daten zwischen Geräten und
/// Menschen wandern.
///
/// ## Warum diese Seite nativ ist und der Rest davon nicht
///
/// Sie besteht aus **drei Zeilen**, die alle dasselbe tun: einen Bildschirm in
/// Flutter öffnen. Die eigentliche Arbeit – der Abgleich mit anderen Geräten,
/// das Verschlüsseln, das Kodieren und Dekodieren der Angebote – liegt in
/// `ShareManager`, `SyncEngine` und `SyncKeys`, und die bleiben dort.
///
/// Der Bildschirm ist also genau das, wofür sich ein nativer Bildschirm lohnt:
/// er liest drei Werte und tut dreimal dasselbe. Das gilt für die
/// Einstellungsseiten genauso, aus demselben Grund.
///
/// ## Was an ihre Stelle getreten ist
///
/// `SyncShareHub` war eine Liste aus `ListItem` mit je einem Knopf am Rand, der
/// dieselbe Aktion ausführte wie die Zeile selbst – zweimal derselbe Weg pro
/// Eintrag, und nichts sagte, welcher davon der eigentliche ist. In iOS ist die
/// ganze Zeile der Weg, und rechts steht ein **Pfeil**, der genau das sagt.
///
/// ## Warum die Texte aus Dart kommen
///
/// „Synchronisieren", „Teilen", „Angebote durchsuchen" sind übersetzbar, und die
/// Übersetzung steht in `app_localizations_de.dart`. Sie hier zu wiederholen
/// hieße, dieselben Wörter an zwei Orten zu pflegen – und die beiden würden
/// irgendwann auseinanderlaufen, in genau der einen Sprache, in der jemand
/// anderes als der Autor sie benutzt.
///
/// Dart schickt deshalb den Text mit, und diese Seite sucht **nur** das
/// Zeichen dazu aus. Das Zeichen ist eine Frage des Aussehens, und das Aussehen
/// ist Sache der nativen Seite.
final class SyncHubScreen: ListScreen {

    init() {
        super.init(title: L.syncShare, largeTitle: true)
        navigationItem.leftBarButtonItem = LogoBarButton.make(
            target: self, action: #selector(heimGetippt))
    }

    /// Der Bildschirm, dessen Werte hier gezeichnet werden – siehe
    /// `PlanOverviewScreen.datenQuelle`.
    override var datenQuelle: ScreenBridge.Screen? { .sync }

    override func makeSections() -> [Section] {
        let eintraege = (ScreenBridge.stand(.sync) ?? [:]).eintraege

        guard !eintraege.isEmpty else {
            // Noch nichts gekommen. Das ist **kein** Fehlerbild, sondern der
            // Zustand vor dem ersten `publish` – und deshalb steht hier eine
            // Zeile mit Text und kein „nichts gefunden".
            return [Section(header: nil, footer: nil, rows: [
                .text(title: L.loading, subtitle: nil, symbol: "hourglass")
            ])]
        }

        return [
            Section(header: L.syncShare, footer: L.syncShareSubtitle, rows: eintraege.map(zeile))
        ]
    }

    /// Baut aus einem Eintrag aus Dart eine Zeile.
    private func zeile(_ eintrag: [String: Any]) -> Row {
        let id = (eintrag["id"] as? String) ?? ""
        let titel = (eintrag["title"] as? String) ?? ""
        let untertitel = eintrag["subtitle"] as? String

        // Das Zeichen kommt **hier** her und nicht aus Dart.
        //
        // Es ist eine Frage des Aussehens, und das Aussehen ist hier. Dart
        // müsste dafür die Namen der SF Symbols mitgeben – also wüsste die
        // Dart-Seite, welche Symbole es auf der nativen Seite gibt, und jede neue
        // iOS-Version, die eines umbenennt, wäre ein Fehler auf **dieser** Seite.
        //
        // Eine fremde Kennung liefert einen **leeren** Namen, und `UIImage`
        // gibt dafür `nil` zurück. Die Zeile bleibt dadurch lesbar und zeigt nur
        // nichts links – statt sich aufzulösen oder ein falsches Zeichen zu
        // behaupten.
        let symbol = Self.symbolFuer(id)

        return .choice(
            title: titel, subtitle: untertitel, symbol: symbol,
            action: {
                guard let weg = wegZu(id) else { return }
                SyncRoute.present(weg, from: self.navigationController)
            }
        )
    }

    /// Der Weg, der zu einem Eintrag gehört.
    ///
    /// `nil` heisst: Dart hat einen Eintrag geschickt, zu dem hier **kein** Weg
    /// bekannt ist – etwa weil eine neuere Dart-Seite eine neue Zeile bringt.
    ///
    /// Es ist **kein** Fehler und wird auch nicht als einer gemeldet. Es ist die
    /// Folge davon, dass die Wege hier feststehen und nicht aus Dart kommen: Eine
    /// neue Zeile aus Dart braucht hier einen neuen Fall, und bis dahin führt
    /// sie nirgendwohin – was sichtbar ist und sich nicht als Absturz tarnt.
    private func wegZu(_ id: String) -> SyncRoute? {
        // Die Kennungen stehen hier als **Wörter** und nicht über
        // `SyncRoute.<fall>.id`. Sie tun dasselbe, aber `case` vergleicht mit
        // einem Muster, und ein ausgerechneter Wert ist kein solches – der
        // Compiler kann dann nichts prüfen, und ein Tippfehler bliebe still.
        //
        // Dasselbe gilt für `symbolFuer`. Beide Stellen stehen nebeneinander,
        // damit klar ist, dass sie dieselbe Menge kennen – und eine neue Zeile
        // aus Dart an beiden zu ergänzen ist.
        switch id {
        case "sync": return .sync
        case "share": return .share
        case "browse": return .browse
        default: return nil
        }
    }

    /// Das Zeichen zu einem Eintrag.
    ///
    /// ## Warum hier ein `switch` und keine Liste
    ///
    /// Weil die Zuordnung **Absicht** ist, und nicht etwas, was sich ergibt: Der
    /// Eintrag „Teilen" ist etwas anderes als „Synchronisieren", und der Leser
    /// soll den Unterschied vor dem Tippen sehen. Ein `switch` sagt das an einer
    /// Stelle – und ein fehlender Fall fällt beim Übersetzen sofort auf, statt
    /// still ein falsches Symbol zu zeigen.
    ///
    /// Sollte Dart einmal einen Eintrag schicken, für den es hier keinen Fall
    /// gibt, wird **kein** Symbol erfunden. Eine Zeile ohne Zeichen ist
    /// unauffällig; eine mit dem falschen Zeichen behauptet etwas Falsches.
    private static func symbolFuer(_ id: String) -> String {
        switch id {
        case "sync": return "arrow.triangle.2.circlepath"
        case "share": return "person.2"
        case "browse": return "safari"
        default: return ""
        }
    }

    @objc private func heimGetippt() {
        let heim = HomeScreen()
        navigationController?.pushViewController(heim, animated: true)
    }
}