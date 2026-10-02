import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncCoordinator.dart';
import 'package:substitute/services/sync/SyncEngine.dart';
import 'package:substitute/services/sync/SyncKeys.dart';

import '../../../models/Button.dart';
import '../../../models/InputField.dart';
import '../../../models/ListPage.dart';
import '../../../models/LoadingProcess.dart';
import '../../../models/SettingsSwitchTile.dart';
import '../../../models/swipe_page_transition.dart';

import 'SyncDevices.dart';

/// Die Sync-Seite.
///
/// Der Ablauf ist bewusst kurz gehalten:
///
/// * **Aus** – entweder einen neuen Sync starten (die App erzeugt zehn Wörter)
///   oder mit den zehn Wörtern eines anderen Geräts beitreten.
/// * **An**  – "Jetzt synchronisieren", die Liste der Geräte und die Option,
///   ob die Einstellungen dazugehören. Dazu kommt der Code der Kette: Er ist
///   der Weg, ein weiteres Gerät hinzuzufügen, und er wird auch dann gezeigt,
///   wenn bisher nur dieses eine Gerät darin ist. Erst wenn die Kette gar kein
///   Gerät mehr enthält, wird sie aufgelöst.
///
/// Drei Kacheln – "Server prüfen", "Automatisch synchronisiert" und der
/// Zähler der übertragenen Einträge – erscheinen nur, wenn in den
/// Entwickleroptionen "Show additional sync options and information"
/// eingeschaltet ist. Sie sagen, was hinter der Kette passiert; im Alltag ist
/// das eine Zeile Text, die niemand liest.
///
/// Wer den Sync verlässt, behält alle Daten. Das steht ausdrücklich so auf der
/// Seite, weil es die häufigste Sorge ist.
class SyncSettings extends StatefulWidget {
  const SyncSettings({Key? key}) : super(key: key);

