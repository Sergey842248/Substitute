import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Das Erzeugen und Anzeigen von QR-Codes.
///
/// ## Warum `CoreImage` und nicht ein Bild aus dem Netz
///
/// Weil der Code **aus Daten dieser App** besteht – Zugangsdaten, die auf
/// keinem Server liegen. Er wird nicht geholt, sondern hier und jetzt aus dem
/// gebaut, was gespeichert ist.
enum QRCode {
    /// Die Fehlerkorrektur.
    ///
    /// Wie hoch sie sein muss, hängt davon ab, wie viel daneben liegt: Ein Logo
    /// in der Mitte verdeckt ein gutes Drittel der Fläche, und das muss die
    /// Fehlerkorrektur noch auffangen können. Deshalb steht hier `H` – dieselbe
    /// Stufe wie in `VPlanLogin.dart`.
    enum Korrektur: String {
        case niedrig = "L"
        case mittel = "M"
        case hoch = "H"
    }

    private static let contexto: CIContext = {
        // Ohne einen eigenen Kontext würde CoreImage bei jedem Bild einen neuen
        // anlegen – das ist bei etwas, das nur beim Öffnen einmal passiert,
        // nicht schlimm, aber an zwei Stellen im Bildschirm wäre es doppelt.
        CIContext(options: [.useSoftwareRenderer: false])
    }()

    /// Baut den Code als Bild. `nil`, wenn der Text leer ist.
    static func bild(
        aus text: String,
        groesse: CGFloat = 600,
        korrektur: Korrektur = .hoch
    ) -> UIImage? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = korrektur.rawValue
        guard let ergebnis = filter.outputImage else { return nil }

        // `CIFilter` liefert immer ein Quadrat in einer Grösse von 1–33 Punkten,
        // unabhängig von der gewünschten. Skaliert wird deshalb hier – und über
        // einen passenden Kontext, damit das Ergebnis **scharf** bleibt.
        let faktor = groesse / ergebnis.extent.width
        guard
            let skaliert = contexto.createCGImage(
                ergebnis, from: ergebnis.extent)
        else { return nil }

        let ziel = CGSize(
            width: ergebnis.extent.width * faktor,
            height: ergebnis.extent.height * faktor)
        guard let zeichner = CGContext(
            data: nil, width: Int(ziel.width), height: Int(ziel.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        zeichner.interpolationQuality = .none
        zeichner.draw(skaliert, in: CGRect(origin: .zero, size: ziel))
        guard let bild = zeichner.makeImage() else { return nil }
        return UIImage(cgImage: bild)
    }
}

/// Die Ansicht, in der ein QR-Code **gezeigt** wird.
///
/// ## Warum der Hintergrund weiß ist – und nicht der der App
///
/// Ein QR-Code wird von einem **Scanner** gelesen, und der rechnet mit einem
/// Kontrast wie auf Papier: dunkel auf hell. Ein heller Code auf dunklem Grund
/// liest sich bei vielen Kameras gar nicht.
///
/// Deshalb sitzt der Code in einem weißen Feld, auch wenn die App dunkel ist.
/// Der Rahmen darum hält den Ton der Seite – man sieht also, dass er dazugehört,
/// während der Code selbst so gezeichnet ist, wie ein Scanner ihn braucht.
final class QRCodeView: UIView {
    private let bildView = UIImageView()
    private let rahmenView = UIView()

    /// Setzt den Code. `nil` blendet die Ansicht aus.
    func setzeCode(_ bild: UIImage?) {
        bildView.image = bild
        rahmenView.isHidden = bild == nil
        // Ohne das läge der Code unscharf auf dem Retina-Bildschirm: Ein
        // `UIImageView` skaliert ein Bild sonst mit weicher Interpolation, und
        // genau an den Kanten eines QR-Codes entstehen dadurch graue Ränder,
        // die den ganzen Block unlesbar machen.
        //
        // `nearest` und **nicht** `none`: Letzteres gibt es bei
        // `CALayerContentsFilter` gar nicht. Die beiden Filter heissen
        // `nearest` und `linear`, und `nearest` ist hier das gesuchte „kein
        // Glätten, sondern jeden Punkt für sich nehmen".
        bildView.layer.magnificationFilter = .nearest
        bildView.layer.minificationFilter = .nearest
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        aufbauen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    private func aufbauen() {
        rahmenView.backgroundColor = .white
        rahmenView.layer.cornerRadius = 16
        // Der Code selbst bekommt einen kleinen Innenabstand: Direkt an der Kante
        // abgeschnittene Module sehen nach einem Fehler im Code aus, und genau
        // das ist der erste Verdacht, wenn jemand einen Scanner ausrichtet.
        rahmenView.layer.borderWidth = 0
        rahmenView.translatesAutoresizingMaskIntoConstraints = false

        bildView.contentMode = .scaleAspectFit
        bildView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rahmenView)
        rahmenView.addSubview(bildView)
        NSLayoutConstraint.activate([
            // Der Rahmen **füllt** diese Ansicht – er bestimmt nicht ihre Höhe.
            //
            // Die Höhe kommt von aussen (in [QRCodeScreen]: quadratisch, aber
            // höchstens ein Teil des Bildschirms). Wäre der Rahmen hier nur über
            // oben, unten und Mitte bestimmt, hinge seine Breite an der Höhe
            // und umgekehrt – ein Kreis, aus dem nur die Priorität von aussen
            // herauskommt. So ist es eindeutig: Der Rahmen füllt diese Ansicht.
            rahmenView.topAnchor.constraint(equalTo: topAnchor),
            rahmenView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rahmenView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rahmenView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Der Code selbst bekommt Innenabstand: Direkt an der Kante
            // abgeschnittene Module sehen nach einem Fehler im Code aus – und
            // genau das ist der erste Verdacht, wenn jemand einen Scanner
            // ausrichtet und nichts passiert.
            bildView.topAnchor.constraint(equalTo: rahmenView.topAnchor, constant: 16),
            bildView.bottomAnchor.constraint(
                equalTo: rahmenView.bottomAnchor, constant: -16),
            bildView.leadingAnchor.constraint(
                equalTo: rahmenView.leadingAnchor, constant: 16),
            bildView.trailingAnchor.constraint(
                equalTo: rahmenView.trailingAnchor, constant: -16),
        ])
    }
}