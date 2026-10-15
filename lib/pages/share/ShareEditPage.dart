import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/NameGuard.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

import '../../../models/Button.dart';
import '../../../models/InputField.dart';
import '../../../models/ListPage.dart';
import '../../../models/LoadingIndicator.dart';
import 'ShareListPage.dart';

/// Anlegen oder Bearbeiten eines Shares.
///
/// Reihenfolge der Seite folgt der Frage "was brauche ich in welcher
/// Reihenfolge?": erst *was* geteilt wird, dann *wie* es auffindbar ist
/// (suchbar/global), dann der Schutz (Passwort) und zuletzt der Name, unter
/// dem es in der Liste steht.
class ShareEditPage extends StatefulWidget {
  const ShareEditPage({
    Key? key,
    required this.client,
    required this.prefs,
    this.share,
  }) : super(key: key);

  final SyncApiClient client;
  final SharedPreferences prefs;

  /// null, wenn ein neuer Share entsteht.
  final LocalShare? share;

  @override
  State<ShareEditPage> createState() => _ShareEditPageState();
}

class _ShareEditPageState extends State<ShareEditPage> {
  late ShareSelection _selection;
  late TextEditingController _labelController;
  late TextEditingController _passwordController;

  /// Der Fokus des Passwortfeldes.
  ///
  /// Das Einschalten des Passwortschalters legt das Feld frei – und der Cursor
  /// soll dann auch darin stehen. Wer den Share absichern will, tippt sofort;
  /// er soll nicht erst noch einmal auf das Feld tippen müssen.
  final FocusNode _passwordFocus = FocusNode();

  late List<String> _classes;
  late List<({String id, String name})> _persons;

  bool _searchable = true;
  bool _busy = false;
  String? _error;

  /// Ob das Passwortfeld offen steht.
  ///
  /// Getrennt vom Inhalt des Feldes: Der Schalter zeigt an, ob ein Passwort
  /// **gesetzt** ist – das ist der Text im Feld. Das Feld kann offen sein, ohne
  /// dass schon etwas drinsteht (direkt nach dem Einschalten), und es kann
  /// gefüllt sein, ohne dass jemand den Schalter umgelegt hat (etwa wenn ein
  /// vorhandenes Passwort aus dem Speicher kommt). Ein einziges Feld für
  /// beides würde eines der beiden verschlucken.
  bool _passwordOpen = false;

  /// Ob die erweiterten Optionen aufgeklappt sind. Sie sind die Ausnahme –
  /// der Normalfall ist ein Share für die eigene Schule, sichtbar in der
  /// eigenen Schule, mit den Plänen der letzten Wochen.
  bool _advancedOpen = false;

  /// Ob der Vorschlagstext schon gesetzt wurde. Der braucht die Übersetzungen
  /// und steht deshalb nicht in [initState] – siehe [didChangeDependencies].
  bool _labelInitialised = false;

