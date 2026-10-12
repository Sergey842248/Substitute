import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

import '../../models/Button.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingIndicator.dart';
import 'ShareListPage.dart';

/// Zeigt alle Shares einer Person und lässt einen davon importieren.
///
/// Der Ablauf ist eine Frage pro Schritt: **erst wird der Share gewählt, dann
/// entschieden, *was* davon übernommen wird, und zuletzt *wie*.** Auch bei einer
/// einzigen Share dieser Person wird nichts automatisch geöffnet – die Seite ist
/// die Übersicht, und wer eine Person gefunden hat, will in aller Regel sehen,
/// *was* sie anbietet, bevor er etwas übernimmt. Ein Automatismus wäre hier
/// nicht nur überraschend, sondern würde beim Tippen auf eine Person ohne
/// Rückfrage die Importseite mit einem bereits entschlüsselten Share öffnen.
///
/// Die Auswahl ist **einzeln**: jede Klasse und jede Person lässt sich
/// abwählen, standardmäßig ist alles ausgewählt. Wie importiert wird
/// (Original / Klassen / Personen) und ob die zwischengespeicherten Pläne mit
/// kommen, steht ganz unten unter „Erweiterte Optionen" – eingeklappt, weil
/// beides die Ausnahme ist und nicht der Normalfall. Voreingestellt sind
/// „Original" und „Pläne mitnehmen".
class ShareImportPage extends StatefulWidget {
  const ShareImportPage({
    Key? key,
    required this.client,
    required this.owner,
    required this.prefs,
  }) : super(key: key);

  final SyncApiClient client;
  final ShareOwner owner;
  final SharedPreferences prefs;

  @override
  State<ShareImportPage> createState() => _ShareImportPageState();
}

/// Wie breit der Radiobutton links in einer Zeile ist.
///
/// `RadioListTile` reserviert dafür Platz, ohne ihn zu benennen. Damit der
/// Pläne-Schalter ohne Icon nicht weiter links steht als die drei Radiobuttons
/// darüber, wird hier derselbe Platz von Hand gesetzt. Steht die Zahl einmal
/// daneben, ist der Versatz weg – statt ihn zu schätzen.
const double _radioGutter = 40;

class _ShareImportPageState extends State<ShareImportPage> {
  String? _selectedShareId;
  Map<String, dynamic>? _payload;
  ({int classes, int persons, int plans})? _counts;

  /// Die Klassen und Personen des geöffneten Shares, wie sie angezeigt werden.
  List<String> _classChoices = <String>[];
  List<({String id, String name})> _personChoices = <({String id, String name})>[];

  /// Was davon übernommen wird. Standardmäßig **alles** – wer einen Share
  /// öffnet, will ihn erst einmal sehen und erst dann entscheiden, was davon
  /// in die eigene App gehört. Alles vorausgewählt zu lassen ist deshalb der
  /// ehrliche Start; wer weniger braucht, klickt es ab.
  ShareImportSelection _selection =
      const ShareImportSelection(includePlans: true);

  /// Wie die Auswahl übernehmen wird. Standardmäßig **Original**: Nichts wird
  /// umgebaut, was die einzelne Einträge betrifft.
  ShareImportMode _mode = ShareImportMode.original;

  /// Der Schalter für die zwischengespeicherten Pläne steht unter den
  /// erweiterten Optionen und ist deshalb eingeklappt.
  bool _advancedOpen = false;

  bool _busy = false;
  String? _error;
  bool _needsPassword = false;

  String get _schoolPassword => widget.prefs.getString(
            SchoolStorage.scopedKey(widget.prefs, 'vplanPassword'),
          ) ??
      '';

  /// Öffnet einen Share. Bei einem passwortgeschützten Share wird zuerst nach
  /// dem Passwort gefragt – sonst wäre die Meldung "falscher Code" die ganze
  /// Information, die man bekäme.
  Future<void> _open(ShareSummary share) async {
    setState(() {
      _busy = true;
      _error = null;
      _selectedShareId = share.id;
    });

    ShareRecord? record;
    try {
      record = await widget.client.fetchShare(share.id);
    } on SyncException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      return;
    }
    if (!mounted) return;

