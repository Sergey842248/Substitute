import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/SchoolStorage.dart';

import 'SyncApiClient.dart';
import 'SyncEngine.dart';

/// Trägt den automatischen Sync, damit die Kette ohne Zutun des Nutzers
/// aktuell bleibt.
///
/// Vorher lief ein Sync **nur** über den Knopf in den Einstellungen. Das ist
/// keine ausreichende Form: Wer die App täglich öffnet, aber die Einstellungen
/// nie aufsucht, überträgt nie etwas – und ein Sync, den man sich nicht
/// erklären kann, wird irgendwann für kaputt gehalten.
///
/// ## Wann gelaufen wird
///
/// * einmal beim Start der App,
/// * beim Zurückkehren aus dem Hintergrund, wenn inzwischen Zeit vergangen ist,
/// * danach in festen Abständen, solange die App im Vordergrund ist.
///
/// ## Wann nicht
///
/// Der Koordinator sagt von selbst nein, und zwar bei jedem der folgenden
/// Punkte – jeder einzelne davon war schon einmal ein Fehler:
///
/// * **Kein Sync eingerichtet.** Es wird nicht einmal der Zustand gelesen.
/// * **Gerade ein Lauf dabei.** Der Knopf und der Zeitgeber dürfen sich nie
///   in die Quere kommen: zwei gleichzeitige Läufe könnten sich gegenseitig
///   die Daten zurückschreiben.
/// * **Zu früh.** Zwischen zwei Läufen muss [minInterval] liegen. Der Server
///   drosselt, und ein Lauf pro Sekunde hilft niemandem.
/// * **Gerade fehlgeschlagen.** Dann wächst die Wartezeit
///   ([backoffBase] … [backoffMax]). Sonst versucht die App alle paar Sekunden
///   dasselbe und macht die Leitung nur langsamer.
/// * **Demo-Account.** Dort gibt es nichts zu übertragen.
///
/// ## Sichtbarkeit
///
/// Über [changes] können Seiten zuhören, um sich nach einem Lauf mit fremden
/// Daten neu aufzubauen. Ohne diesen Schritt lädt zwar die Datei, die
/// angezeigte Liste aber nicht – was sich anfühlt, als sei nichts passiert.
class SyncCoordinator with WidgetsBindingObserver {
  SyncCoordinator._();

  static SyncCoordinator? _instance;

  /// Die einzige Instanz der App.
  static SyncCoordinator get instance =>
      _instance ??= SyncCoordinator._();

  /// Nur für Tests: baut eine frische Instanz.
  @visibleForTesting
  static SyncCoordinator createForTest() => SyncCoordinator._();

  /// Erzeugt den HTTP-Client eines Laufs. Nur für Tests überschreibbar.
  ///
  /// Ohne diese Naht ist der Koordinator nur gegen das *echte* Netz prüfbar –
  /// und ein Test gegen das echte Netz sagt bei einem Netzausfall "Kaputt",
  /// während bei einem Serverfehler "Alles gut" dasteht. Beides führt in die
  /// Irre. Die Naht ist auf `@visibleForTesting` beschränkt, damit im
  /// Betrieb niemand auf Verdacht einen anderen Client einsetzt.
  @visibleForTesting
  static SyncApiClient Function(Uri baseUrl)? clientFactory;

  /// Kürzester Abstand zwischen zwei Läufen.
  static const Duration minInterval = Duration(minutes: 2);

  /// Wie lange nach dem Start gewartet wird, bevor der erste Lauf startet.
  ///
  /// Nicht null: Der allererste Plan-Refresh der App braucht ebenfalls das
  /// Netz, und beide gleichzeitig wären doppelt Last. Der Start ist auch der
  /// Moment, in dem die App am ehesten im WLAN hängt – aber der erste Plan
  /// ist wichtiger als ein Sync, der zwei Minuten später kommt.
  static const Duration startupDelay = Duration(seconds: 20);

