import UIKit

/// Ein Blatt, in dem man ein Datum **und** eine Uhrzeit wählt.
///
/// ## Warum ein eigenes Blatt und kein `UIAlertController`
///
/// `UIAlertController` kennt **keine** Auswahl von Datum oder Uhrzeit. Es gibt
/// nur Textfelder – und ein Textfeld für eine Uhrzeit wäre genau das, was iOS
/// seit Jahren nicht mehr tut: man müsste „08:15" von Hand eintippen.
///
/// Das Blatt ist deshalb eine eigene, kleine Seite mit derselben Liste, die alle
/// anderen Bildschirme hier benutzen: eine Gruppe, ein Zeiger, zwei Knöpfe.
///
/// ## Der Zeiger im **Rollen**format
///
/// Bei den Stundenzeiten will man eine Uhrzeit wählen, kein Datum. Bei den
/// Entwickleroptionen beides. Deshalb wird die Art übergeben und nicht
/// festgeschrieben – eine Seite, die immer beides zeigt, wäre für die häufigere
/// der beiden Aufgaben umständlich.
final class DateTimePickerSheet: UIViewController {
    /// Wie viel die Auswahl gilt.
    enum Art {
        /// Nur die Uhrzeit.
        case uhrzeit
        /// Datum und Uhrzeit zusammen.
        case datumUndUhrzeit
    }

    /// Der Zeiger selbst.
    private let zeiger = UIDatePicker()

    private let art: Art
    private let start: Date

    /// Wird mit der gewählten Zeit aufgerufen – oder **nicht**, wenn abgebrochen
    /// wurde. Deshalb ist es ein Aufruf und kein Rückgabewert: Der Bildschirm
    /// hält den Bildschirmschirm selbst fest, und `dismiss` von hier aus würde
    /// ihn mitnehmen.
    var onSave: ((Date) -> Void)?

    init(titel: String, start: Date, art: Art) {
        self.art = art
        // Fällt der übergebene Wert auf heute zurück, wird von der jetzigen – und
        // nicht von der Mitternacht des Tages ausgehend gewählt. Sonst stünde der
        // Zeiger bei 00:00, während die wirkliche Uhrzeit frühmorgens ist, und
        // man müsste erst durch den halben Tag zurück.
        self.start = Calendar.current.isDate(start, inSameDayAs: Date())
            ? start
            : Date()
        super.init(nibName: nil, bundle: nil)
        self.title = titel
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) fehlt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.background

        zeiger.datePickerMode = art == .uhrzeit ? .time : .dateAndTime
        // Das Rollenformat hat eine feste Höhe und öffnet **nichts** über sich:
        // Ein Zeiger im Kompaktformat öffnet beim Tippen ein zweites Fenster über
        // dem Blatt, und der Bildschirm darunter – die Liste, aus der man die
        // Stundenzeiten gewählt hat – wäre dann nicht mehr zu sehen.
        zeiger.preferredDatePickerStyle = .wheels
        zeiger.date = start
        zeiger.tintColor = Appearance.accent
        zeiger.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(zeiger)
        NSLayoutConstraint.activate([
            zeiger.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            zeiger.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zeiger.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L.cancel, style: .plain, target: self, action: #selector(abbrechen))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L.save, style: .done, target: self, action: #selector(speichern))

        // Die Leiste braucht ihre Farben von hier: Sie gehört zu diesem
        // Bildschirm, und diese Seite ist es, die sie aufbaut.
        navigationController?.navigationBar.tintColor = Appearance.accent
    }

    @objc private func speichern() {
        onSave?(zeiger.date)
        dismiss(animated: true)
    }

    @objc private func abbrechen() {
        // Bewusst **ohne** `onSave`: Ein Abbruch verwirft die Wahl.
        dismiss(animated: true)
    }
}