  @override
  void initState() {
    super.initState();
    _classes = readClassShorts(widget.prefs);
    _persons = readPersons(widget.prefs);
    final LocalShare? share = widget.share;
    _selection = share?.selection ?? const ShareSelection();
    // **Kein** `_defaultLabel()` hier: Es greift über
    // `AppLocalizations.of(context)` auf ein InheritedWidget zu, und darauf
    // darf vor Abschluss von `initState` nicht zugegriffen werden – das warf
    // „dependOnInheritedWidgetOfExactType … was called before
    // _ShareEditPageState.initState() completed" und ließ die Seite beim
    // Anlegen eines Shares abstürzen. Der Text wird stattdessen gleich in
    // `didChangeDependencies` nachgetragen.
    _labelController = TextEditingController(text: share?.label ?? '');
    _labelInitialised = share?.label != null;
    _passwordController = TextEditingController(
      text: share == null || !share.hasPassword
          ? ''
          : (ShareManager.readSharePassword(widget.prefs) ?? ''),
    );
    // Bei einem Share mit Passwort steht das Feld offen – es ist ja gefüllt.
    _passwordOpen = _passwordController.text.trim().isNotEmpty;
    _searchable = share?.searchable ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Läuft direkt nach `initState` – hier sind die Übersetzungen verfügbar.
    // Nur einmal: bei einem späteren Sprachwechsel soll der Name eines
    // vorhandenen Shares nicht überschrieben werden.
    if (_labelInitialised) return;
    _labelInitialised = true;
    _labelController.text = _defaultLabel();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _passwordFocus.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Der Vorschlag für den Namen des neuen Shares.
  ///
  /// Ohne ausgewählte Klassen steht der Standard drin („Mein Plan") – vorher
  /// stand dort „Neuer Share", was als Name nichts taugte. Sobald genau eine
  /// Klasse gewählt ist, übernimmt deren Kürzel; bei mehreren wird der Standard
  /// mit der Anzahl ergänzt.
  String _defaultLabel() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_selection.classIds.isEmpty && _selection.personIds.isEmpty) {
      return l10n.shareDefaultLabel;
    }
    if (_selection.classIds.length == 1) return _selection.classIds.first;
    return '${l10n.shareDefaultLabel} ${_selection.classIds.length}';
  }

  String _schoolNumber() =>
      widget.prefs.getString(
        SchoolStorage.scopedKey(widget.prefs, 'vplanSchoolnumber'),
      ) ??
      '';

  String _schoolPassword() =>
      widget.prefs.getString(
        SchoolStorage.scopedKey(widget.prefs, 'vplanPassword'),
      ) ??
      '';

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_selection.isEmpty) {
      setState(() => _error = l10n.shareSelectNothingSelected);
      return;
    }
    // Der Name des Shares steht offen in einer Liste, die alle Kolleginnen
    // sehen – derselbe Name wird also geprüft wie ein Anzeigename. Ein
    // anstößiger Name wird **nicht** übernommen, es gibt eine Warnung und das
    // Speichern bricht ab.
    final NameVerdict labelVerdict = NameGuard.check(_labelController.text);
    if (labelVerdict.isBlocked) {
      setState(() => _error = shareNameError(l10n, labelVerdict));
      return;
    }
    final String schoolNumber = _schoolNumber();
    if (schoolNumber.isEmpty) {
      setState(() => _error = l10n.credentialsSubtitle);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ShareManager manager = ShareManager(client: widget.client);
    final String? displayName = ShareManager.readDisplayName(widget.prefs);
    final String password = _passwordController.text.trim();

    try {
      final Map<String, dynamic> payload =
          await ShareManager.buildPayload(widget.prefs, _selection);
      if (widget.share == null) {
        await manager.publish(
          prefs: widget.prefs,
          schoolNumber: schoolNumber,
          schoolPassword: _schoolPassword(),
          displayName: displayName ?? '',
          label: _labelController.text.trim(),
          payload: payload,
          selection: _selection,
          searchable: _searchable,
          sharePassword: password.isEmpty ? null : password,
        );
      } else {
        await manager.update(
          prefs: widget.prefs,
          schoolNumber: schoolNumber,
          schoolPassword: _schoolPassword(),
          share: widget.share!,
          label: _labelController.text.trim(),
          searchable: _searchable,
          selection: _selection,
          // Auch beim Bearbeiten zählt, was im Formular steht: Vorher stand das
          // Passwortfeld hier nicht in der Anfrage, ein neu eingetipptes
          // Passwort wurde also stillschweigend verworfen und ein
          // abgeschaltetes ignoriert. Ein leeres Feld heißt hier ausdrücklich
          // „kein Passwort" – nicht „unverändert".
          sharePassword: password,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ShareException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = shareErrorMessage(l10n, failure.code);
      });
    } on SyncException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Der **Code** wird übersetzt, nicht der englische Servertext. Vorher
        // stand hier `l10n.syncFailed` als Text in der Fehlermeldung – das ist
        // aber eine Funktion mit einem Parameter, und interpoliert wurde sie
        // deshalb als „Closure: (Object) => String …" samt englischem Originaltext
        // angezeigt.
        _error = shareErrorMessage(l10n, failure.code);
      });
    }
  }

  /// Der Schalter „Dein eigenes Passwort".
  ///
  /// Einschalten legt das Feld frei und **leert** es – siehe die Kachel. Der
  /// Schalter selbst steht anschließend noch auf aus, weil im Feld noch nichts
  /// steht: Das ist die Wahrheit, und beim Speichern wird genau das gespeichert.
  /// Ein Schalter, der etwas behauptet, das nicht gespeichert wird, wäre schlimmer
  /// als einer, der einen Tick später nachkommt.
  void _togglePassword(bool value) {
    setState(() {
      _passwordController.clear();
      _passwordOpen = value;
    });
    if (value) _passwordFocus.requestFocus();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool editing = widget.share != null;

    return Scaffold(
      // ListPage behandelt die Safe Area selbst; außen darf kein zweiter
      // permanenter unterer iOS-Abstand entstehen.
      body: SafeArea(
        bottom: false,
        // Die Ladeanzeige liegt über der ganzen Seite und nicht als Zeile oben
        // im Inhalt: Sie war vorher dort, wo man nicht hinsieht. Der Knopf, auf
        // den gedrückt wurde, steht ganz unten – die Anzeige darüber war
        // außerhalb des Bildes, und beim Anlegen schien deshalb gar nichts zu
        // passieren.
        child: BusyOverlay(
          busy: _busy,
          // Beim Bearbeiten wird nichts neu **angelegt**, sondern der
          // vorhandene Share mit neuem Inhalt überschrieben. Das sind zwei
          // verschiedene Vorgänge, und die Anzeige unterschied sie vorher nicht:
          // Über „Änderungen speichern" stand „lade…" – also eine Meldung über
          // etwas, das gar nicht geladen wurde.
          label: editing ? l10n.updating : l10n.loading,
          child: ListPage(
            title: editing ? l10n.shareEdit : l10n.shareCreate,
            children: <Widget>[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),

              _sectionTitle(l10n.shareSelectClasses),
              // Eigene Meldung: Die Klassen-Sektion zeigte den Personentext
              // („Noch keine Personen. Füge eine Person hinzu …") – auch dann,
              // wenn Klassen vorhanden waren.
              if (_classes.isEmpty)
                _empty(l10n.noClassesYet)
              else
                Wrap(
                  spacing: 8,
                  children: _classes
                      .map((String short) => FilterChip(
                            label: Text(short),
                            selected: _selection.classIds.contains(short),
                            onSelected: (bool value) =>
                                _toggleClass(short, value),
                          ))
                      .toList(),
                ),
              _rowButtons(l10n),

              _sectionTitle(l10n.shareSelectPersons),
              if (_persons.isEmpty)
                _empty(l10n.noPersonsYet)
              else
                // Dieselben Feldmarken wie bei den Klassen darüber. Vorher stand
                // hier eine Liste mit Kontrollkästchen – zwei Systeme für
                // dieselbe Frage auf derselben Seite, und die Liste brach mitten
                // in der Seite ab, während die Chips nebeneinander Platz finden.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _persons
                      .map((({String id, String name}) person) => FilterChip(
                            label: Text(person.name),
                            selected: _selection.personIds.contains(person.id),
                            onSelected: (bool value) =>
                                _togglePerson(person.id, value),
                          ))
                      .toList(),
                ),

              _sectionTitle(l10n.shareSearchable),
              _switchTile(
                l10n.shareSearchable,
                l10n.shareSearchableSubtitle,
                _searchable,
                (bool value) => setState(() => _searchable = value),
              ),

              _sectionTitle(l10n.sharePassword),
              _switchTile(
                l10n.sharePasswordOwn,
                l10n.sharePasswordSubtitle,
                _passwordController.text.trim().isNotEmpty,
                _togglePassword,
              ),
              // Das Feld erscheint, sobald der Schalter eingeschaltet wird –
              // und bleibt **leer**. Vorher stand hier ungefragt eine Wortphrase
              // drin („red moon water nine …"), die niemand notiert hatte: ein
              // Passwort, das beim nächsten Bearbeiten unbemerkt wieder im Feld
              // stand und von dem niemand wusste, ob es noch gilt. Wer einen
              // Share absichert, hat meistens ein eigenes Passwort; es soll
              // getippt werden können. Wer keins hat, tippt auf „Passwort
              // erzeugen".
              if (_passwordOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: <Widget>[
                      InputField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        labelText: l10n.sharePasswordHint,
                        onChanged: (_) => setState(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _passwordController.text =
                                ShareManager.generateSharePassword();
                          }),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.sharePasswordGenerate,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Die erweiterten Optionen stehen ganz unten und sind eingeklappt:
              // Ein Share ist im Normalfall sichtbar für die eigene Schule, und
              // niemand braucht dafür einen Schalter für "Pläne teilen" – die
              // Pläne gehören zu den geteilten Klassen und sind dabei.
              _advancedTile(l10n),

              _sectionTitle(l10n.shareLabel),
              InputField(
                controller: _labelController,
                labelText: l10n.shareLabelHint,
              ),

              Button(
                // "Übernehmen" war hier das falsche Wort: Es steht am Ende einer
                // Seite, auf der nichts übernommen, sondern ein Share
                // erstellt wird. Beim Bearbeiten heißt derselbe Knopf
                // "Änderungen speichern" – auch das sagt, was passiert.
                text: editing ? l10n.shareEditSubmit : l10n.shareCreateSubmit,
                onPressed: _busy ? null : _save,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Der aufklappbare Kasten mit den erweiterten Optionen.
  Widget _advancedTile(AppLocalizations l10n) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 20, 10, 0),
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
                trailing: Icon(
                  _advancedOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ),
              if (_advancedOpen) ...<Widget>[
                _switchTile(
                  l10n.shareIncludeHistory,
                  l10n.shareIncludeHistorySubtitle(ShareManager.historyDays),
                  _selection.includeHistory,
                  (bool value) => setState(() =>
                      _selection = _selection.copyWith(includeHistory: value)),
                ),
                _switchTile(
                  l10n.shareIncludeSettings,
                  l10n.shareIncludeSettingsSubtitle,
                  _selection.includeSettings,
                  (bool value) => setState(() =>
                      _selection = _selection.copyWith(includeSettings: value)),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );

  Widget _rowButtons(AppLocalizations l10n) => Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: () => setState(() {
                _selection = _selection.copyWith(
                  classIds: _classes.toSet(),
                  personIds: _persons
                      .map((({String id, String name}) p) => p.id)
                      .toSet(),
                );
              }),
              child: Text(l10n.shareSelectEverything,
                  style: const TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selection = _selection.copyWith(
                  classIds: <String>{},
                  personIds: <String>{},
                );
              }),
              child: Text(l10n.shareSelectNothing,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      shareSwitch(
        icon: Icons.tune_rounded,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: _busy ? (_) {} : onChanged,
      );
}