    String? sharePassword;
    if (ShareManager.canUnlockWithPassword(record)) {
      setState(() {
        _busy = false;
        _needsPassword = true;
        _selectedShareId = share.id;
      });
      if (!mounted) return;
      sharePassword = await _askForPassword();
      if (sharePassword == null) {
        if (mounted) setState(() => _selectedShareId = null);
        return;
      }
      if (!mounted) return;
      setState(() => _busy = true);
    }

    try {
      // Keine Schulnummer nötig: Der Nutzername ist der Schlüssel. Das Schulpasswort
      // wird nur zusätzlich versucht – es ist der zweite Weg hinein, den der
      // Share anlegt, damit Kolleginnen der eigenen Schule den Share ohne die
      // zehn Wörter öffnen können.
      //
      // `unlockAsync` statt `unlock`: Die Schlüsselableitung (PBKDF2, 120 000
      // Runden je Hülle) lief auf dem UI-Thread. Währenddessen wird kein Frame
      // gezeichnet – die drei Punkte blieben reglos stehen, bis plötzlich der
      // Share offen war. Genau das war die „hängende" Ladeanimation.
      final Map<String, dynamic> payload = await ShareManager.unlockAsync(
        record,
        widget.owner.username,
        sharePassword: sharePassword,
        schoolPassword: sharePassword == null && _schoolPassword.isNotEmpty
            ? _schoolPassword
            : null,
      );
      if (!mounted) return;
      final ({
        List<String> classes,
        List<({String id, String name})> persons,
      }) items = ShareManager.selectableItems(payload);
      setState(() {
        _payload = payload;
        _counts = ShareManager.countContents(payload);
        _classChoices = items.classes;
        _personChoices = items.persons;
        // Alles vorausgewählt, Pläne eingeschaltet.
        _selection = ShareManager.selectAll(payload);
        _needsPassword = false;
        _busy = false;
      });
    } on ShareException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = shareErrorMessage(AppLocalizations.of(context)!, failure.code);
        _selectedShareId = null;
      });
    }
  }

  Future<String?> _askForPassword() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();
    final String? password = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.sharePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.sharePasswordRequired,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: l10n.sharePassword),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.shareImport),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  void _toggleClass(String short, bool selected) {
    setState(() {
      _selection = selected
          ? _selection.copyWith(
              classIds: <String>{..._selection.classIds, short},
            )
          : _selection.copyWith(
              classIds: <String>{..._selection.classIds}..remove(short),
            );
    });
  }

  void _togglePerson(String id, bool selected) {
    setState(() {
      _selection = selected
          ? _selection.copyWith(
              personIds: <String>{..._selection.personIds, id},
            )
          : _selection.copyWith(
              personIds: <String>{..._selection.personIds}..remove(id),
            );
    });
  }

  Future<void> _import() async {
    final Map<String, dynamic>? payload = _payload;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (payload == null) return;
    if (_selection.hasNothing) {
      setState(() => _error = l10n.shareImportNothingChosen);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ShareImportResult result = await ShareManager.applyImport(
        widget.prefs,
        payload,
        mode: _mode,
        displayName: widget.owner.displayName,
        selection: _selection,
      );
      if (!mounted) return;
      // Die Zahl der übernommenen Elemente wandert mit zurück, damit die
      // aufrufende Seite eine ehrliche Meldung zeigen kann.
      Navigator.pop(context, result);
    } on ShareException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = shareErrorMessage(AppLocalizations.of(context)!, failure.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Map<String, dynamic>? payload = _payload;

    return Scaffold(
      body: SafeArea(
        // Über der ganzen Seite statt als Zeile oben im Inhalt: Die Zeile stand
        // dort, wo man nicht hinsieht – der Share, auf den man getippt hat,
        // kann weiter unten stehen – und sie überlappte die Liste, statt sie zu
        // ersetzen.
        child: BusyOverlay(
          busy: _busy,
          label: l10n.loading,
          child: ListPage(
            title: l10n.shareOf(widget.owner.displayName),
            children: <Widget>[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              // Schritt 1: Alle Shares der Person auflisten. Sobald einer
              // gewählt ist, wird er markiert – sonst ist nicht erkennbar,
              // welcher gerade geöffnet wird.
              if (payload == null) ...<Widget>[
                for (final ShareSummary share in widget.owner.shares)
                  _shareTile(l10n, share),
              ],
              if (_needsPassword && payload == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Text(
                    l10n.sharePasswordRequired,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),

              // Schritt 2: Was steckt drin, was davon wird übernommen, und wie.
              if (payload != null && _counts != null) ...<Widget>[
                _sectionTitle(l10n.shareContents),
                _contentLine(l10n.shareContentsClasses(_counts!.classes)),
                _contentLine(l10n.shareContentsPersons(_counts!.persons)),
                _contentLine(l10n.shareContentsPlans(_counts!.plans)),

                // Schritt 2a: Die Auswahl. Alles ist vorausgewählt, damit man
                // sieht, was der Share überhaupt enthält – abwählen geht einzeln.
                _sectionTitle(l10n.shareSelectItems),
                if (_classChoices.isEmpty && _personChoices.isEmpty)
                  _contentLine(l10n.shareNothingToImport),
                if (_classChoices.isNotEmpty) ...<Widget>[
                  _subTitle(l10n.shareSelectClasses),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _classChoices
                        .map((String short) => FilterChip(
                              label: Text(short),
                              selected: _selection.classIds.contains(short),
                              onSelected: _busy
                                  ? null
                                  : (bool value) =>
                                      _toggleClass(short, value),
                            ))
                        .toList(),
                  ),
                ],
                if (_personChoices.isNotEmpty) ...<Widget>[
                  _subTitle(l10n.shareSelectPersons),
                  // Dieselben Chips wie bei den Klassen. Vorher stand hier eine
                  // Liste mit Kontrollkästchen und die Auswahl brach mitten in
                  // der Seite ab: Die Klassen wurden als Feldmarken gewählt, die
                  // Personen als Zeilen – zwei Systeme für dieselbe Frage. Jetzt
                  // steht beides als Feldmarken übereinander, und es passt auch
                  // mehr Personen nebeneinander in eine Zeile.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _personChoices
                        .map((({String id, String name}) person) => FilterChip(
                              label: Text(person.name),
                              selected:
                                  _selection.personIds.contains(person.id),
                              onSelected: _busy
                                  ? null
                                  : (bool value) =>
                                      _togglePerson(person.id, value),
                            ))
                        .toList(),
                  ),
                ],
                if (_classChoices.isNotEmpty || _personChoices.isNotEmpty)
                  _selectAllRow(l10n, payload),

                // Schritt 2b: Erweiterte Optionen. Ganz unten und
                // eingeklappt: Wer die Daten einfach übernehmen will, ist mit
                // Original und "alle ausgewählt" fertig – ohne sich durch drei
                // Radio-Buttons und einen Schalter zu arbeiten, die er nicht
                // braucht.
                _advancedTile(l10n),

                Button(
                  text: l10n.shareImport,
                  onPressed: _busy ? null : _import,
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareTile(AppLocalizations l10n, ShareSummary share) =>
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _busy ? null : () => _open(share),
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: const Icon(Icons.folder_rounded),
              ),
              title: Text(
                share.displayLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: share.id == _selectedShareId
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (share.hasPassword)
                    Text(l10n.sharePassword,
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ),
      );

  /// "Alle auswählen" / "Keine auswählen" über der Auswahlliste.
  Widget _selectAllRow(AppLocalizations l10n, Map<String, dynamic> payload) =>
      Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _selection = ShareManager.selectAll(payload)),
              child: Text(l10n.shareSelectEverything,
                  style: const TextStyle(fontSize: 13)),
            ),
            TextButton(
              // "Keine auswählen" darf den Pläne-Schalter nicht mitreißen –
              // das ist eine eigene Entscheidung und steht weiter unten.
              onPressed: _busy
                  ? null
                  : () => setState(() => _selection = _selection.copyWith(
                        classIds: <String>{},
                        personIds: <String>{},
                      )),
              child: Text(l10n.shareSelectNothing,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

  /// Der aufklappbare Kasten mit den erweiterten Optionen.
  Widget _advancedTile(AppLocalizations l10n) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Column(
            children: <Widget>[
              ListTile(
                onTap: _busy
                    ? null
                    : () => setState(() => _advancedOpen = !_advancedOpen),
                leading: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(100)),
                  child: const Icon(Icons.tune_rounded),
                ),
                title: Text(l10n.shareAdvancedOptions,
                    style: const TextStyle(fontSize: 18)),
                // Ohne Untertitel: Der Kasten ist eine Schaltfläche zum
                // Aufklappen, kein Textfeld. Welcher Modus gilt, steht direkt
                // darunter bei den Radiobuttons – und dort steht er auch dann,
                // wenn jemand hereinschaut, statt es sich merken zu müssen.
                trailing: Icon(
                  _advancedOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ),
              if (_advancedOpen) ...<Widget>[
                // Radio buttons: Die drei Modi schließen einander aus, deshalb
                // gehören sie in eine Gruppe – drei Tap-Kacheln, wie es vorher
                // war, wirkten wie drei equally-plausible Aktionen, obwohl es
                // eine einzige Frage mit drei Antworten ist.
                _sectionTitle(l10n.shareImportModeTitle),
                _modeOption(
                  ShareImportMode.original,
                  l10n.shareImportModeOriginal,
                  l10n.shareImportModeOriginalSubtitle,
                ),
                _modeOption(
                  ShareImportMode.plans,
                  l10n.shareImportModePlans,
                  l10n.shareImportModePlansSubtitle,
                ),
                _modeOption(
                  ShareImportMode.persons,
                  l10n.shareImportModePersons,
                  l10n.shareImportModePersonsSubtitle,
                ),
                _plansSwitchTile(l10n),
              ],
            ],
          ),
        ),
      );

  /// Eine der drei Antworten auf "Wie soll es übernommen werden?".
  Widget _modeOption(ShareImportMode mode, String title, String subtitle) =>
      Material(
        type: MaterialType.transparency,
        child: RadioListTile<ShareImportMode>(
          value: mode,
          // Dart-ANALYZE: `groupValue` ist deprecated, `RadioGroup` gibt es
          // erst ab Flutter 3.32. Das alte Feld bleibt die kompatible Wahl.
          // ignore: deprecated_member_use
          groupValue: _mode,
          // ignore: deprecated_member_use
          onChanged: _busy
              ? null
              : (ShareImportMode? value) => setState(
                  () => _mode = value ?? ShareImportMode.original),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          dense: true,
        ),
      );

  /// Der Schalter für die zwischengespeicherten Pläne.
  ///
  /// Früher stand hier eine `shareSwitch`-Kachel mit einem Icon links. Ihr Icon
  /// schob den Text so weit nach rechts, dass der Schalter gegenüber den drei
  /// Radiobuttons darüber deutlich versetzt wirkte – zwei Zeilen, dieselbe
  /// Frage, an zwei verschiedenen Stellen. Das Icon ist deshalb weg, und der
  /// Platz für den Radiobutton bleibt: So beginnt der Text genau dort, wo bei
  /// den Radios der Name beginnt.
  Widget _plansSwitchTile(AppLocalizations l10n) => Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          // Der leere Platz links ist der des Radiobuttons darüber – er hält
          // den Text auf derselben Linie.
          secondary: const SizedBox(width: _radioGutter),
          title: Text(l10n.shareImportCachedPlans),
          subtitle: Text(
            _mode == ShareImportMode.original
                ? l10n.shareImportCachedPlansSubtitle
                : l10n.shareImportPlansOnlyOriginal,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          value: _selection.includePlans,
          onChanged: _busy
              ? null
              : (bool value) => setState(
                  () => _selection = _selection.copyWith(includePlans: value)),
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );

  /// Wie [_sectionTitle], aber kleiner – für die Zwischentitel innerhalb der
  /// Auswahl („Klassen", „Personen").
  Widget _subTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );

  Widget _contentLine(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 2, 20, 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
}
