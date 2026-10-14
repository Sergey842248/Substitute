import AVFoundation
import UIKit

/// Der Scanner, der einen QR-Code von der Kamera liest.
///
/// ## Warum `AVFoundation` und nicht das Kamera-Programm von Flutter
///
/// Weil diese Seite in `UIKit` steht und gar nicht erst in Flutter läuft. Ein
/// Blick in Flutter würde heißen, dass hier eine ganze Dart-Isolate für ein
/// Bild entsteht – und die einzige Aufgabe dieses Bildes ist, einen Text
/// zurückzugeben.
///
/// ## Der Rückweg ist derselbe wie beim Teilen
///
/// Was hier gelesen wird, muss genau das Format haben, was [QRCodeScreen]
/// erzeugt. Sonst wäre Teilen nutzlos: Man teilte etwas, das das andere Gerät
/// nicht lesen kann.
final class QRScannerController: UIViewController {
    /// Wird mit dem gelesenen Text aufgerufen – **einmal**.
    ///
    /// Nur einmal, und nicht bei jedem Bild: `AVCaptureMetadataOutput` liefert
    /// denselben Code über viele Bilder hinweg, und ohne diese Bremse würde der
    /// Bildschirm den gefundenen Wert dutzende Male übernehmen.
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var vorschau: AVCaptureVideoPreviewLayer?
    private var ausgabe: AVCaptureMetadataOutput?
    private var gemeldet = false