  /// Abstand zwischen zwei Zeitgeber-Läufen im Vordergrund.
  static const Duration tickInterval = Duration(minutes: 5);

  /// Erster Rückstand nach einem Fehlschlag.
  static const Duration backoffBase = Duration(minutes: 1);

  /// Höchster Rückstand. Danach lohnt weiteres Warten nicht mehr, es soll
  /// aber auch nicht endgültig aufgeben.
  static const Duration backoffMax = Duration(minutes: 30);

  final StreamController<SyncOutcome> _changes =
      StreamController<SyncOutcome>.broadcast();

  /// Feuert nach jedem Lauf, der etwas **herübergebracht** hat.
  ///
  /// Absichtlich nicht nach jedem Lauf: Eine Seite, die sich bei jeder
  /// Leerfahrt neu aufbaut, wäre beim Tippen unerträglich.
  Stream<SyncOutcome> get changes => _changes.stream;

  Timer? _startupTimer;
  Timer? _tickTimer;
  bool _running = false;
  bool _attached = false;
  DateTime? _lastRun;
  DateTime? _lastSuccess;
  int _consecutiveFailures = 0;

  /// Wird der Koordinator gerade gelassen?
  ///
  /// Für die Anzeige in den Einstellungen – dort steht bisher nur das Feld
  /// "letzter Sync", und das beantwortet die Frage nicht, ob überhaupt
  /// automatisch synchronisiert wird.
  bool get isAutomatic => _attached;

  /// Anzahl der Fehlschläge hintereinander – für die Diagnoseanzeige.
  int get consecutiveFailures => _consecutiveFailures;

  /// Wann zuletzt ein Lauf **erfolgreich** war.
  ///
  /// Getrennt von [SyncState.lastSync] zu halten ist wichtig: Dort steht der
  /// Wert, den der Knopf in den Einstellungen schreibt, hier der des
  /// Zeitgebers. Dass die beiden auseinanderlaufen, ist die Antwort auf die
  /// Frage „synct die App automatisch?" – ein einziges Feld könnte sie nicht
  /// beantworten.
  DateTime? get lastSuccess => _lastSuccess;

  /// Wie viele Geräte zuletzt in der Kette standen – einschließlich diesem.
  ///
  /// null, solange noch kein Lauf stattgefunden hat. Diese Zahl ist das
  /// wichtigste, was man über eine Kette wissen will, und sie stand nirgends:
  /// Nach einem Sync mit einem einzigen Gerät sieht alles erfolgreich aus und
  /// es fließt trotzdem nichts, weil es niemanden gibt, von dem etwas kommen
  /// könnte. Genau das lässt sich mit „Letzter Sync: gerade eben" nicht
  /// unterscheiden.
  int? get peerCount => _peerCount;
  int? _peerCount;

