import UIKit

/// Eine kurz auftauchende Bestätigung am unteren Rand.
///
/// ## Warum nicht `UIAlertController`
///
/// Ein Dialog mit einem Knopf **wartet**: Er bleibt stehen, bis jemand ihn
/// drückt, und der Bildschirm darunter kann nicht weiter. Für „Stundenzeiten
/// gelöscht" wäre das genau die falsche Sorte von Rückmeldung – man will weiter,
/// und nur wissen, dass es geklappt hat.
///
/// ## Warum nicht die Vibration von iOS
///
/// `UINotificationFeedbackGenerator` sagt dem **Finger**, dass etwas passiert ist
/// – es sagt nichts **auf dem Bildschirm**. Für Dinge, die man nicht bemerkt
/// haben muss, wäre das die richtige Wahl: die Berührung wird beantwortet.
///
/// Ein Hinweis wie „Einstellungen gelöscht" ist etwas anderes: Er berichtet
/// über etwas, das man **nicht** getippt hat, und das man bemerken soll, bevor
/// man weitergeht. Eine Vibration, die nebenbei ausgelöst wird, verschwindet
/// zwischen den nächsten Fingertipps – und gerade das Löschen aller Werte
/// sollte niemand überlesen.
enum Meldung {
    /// Zeigt [text] für eine kurze Zeit an.
    static func zeigen(_ text: String, in view: UIView) {
        guard !text.isEmpty else { return }

        let etikett = UILabel()
        etikett.text = "  \(text)  "
        etikett.font = .preferredFont(forTextStyle: .footnote)
        etikett.adjustsFontForContentSizeCategory = true
        etikett.textColor = .white
        etikett.backgroundColor = UIColor.label.withAlphaComponent(0.85)
        etikett.textAlignment = .center
        etikett.numberOfLines = 0
        etikett.layer.cornerRadius = 8
        etikett.clipsToBounds = true
        etikett.alpha = 0
        etikett.translatesAutoresizingMaskIntoConstraints = false
        etikett.isUserInteractionEnabled = false

        view.addSubview(etikett)
        NSLayoutConstraint.activate([
            etikett.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // Nicht am unteren Rand: Dort liegt bei den meisten Bildschirmen die
            // Navigationsleiste, und der Hinweis verschwände unter ihr.
            etikett.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            etikett.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            etikett.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor, constant: -16),
        ])

        UIView.animate(withDuration: 0.18) { etikett.alpha = 1 }
        UIView.animate(
            withDuration: 0.25, delay: 1.6,
            options: [.curveEaseInOut]
        ) { etikett.alpha = 0 } completion: { _ in
            etikett.removeFromSuperview()
        }
    }
}

/// Bequemer Aufruf ohne Bildschirm im Weg.
extension UIViewController {
    /// Zeigt eine Bestätigung auf diesem Bildschirm.
    func melde(_ text: String) {
        Meldung.zeigen(text, in: view)
    }
}