    init(titel: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = titel
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L.cancel, style: .plain, target: self, action: #selector(abbruch))
        navigationController?.navigationBar.tintColor = Appearance.accent

        // Ein Tippen irgendwo beendet den Scanner – das ist die Geste, die man
        // erwartet, wenn einen etwas stört. `cancelsTouchesInView` bleibt aber
        // `false`, sonst verschwände der Knopf „Einstellungen" unter dem Bild,
        // das er gerade anbietet.
        let tippen = UITapGestureRecognizer(
            target: self, action: #selector(abbruch))
        tippen.cancelsTouchesInView = false
        view.addGestureRecognizer(tippen)

        berechtigungPruefen()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Die Sitzung darf nur laufen, solange der Scanner wirklich da ist. Ohne
        // das liefe die Kamera im Hintergrund weiter – und das ist genau das, was
        // iOS einem verbietet.
        if !session.isRunning { starten() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Der Rahmen der Vorschau wird bei jeder Drehung neu gesetzt. Er wird
        // **nicht** per Auto Layout bestimmt: Eine `CALayer` nimmt an keinem
        // Auto-Layout teil – sie bekommt ihren Rahmen von Hand gesetzt.
        vorschau?.frame = view.bounds
    }

    deinit {
        session.stopRunning()
    }

    // ----------------------------------------------------------------- Ablauf

    /// Fragt nach der Erlaubnis – und startet erst danach.
    ///
    /// ## Warum gefragt wird, **bevor** die Kamera benutzt wird
    ///
    /// `AVCaptureSession.startRunning()` **blockiert** die aufrufende
    /// Warteschlange; das dauert bis zu einer halben Sekunde und friert dabei
    /// die Oberfläche ein. Lässt man es auf dieser Warteschlange laufen, dreht
    /// sich beim Öffnen kurz nichts mehr.
    ///
    /// Deshalb läuft es auf einer eigenen – und die Berechtigungsfrage ist
    /// vorher geklärt, damit dort nicht schon einmal die Kamera angefasst wird.
    private func berechtigungPruefen() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            aufbauen()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] erlaubt in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if erlaubt {
                        self.aufbauen()
                    } else {
                        self.zeigeKeinZugriff()
                    }
                }
            }
        case .denied, .restricted:
            zeigeKeinZugriff()
        @unknown default:
            zeigeKeinZugriff()
        }
    }

    private func aufbauen() {
        // Kein Bild, wenn keine Kamera da ist: Auf einem Gerät ohne Kamera –
        // oder in der Vorschau von Xcode – wäre eine leere schwarze Seite eine
        // Erklärung, die niemand geben kann.
        guard
            let geraet = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back),
            let eingang = try? AVCaptureDeviceInput(device: geraet),
            session.canAddInput(eingang)
        else {
            abbrechenMitHinweis(L.cameraUnavailable)
            return
        }
        session.addInput(eingang)

        let ausgabe = AVCaptureMetadataOutput()
        guard session.canAddOutput(ausgabe) else {
            abbrechenMitHinweis(L.cameraUnavailable)
            return
        }
        session.addOutput(ausgabe)
        ausgabe.setMetadataObjectsDelegate(self, queue: .main)
        // Nur QR-Codes. Ohne diese Einschränkung sucht der Ausgang auch nach
        // Strichcodes und nach allem anderen, was im Bild liegt – und gibt das
        // Erstbeste zurück, nicht den Code, den man eigentlich meint.
        ausgabe.metadataObjectTypes = [.qr]
        self.ausgabe = ausgabe

        let schicht = AVCaptureVideoPreviewLayer(session: session)
        schicht.videoGravity = .resizeAspectFill
        schicht.frame = view.bounds
        view.layer.insertSublayer(schicht, at: 0)
        vorschau = schicht

        starten()
    }

    private func starten() {
        guard !session.inputs.isEmpty else { return }
        // Auf einer eigenen Warteschlange – siehe [berechtigungPruefen].
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    @objc private func abbruch() {
        dismiss(animated: true)
    }

    // ---------------------------------------------------------- Die Meldungen

    /// Bricht ab und sagt dem Bildschirm darunter, warum.
    ///
    /// ## Warum eigener Name und nicht [UIViewController.melde]
    ///
    /// Der Hinweis gehört **dem Bildschirm darunter**: Diesen wird man im
    /// nächsten Augenblick nicht mehr sehen, und ein Hinweis, der an ihm hängt,
    /// erreicht niemanden.
    ///
    /// Weggegangen wird mit `dismiss` und **nicht** mit `pop`: Der Scanner wird
    /// von [CredentialsScreen] über der nativen Bildschirmreihe gezeigt, also als
    /// eigener Bildschirm. Ein `pop` würde nur die Navigation leeren und eine leere
    /// Seite stehen lassen – der Grund, warum man hergekommen ist, wäre dann weg.
    private func abbrechenMitHinweis(_ text: String) {
        guard let eltern = presentingViewController else { return }
        dismiss(animated: true)
        Meldung.zeigen(text, in: eltern.view)
    }

    /// Zeigt den Hinweis, wenn die Kamera verweigert wurde.
    ///
    /// Der Text sagt nicht nur, **was** fehlt, sondern auch, **wo** man es ändert:
    /// Die Kamera lässt sich nicht aus der App heraus einschalten, und ein
    /// Hinweis ohne Weg wäre eine Sackgasse.
    private func zeigeKeinZugriff() {
        let beschriftung = UILabel()
        beschriftung.text = L.cameraDenied
        beschriftung.font = .preferredFont(forTextStyle: .body)
        beschriftung.adjustsFontForContentSizeCategory = true
        beschriftung.textColor = .white
        beschriftung.textAlignment = .center
        beschriftung.numberOfLines = 0

        let knopf = UIButton(type: .system)
        knopf.configuration = .tinted()
        knopf.configuration?.title = L.openSettings
        knopf.configuration?.baseForegroundColor = .white
        knopf.addAction(
            UIAction { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString)
                else { return }
                UIApplication.shared.open(url)
            }, for: .touchUpInside)

        let stapel = UIStackView(arrangedSubviews: [beschriftung, knopf])
        stapel.axis = .vertical
        stapel.spacing = 16
        stapel.alignment = .center
        stapel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stapel)
        NSLayoutConstraint.activate([
            stapel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stapel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 32),
            stapel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -32),
        ])
    }
}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Die Bremse gegen mehrfaches Melden – siehe [onScan].
        guard !gemeldet else { return }
        guard
            let objekt = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            objekt.type == .qr,
            let inhalt = objekt.stringValue
        else { return }

        gemeldet = true
        // Das Bild wird abgeschaltet, **bevor** der Bildschirm weitersagt: Sonst
        // lief die Kamera noch, während schon die nächste Ansicht aufgebaut wird
        // – und die Session ist an diesen Bildschirm gebunden.
        session.stopRunning()

        onScan?(inhalt)
        dismiss(animated: true)
    }
}