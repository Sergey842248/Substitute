import UIKit

/// Die Seite, auf der ein QR-Code steht.
///
/// Sie macht aus einem Text ein Bild, legt es in einen weißen Rahmen und
/// bietet es über das Teilen-Menü an. Der Rahmen ist **nicht** die Seite selbst:
/// Sie trägt die Farben der App, der Rahmen die des Codes – siehe [QRCodeView].
///
/// ## Warum „Teilen" ein Knopf ist und nicht ein Menü neben „Fertig"
///
/// `UIBarButtonItem` hat rechts oben Platz für zwei. Auf dieser Seite ist der
/// eine „Fertig" – denn man kommt hierher, um etwas mitzunehmen, nicht um hier
/// zu bleiben – und der andere das Teilen. Andersherum würde man die Seite
/// verlassen, ohne sie zu schließen, und wüsste nicht, wie man zurückkommt.
final class QRCodeScreen: UIViewController {
    private let codeView = QRCodeView()
    private let erklaerung = UILabel()

    /// Der Inhalt, aus dem der Code entsteht.
    private let inhalt: String

    init(titel: String, inhalt: String) {
        self.inhalt = inhalt
        super.init(nibName: nil, bundle: nil)
        self.title = titel
        // Grosse Titel nur auf der ersten Seite einer Reihe: Auf dem Weg nach
        // unten schrumpfen sie ohnehin, und zwei hintereinander wirkende grosse
        // Titel sind eines zu viel.
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        codeView.setzeCode(QRCode.bild(aus: inhalt))
        codeView.translatesAutoresizingMaskIntoConstraints = false

        erklaerung.text = L.credsQrHint
        erklaerung.font = .preferredFont(forTextStyle: .footnote)
        erklaerung.adjustsFontForContentSizeCategory = true
        erklaerung.textColor = .secondaryLabel
        erklaerung.numberOfLines = 0
        erklaerung.textAlignment = .center

        let stapel = UIStackView(arrangedSubviews: [codeView, erklaerung])
        stapel.axis = .vertical
        stapel.spacing = 16
        stapel.alignment = .fill
        stapel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stapel)

        NSLayoutConstraint.activate([
            stapel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stapel.leadingAnchor.constraint(
                equalTo: view.layoutMarginsGuide.leadingAnchor),
            stapel.trailingAnchor.constraint(
                equalTo: view.layoutMarginsGuide.trailingAnchor),
            codeView.heightAnchor.constraint(
                lessThanOrEqualTo: view.heightAnchor, multiplier: 0.55),
        ])

        // Der Code ist quadratisch: Seine Höhe folgt der Breite.
        //
        // Diese Vorgabe steht **nicht** bei den anderen, weil sie eine geringere
        // Priorität bekommt: Auf einem hohen, schmalen Gerät wäre ein Code in
        // voller Breite grösser als der Bildschirm. Zwei gleich wichtige
        // Vorgaben, die sich widersprechen, brechen den ganzen Aufbau – und die
        // Oberfläche wäre dann leer. Deshalb gewinnt die kleinere Grenze, und
        // die quadratische gilt nur, solange sie hineinpasst.
        let quadratisch = codeView.heightAnchor.constraint(
            equalTo: codeView.widthAnchor, constant: 0)
        quadratisch.priority = .defaultHigh
        quadratisch.isActive = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L.done, style: .done, target: self, action: #selector(schliessen))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L.share, style: .plain, target: self, action: #selector(teilen))
        navigationController?.navigationBar.tintColor = Appearance.accent
    }

    @objc private func schliessen() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func teilen() {
        guard let bild = QRCode.bild(aus: inhalt) else { return }
        // Der Bildschirm bleibt stehen, während das Teilen läuft: Ohne das
        // kehrte man beim Schliessen des Teilen-Blattes in eine leere Ansicht
        // zurück.
        let blatt = UIActivityViewController(
            activityItems: [bild], applicationActivities: nil)
        if let popper = blatt.popoverPresentationController {
            popper.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(blatt, animated: true)
    }
}