  @override
  State<SyncSettings> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettings> {
  SharedPreferences? _prefs;
  SyncState? _state;
  SyncApiClient? _client;

  bool _busy = false;
  bool _serverRunning = false;
  bool _checkedServer = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SyncState? state = await SyncEngine.loadState(prefs);
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
    // Der bisherige Client wird nach jedem [_load] ersetzt – auch nach jedem
    // Sync, denn die Anzeige lädt danach neu. Ohne dieses Schließen sammelt
    // sich bei jedem Lauf eine offene Verbindung an.
    final SyncApiClient? previous = _client;
    if (!mounted) {
      client.dispose();
      return;
    }
    setState(() {
      _prefs = prefs;
      _state = state;
      _client = client;
      // Der Entwicklerschalter wird bei jedem [_load] neu gelesen, nicht nur
      // beim Öffnen der Seite: Er wird in den Entwickleroptionen umgelegt, und
      // wer danach hierher zurückkehrt, soll die Kacheln sehen – ohne die App
      // neu zu starten.
      _showDetails = SyncEngine.showsDetails(prefs);
    });
    previous?.dispose();
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ Server

  Future<void> _checkServer() async {
    final SyncApiClient? client = _client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _checkedServer = false;
    });
    final bool running = await client.isServerRunning();
    if (!mounted) return;
    setState(() {
      _serverRunning = running;
      _checkedServer = true;
      _busy = false;
    });
  }

  // ------------------------------------------------------------------ Start

  /// Erzeugt einen neuen Sync: zehn Wörter, und dieses Gerät ist das erste
  /// darin.
  Future<void> _startSync() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;

    final String passphrase = SyncEngine.generatePassphrase();
    final ({String deviceId, String deviceName}) device =
        SyncEngine.createDevice(prefs);
    await prefs.setString('sync.deviceId', device.deviceId);
    final String deviceName = await SyncEngine.describeDevice();
    await prefs.setString('sync.deviceName', deviceName);

    final SyncState state = SyncState(
      passphrase: passphrase,
      chainId: SyncEngine.chainIdFor(passphrase),
      deviceId: device.deviceId,
      deviceName: deviceName,
      // Voreingestellt mit Einstellungen: Wer einen Sync einrichtet, will in
    // der Regel, dass beide Geräte gleich aussehen. Abschalten lässt es sich
    // jederzeit.
      includeSettings: true,
      lastSync: null,
    );
    await SyncEngine.saveState(prefs, state);
    if (!mounted) return;
    setState(() {
      _state = state;
    });

    // Der Code wird gezeigt, damit er notiert oder weitergegeben werden kann.
    await _showPassphrase(passphrase);

    // Und gleich das erste Mal synchronisieren, damit die eigenen Daten
    // oben liegen.
    await _runSync();
  }

  /// Tritt mit den eingegebenen Wörtern einem bestehenden Sync bei.
  Future<void> _joinSync() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final String? code = await _askForPassphrase();
    if (code == null || !mounted) return;

    final PassphraseCheck check = SyncEngine.checkPassphrase(code);
    if (!check.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (check.errorCode) {
            'tooFewWords' => l10n.syncPassphraseTooFewWords,
            'unknownWords' => l10n.syncPassphraseUnknownWord(check.detail ?? ''),
            _ => l10n.syncPassphraseEmpty,
          }),
        ),
      );
      return;
    }

    final String passphrase = code.trim();
    final String chainId = SyncEngine.chainIdFor(passphrase);

    // Erst prüfen, ob es die Kette überhaupt gibt – sonst würde man einen
    // leeren Sync anlegen, ohne es zu merken.
    setState(() => _busy = true);
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
    bool known = false;
    try {
      final List<SyncDevice> devices = await client.fetchDevices(chainId);
      // Der Server liefert auch für eine unbekannte Kette eine leere Liste –
      // das ist gewollt, weil das Raten einer Kette nichts nützen würde.
      known = devices.isNotEmpty;
    } on SyncException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.syncFailed}: ${error.message}')),
        );
      }
      return;
    }
    if (!known && mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncErrorNotFound)),
      );
      return;
    }
    if (!mounted) return;

    final ({String deviceId, String deviceName}) device =
        SyncEngine.createDevice(prefs);
    await prefs.setString('sync.deviceId', device.deviceId);
    final String deviceName = await SyncEngine.describeDevice();
    await prefs.setString('sync.deviceName', deviceName);

    final SyncState state = SyncState(
      passphrase: passphrase,
      chainId: chainId,
      deviceId: device.deviceId,
      deviceName: deviceName,
      includeSettings: true,
      lastSync: null,
    );
    await SyncEngine.saveState(prefs, state);
    if (!mounted) return;
    setState(() {
      _state = state;
      _busy = false;
    });

    await _runSync();
  }

  // -------------------------------------------------------------------- Lauf

  Future<void> _runSync() async {
    if (_prefs == null || _state == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    setState(() => _busy = true);
    // Bewusst über den Koordinator und nicht direkt über die Engine: Ein Lauf
    // darf nie zweimal gleichzeitig stattfinden. Zwei gleichzeitig laufende
    // Läufe könnten sich gegenseitig die Daten zurückschreiben – einer liest
    // den Stand, den der andere gerade geschrieben hat, und entscheidet dann
    // mit einer veralteten Grundlage. `force` übergeht nur die Zeitprüfung:
    // wer auf den Knopf tippt, will jetzt etwas sehen.
    final SyncOutcome? outcome =
        await SyncCoordinator.instance.syncNow(reason: 'manual', force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    // Der Koordinator schreibt `lastSync` und `lastPushError` in den
    // gespeicherten Zustand. Die Anzeige hier hat ihren eigenen Satz und
    // würde sonst weiter den alten Zeitpunkt zeigen.
    await _load();

    // null heißt: Ein Lauf war bereits unterwegs. Der zweite wäre derselbe
    // gewesen, also wird hier nichts gemeldet – zwei Erfolgsmeldungen für
    // einen Vorgang verwirren mehr als eine.
    if (outcome == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.succeeded
              ? (outcome.hasChanges
                  ? l10n.syncDone(outcome.merged, outcome.devices.length)
                  // "Alles aktuell" und "da war nichts zu holen" sind
                  // zwei verschiedene Nachrichten. Die zweite sagt dem
                  // Nutzer, woran es liegt, statt ihn zu raten lassen.
                  : (outcome.devices.length <= 1
                      ? l10n.syncDoneAlone
                      : l10n.syncDoneNoChanges))
              : '${l10n.syncFailed}: ${syncErrorMessage(l10n, outcome.error)}',
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Optionen

  Future<void> _toggleIncludeSettings(bool value) async {
    final SharedPreferences? prefs = _prefs;
    final SyncState? state = _state;
    if (prefs == null || state == null) return;
    final SyncState updated = state.copyWith(includeSettings: value);
    await SyncEngine.saveState(prefs, updated);
    if (!mounted) return;
    setState(() => _state = updated);
    // Die Umschaltung wirkt sich sofort aus: der nächste Lauf schickt die
    // Einstellungen mit – bzw. eben nicht.
    await _runSync();
  }

  /// Zeigt den Code der Kette – oder löst sie auf, wenn sie leer ist.
  ///
  /// Der Code ist nicht nur beim Einrichten interessant: Er ist der einzige
  /// Weg, ein weiteres Gerät in eine bestehende Kette zu holen – und zwar auch
  /// dann, wenn schon zwei oder mehr Geräte im Sync sind oder bisher nur
  /// dieses eine. Gerade im letzten Fall ist er die Chance, den Sync nicht
  /// verwaist auf dem Telefon sterben zu lassen, sondern das Tablet noch
  /// nachzuholen. Er wird deshalb **immer** gezeigt.
  ///
  /// Nur wenn die Kette gar kein Gerät mehr enthält, gibt es nichts zu zeigen:
  /// Dann ist auch dieses Gerät nicht mehr darin – etwa weil es in der
  /// Geräteliste entfernt wurde oder der Server die Kette nicht mehr kennt. Der
  /// Code führt ins Leere, und die Kette wird nach Rückfrage aufgelöst. Sie zu
  /// behalten wäre auch eine gültige Antwort, nur eben eine, die niemanden
  /// mehr erreicht.
  Future<void> _showPassphraseOrDissolve() async {
    final SharedPreferences? prefs = _prefs;
    final SyncState? state = _state;
    if (prefs == null || state == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    setState(() => _busy = true);
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
    final List<SyncDevice> devices;
    try {
      devices = await client.fetchDevices(state.chainId);
    } on SyncException catch (failure) {
      client.dispose();
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncErrorMessage(l10n, failure.code))),
      );
      return;
    }
    client.dispose();
    if (!mounted) return;
    setState(() => _busy = false);

    // Nur die ganz leere Kette zählt hier – **nicht** "außer mir ist niemand
    // mehr drin". Solange dieses Gerät noch in der Kette steht, gibt es einen
    // Code, mit dem ein weiteres Gerät beitreten kann, und der gehört gezeigt.
    if (devices.isEmpty) {
      await _confirmAndLeave(
        title: l10n.syncPassphraseNoDevicesTitle,
        message: l10n.syncPassphraseNoDevicesConfirm,
        actionLabel: l10n.syncLeave,
        doneMessage: l10n.syncPassphraseNoDevicesDone,
      );
      return;
    }
    await _showPassphrase(state.passphrase);
  }

  Future<void> _leaveChain() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await _confirmAndLeave(
      title: l10n.syncLeaveConfirmTitle,
      message: l10n.syncLeaveConfirm,
      actionLabel: l10n.syncLeave,
      doneMessage: l10n.syncLeaveDone,
    );
  }

  /// Nimmt dieses Gerät nach Rückfrage aus der Kette.
  ///
  /// Die Beschriftungen unterscheiden nur, **woher** der Weg herauskam – das
  /// "Sync verlassen" und das "Kette auflösen" machen technisch dasselbe: Der
  /// Snapshot dieses Geräts wird vom Server gelöscht, der lokale Zustand
  /// verschwindet, und die Daten auf dem Gerät bleiben, wo sie sind.
  Future<void> _confirmAndLeave({
    required String title,
    required String message,
    required String actionLabel,
    required String doneMessage,
  }) async {
    final SharedPreferences? prefs = _prefs;
    final SyncState? state = _state;
    if (prefs == null || state == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
    String? failure;
    try {
      await SyncEngine.leaveChain(prefs, state, client);
    } catch (error) {
      failure = error.toString();
    }
    client.dispose();
    // Der Koordinator darf die gerade verlassene Kette nicht ein letztes Mal
    // hochschieben. Sein gemerkter Zustand muss mit dem der App übereinstimmen,
    // sonst schiebt der nächste Zeitgeberlauf Daten in eine Kette, die es
    // offiziell nicht mehr gibt.
    SyncCoordinator.instance.forget();
    if (!mounted) return;
    setState(() {
      _state = null;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure == null ? doneMessage : l10n.syncLeaveFailed),
      ),
    );
  }

  Future<void> _deleteChain() async {
    final SharedPreferences? prefs = _prefs;
    final SyncState? state = _state;
    if (prefs == null || state == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.syncDeleteChainConfirmTitle),
        content: Text(l10n.syncDeleteChainConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.syncDeleteChain),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
    try {
      await client.deleteChain(state.chainId);
    } on SyncException {
      // Auch wenn es nicht klappt, wird der lokale Zustand aufgeräumt – sonst
      // zeigte die App einen Sync an, den es nicht mehr gibt.
    }
    client.dispose();
    await prefs.remove(SyncEngine.stateStorageKey);
    SyncCoordinator.instance.forget();
    if (!mounted) return;
    setState(() {
      _state = null;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.syncDeleteChainDone)),
    );
  }

  // ------------------------------------------------------------------ Dialoge

  /// Zeigt den erzeugten Code zum Abtippen oder Kopieren.
  Future<void> _showPassphrase(String passphrase) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          color: Theme.of(sheetContext).colorScheme.surface,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.syncPassphrase,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            SelectableText(
              passphrase,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.syncPassphraseHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Button(
              text: l10n.syncPassphraseCopy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: passphrase));
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.syncPassphraseCopied)));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Fragt die zehn Wörter eines bestehenden Syncs ab.
  Future<String?> _askForPassphrase() async {
    // Das Feld bekommt nur den Code einer **laufenden** Kette. Stand hier der
    // zuletzt benutzte Code, wäre nach dem Verlassen eines Syncs genau dessen
    // Wortfolge wieder im Feld – und wer dann auf "Beitreten" tippt, landet
    // wieder in derselben Kette, ohne es zu bemerken. Das war der gemeldete
    // Fehler: Nach dem Wechsel in einen neuen Sync stand noch der alte Code
    // drin.
    //
    // Beim Beitreten selbst (ohne laufende Kette) startet das Feld deshalb
    // **leer**, und ein verlassener oder gelöschter Sync hinterlässt nichts.
    final TextEditingController controller =
        TextEditingController(text: _state?.passphrase ?? '');
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.syncJoin),
        content: InputField(
          controller: controller,
          labelText: AppLocalizations.of(context)!.syncPassphrase,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context)!.shareImport),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- Aufbau

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final SyncState? state = _state;

    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.syncTitle,
          onRefresh: state == null ? null : _runSync,
          children: <Widget>[
            if (_busy) const Center(child: LoadingProcess()),
            // Die Server-Kachel ist Werbung für den Server und für niemanden
            // sonst: Im Alltag ist sie eine Zeile, die man nicht liest. Sie
            // erscheint deshalb nur, wenn die Entwickleroption
            // "Show additional sync options and information" eingeschaltet ist –
            // dann nämlich, wenn man wirklich wissen will, ob der Server läuft.
            if (_showDetails) _serverTile(l10n),
            if (state == null) ..._offlineChildren(l10n) else ..._onlineChildren(l10n, state),
            if (!_busy) const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _serverTile(AppLocalizations l10n) {
    if (!_checkedServer) {
      return _tile(
        icon: Icons.dns_rounded,
        title: l10n.syncServerCheck,
        subtitle: l10n.syncSubtitle,
        onTap: _checkServer,
      );
    }
    return _tile(
      icon: _serverRunning ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      title: _serverRunning ? l10n.syncServerRunning : l10n.syncServerStopped,
      subtitle: SyncEngine.serverUrl(_prefs!).toString(),
      onTap: _checkServer,
    );
  }

  List<Widget> _offlineChildren(AppLocalizations l10n) {
    return <Widget>[
      _tile(
        icon: Icons.play_arrow_rounded,
        title: l10n.syncStart,
        subtitle: l10n.syncStartSubtitle,
        onTap: _startSync,
      ),
      _tile(
        icon: Icons.login_rounded,
        title: l10n.syncJoin,
        subtitle: l10n.syncJoinSubtitle,
        onTap: _joinSync,
      ),
      _note(l10n.syncSettingsNote),
    ];
  }

  /// Kachel, die sagt, ob der Sync **von selbst** läuft.
  ///
  /// Vorher stand hier nur "Letzter Sync: …", und das beantwortet die Frage
  /// nicht, die man sich stellt, wenn einen der Knopf einen Klick lang
  /// beschäftigt: Läuft das überhaupt ohne mich? Die Antwort war vorher
  /// "nein" – ohne es irgendwo zu sagen.
  Widget _autoSyncTile(AppLocalizations l10n, SyncState state) {
    final SyncCoordinator coordinator = SyncCoordinator.instance;
    final DateTime? last = coordinator.lastSuccess ?? state.lastSync;
    final String subtitle = coordinator.consecutiveFailures > 0
        ? l10n.syncAutoFailing(coordinator.consecutiveFailures)
        : last == null
            ? l10n.syncAutoNever
            : l10n.syncAutoLast(_formatTime(last));
    return _tile(
      icon: Icons.autorenew_rounded,
      title: l10n.syncAutoTitle,
      subtitle: <String>[
        coordinator.isAutomatic
            ? l10n.syncAutoOn(SyncCoordinator.tickInterval.inMinutes)
            : l10n.syncNever,
        subtitle,
        // Die Zahl der Geräte in der Kette. Ohne sie ist ein Sync mit einem
        // einzigen Gerät nicht von einem Sync mit zwanzig zu unterscheiden –
        // beide melden nur "alles aktuell".
        if (coordinator.peerCount != null) l10n.syncPeerCount(coordinator.peerCount!),
      ].join(' · '),
      onTap: null,
    );
  }

  /// Kachel, die zählt, was tatsächlich zum Übertragen bereitsteht.
  ///
  /// Sie beantwortet die Frage, an der ein Sync scheitern kann, ohne dass
  /// irgendwo ein Fehler steht: "Sind überhaupt Daten da?" Bei einer frischen
  /// App ist die Antwort null, und ein Sync meldet trotzdem Erfolg – weil es
  /// ja auch nichts zu übertragen gab. Das sieht von außen genau aus wie ein
  /// kaputter Sync.
  Widget _payloadTile(AppLocalizations l10n) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return const SizedBox.shrink();
    // Über `SyncDataReader`, nicht über `getStringList`: Die Hälfte dieser
    // Schlüssel liegt als JSON-Zeichenkette in den Einstellungen. Ein
    // `getStringList` darauf wirft einen TypeError und nimmt die ganze Seite
    // mit – ausgerechnet beim Öffnen des Sync-Menüs.
    final List<String> keys = <String>[
      for (final String key in SyncKeys.dataKeys)
        SchoolStorage.scopedKey(prefs, key),
    ];
    final int count = SyncDataReader.countItemsOf(prefs, keys);
    return _tile(
      icon: Icons.inventory_2_rounded,
      title: l10n.syncPayloadCount(count),
      subtitle: count == 0 ? l10n.syncPayloadEmpty : l10n.syncAloneNote,
      onTap: null,
    );
  }

  List<Widget> _onlineChildren(AppLocalizations l10n, SyncState state) {
    final String lastSync = state.lastSync == null
        ? l10n.syncNever
        : l10n.syncLastSync(_formatTime(state.lastSync!));
    return <Widget>[
      _tile(
        icon: Icons.sync_rounded,
        title: l10n.syncNow,
        subtitle: '$lastSync · ${state.deviceName.isEmpty ? l10n.syncDeviceUnknown : state.deviceName}',
        onTap: _runSync,
      ),
      // "Automatisch synchronisiert" und der Zähler der Einträge sagen, was im
      // Hintergrund passiert. Das ist beim Einrichten und bei einer Störung
      // Gold wert und im Alltag eine Kachel, die man überliest – deshalb
      // beide hinter dem Entwicklerschalter.
      if (_showDetails) _autoSyncTile(l10n, state),
      if (_showDetails) _payloadTile(l10n),
      SettingsSwitchTile(
        icon: Icons.tune_rounded,
        title: l10n.syncSettingsToggle,
        subtitle: l10n.syncSettingsToggleSubtitle,
        value: state.includeSettings,
        onChanged: _busy ? (_) {} : _toggleIncludeSettings,
      ),
      // Der Code ist auch dann noch da, wenn schon zwei oder mehr Geräte im
      // Sync sind – er ist der einzige Weg, ein drittes Gerät hinzuzufügen,
      // und der Grund, warum die Kette überhaupt funktioniert.
      _tile(
        icon: Icons.password_rounded,
        title: l10n.syncPassphraseShow,
        subtitle: l10n.syncPassphraseShowSubtitle,
        onTap: _showPassphraseOrDissolve,
      ),
      _tile(
        icon: Icons.devices_rounded,
        title: l10n.syncDevices,
        subtitle: l10n.syncDeviceThisOne,
        onTap: () => Navigator.push(
          context,
          SwipePageTransition(
            type: PageTransitionType.rightToLeft,
            child: SyncDevices(
              client: SyncApiClient(baseUrl: SyncEngine.serverUrl(_prefs!)),
              state: state,
            ),
          ),
        ),
      ),
      _tile(
        icon: Icons.logout_rounded,
        title: l10n.syncLeave,
        subtitle: l10n.syncLeaveConfirm,
        onTap: _leaveChain,
      ),
      _tile(
        icon: Icons.delete_forever_rounded,
        title: l10n.syncDeleteChain,
        subtitle: l10n.syncDeleteChainConfirm,
        onTap: _deleteChain,
      ),
      _note(l10n.syncSettingsNote),
    ];
  }

  /// Die Uhrzeit in der Formatsprache der App, aber ohne Sekunden – die sind
  /// hier nur Rauschen.
  static String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) =>
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _busy ? null : onTap,
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(icon),
              ),
              title: Text(title, style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w100,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w100,
            color: Colors.grey,
          ),
        ),
      );
}

/// Übersetzt einen Fehlercode des Servers in eine Meldung der Oberfläche.
///
/// Top-Level und nicht Teil der Seite, weil auch die Share-Seiten ihre
/// Fehler genauso beschriften sollen.
String syncErrorMessage(AppLocalizations l10n, String? code) =>
    switch (code) {
      'network' => l10n.syncErrorNetwork,
      'timeout' => l10n.syncErrorTimeout,
      'notFound' => l10n.syncErrorNotFound,
      'wrongPassphrase' => l10n.syncErrorWrongPassphrase,
      'forbidden' => l10n.syncErrorForbidden,
      'tooManyRequests' => l10n.syncErrorTooManyRequests,
      'conflict' => l10n.syncErrorConflict,
      'tooLarge' => l10n.syncErrorTooLarge,
      'futureSchema' => l10n.syncErrorFutureSchema,
      'foreignApp' => l10n.syncErrorForeignApp,
      _ => l10n.syncErrorServerError,
    };