  /// Startet Zeitgeber und Lebenszyklus-Beobachtung.
  ///
  /// Idempotent: Ein zweiter Aufruf ändert nichts.
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    // Zwei Timer statt einem: Der Start-Timer wird nach 20 Sekunden genau
    // einmal ausgelöst. Läge er im selben Feld wie der Zeitgeber, überschriebe
    // der Perioden-Timer die Referenz – der Start-Timer liefe dann zwar
    // trotzdem, wäre aber nicht mehr abschaltbar. Genau das fällt in Tests
    // als "Sync passiert plötzlich doch" auf.
    _startupTimer = Timer(startupDelay, () => syncNow(reason: 'startup'));
    _tickTimer = Timer.periodic(tickInterval, (_) => syncNow(reason: 'tick'));
  }

  /// Stoppt alles wieder. Vor allem für Tests nötig.
  void detach() {
    if (!_attached) return;
    _attached = false;
    _startupTimer?.cancel();
    _startupTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Beim Zurückkehren ist die Wahrscheinlichkeit hoch, dass sich auf dem
    // anderen Gerät etwas getan hat – und das ist genau der Moment, an dem
    // der Nutzer ohnehin auf einen aktuellen Stand hofft.
    syncNow(reason: 'resumed');
  }

  /// Führt einen Lauf aus, sofern nichts dagegen spricht.
  ///
  /// [force] übergeht die Zeitprüfung – das ist der Knopf in den
  /// Einstellungen. Er wartet nicht und bricht nicht ab, weil "vor kurzem
  /// gesynchronisiert" gesagt wurde; wer darauf tippt, will jetzt etwas sehen.
  ///
  /// Gibt das Ergebnis zurück, oder null, wenn kein Lauf stattfand. null heißt
  /// ausdrücklich **nicht** Fehler: Es kann sein, dass gar nichts ansteht.
  Future<SyncOutcome?> syncNow({String reason = 'manual', bool force = false}) async {
    if (_running) return null;
    if (!force && !_dueByTime()) return null;

    _running = true;
    _lastRun = DateTime.now();
    SyncApiClient? client;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncState? state = await SyncEngine.loadState(prefs);
      if (state == null) return null;
      // Der Demo-Account hat nichts zu übertragen. Das wird hier geprüft und
      // nicht erst in der Oberfläche, weil dieser Koordinator ohne jede
      // Oberfläche arbeitet.
      if (VPlanAPI.isDemoAccount(prefs)) return null;
      // Die aktive Schule kann sich gewechselt haben, seit der Zustand
      // gespeichert wurde. Ohne diese Prüfung schriebe ein Lauf in die
      // falsche Schule – und der Merge gefresse die echten Daten.
      await SchoolStorage.ensureInitialized(prefs);

      final Uri base = SyncEngine.serverUrl(prefs);
      client = clientFactory?.call(base) ??
          SyncApiClient(baseUrl: base);
      final SyncOutcome outcome = await SyncEngine(client: client).run(
        prefs,
        state,
        deviceName: state.deviceName,
      );

      if (outcome.succeeded) {
        _consecutiveFailures = 0;
        _lastSuccess = DateTime.now();
        await SyncEngine.saveState(
          prefs,
          state.copyWith(lastSync: DateTime.now(), clearError: true),
        );
        _peerCount = outcome.devices.length;
        if (outcome.merged > 0 && !_changes.isClosed) {
          _changes.add(outcome);
        }
      } else {
        _consecutiveFailures++;
        await SyncEngine.saveState(
          prefs,
          state.copyWith(lastPushError: outcome.error),
        );
      }
      return outcome;
    } on SyncException {
      // Netzwerk, Zeitüberschreitung, Serverfehler: Alles drei ist ein Grund zu
      // warten, nicht zu hämmern.
      _consecutiveFailures++;
      return null;
    } finally {
      client?.dispose();
      _running = false;
      // ignore: avoid_print
      if (kDebugMode && reason != 'tick') {
        debugPrint('[Sync] $reason: '
            '${_consecutiveFailures == 0 ? 'ok' : 'Fehler ×$_consecutiveFailures'}');
      }
    }
  }

  /// Darf jetzt gelaufen werden?
  bool _dueByTime() {
    final DateTime? last = _lastRun;
    if (last == null) return true;
    final Duration waited = DateTime.now().difference(last);
    if (_consecutiveFailures == 0) {
      return waited >= minInterval;
    }
    // Nach einem Fehlschlag wächst die Wartezeit: 1, 2, 4, 8 … bis [backoffMax].
    final int steps = _consecutiveFailures;
    Duration needed = backoffBase;
    for (int i = 1; i < steps && needed < backoffMax; i++) {
      needed *= 2;
    }
    if (needed > backoffMax) needed = backoffMax;
    return waited >= needed;
  }

  /// Verwirft den gespeicherten Zustand – nach dem Verlassen der Kette.
  ///
  /// Ohne das würde der Koordinator die gerade verlassene Kette ein letztes
  /// Mal hochschieben, nachdem der Nutzer sie verlassen hat.
  void forget() {
    _lastRun = null;
    _lastSuccess = null;
    _consecutiveFailures = 0;
    _peerCount = null;
  }
}
