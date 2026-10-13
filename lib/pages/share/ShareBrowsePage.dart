import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/sync/NameGuard.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

import '../../models/InputField.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingIndicator.dart';
import 'ShareImportPage.dart';

/// Das Suchmenü: Wer in der eigenen Schule etwas geteilt hat.
///
/// **Eine** Zeile erledigt beides:
///
/// * **Name eingeben** – filtert die Liste der Kolleginnen und Kollegen, die
///   ihre Shares als suchbar markiert haben. Von einer fremden Schule kommt
///   hier nichts: Der Server filtert nach Schulnummer, und ohne Anmeldung gibt
///   es keine Schulnummer. Leer zeigt die Zeile alle suchbaren Shares,
///   alphabetisch sortiert.
/// * **Die zehn Wörter einer Person** – sind eingegeben, gilt der Text als
///   Nutzername und deren Shares werden direkt geöffnet. Dafür gab es vorher
///   einen eigenen Menüpunkt („Nutzername eingeben"); der ist entfallen, weil
///   es derselbe Text in derselben Zeile ist.
class ShareBrowsePage extends StatefulWidget {
  const ShareBrowsePage({Key? key}) : super(key: key);

  @override
  State<ShareBrowsePage> createState() => _ShareBrowsePageState();
}

class _ShareBrowsePageState extends State<ShareBrowsePage> {
  SharedPreferences? _prefs;
  SyncApiClient? _client;
  List<ShareOwner> _people = const <ShareOwner>[];

  /// Der Text in der Suchzeile.
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  bool _signedIn = false;
  bool _isDemo = false;
  String? _error;

  /// Läuft gerade die Suche nach einem eingegebenen Nutzernamen.
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _client?.dispose();
    super.dispose();
  }

  /// Der eingegebene Text, für die Anzeige geglättet.
  String get _query => _search.text.trim();

  /// Passt der Text zur Wortliste und damit zu einem Nutzernamen? Genau dann
  /// ist er kein Suchbegriff, sondern die zehn Wörter einer Person.
  bool get _isPassphrase =>
      _query.isNotEmpty && Passphrase.looksLikePassphrase(_query);

  /// Die gefilterte, alphabetisch sortierte Liste – siehe [filterAndSortOwners].
  List<ShareOwner> get _visiblePeople => filterAndSortOwners(_people, _query);

  void _onSearchChanged(String _) => setState(() {});

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SyncApiClient client =
        SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));

    // Im Demo-Account gibt es weder Schulnummer noch echte Nutzer: Dort wird
    // die Funktion gar nicht erst angeboten, sondern nur der Leerzustand
    // gezeigt. Ein Demo-Datensatz, der in einer echten Suchliste auftaucht,
    // wäre irreführend.
    final bool isDemo = VPlanAPI.isDemoAccount(prefs);

    final bool signedIn = await SchoolStorage.hasCredentials(prefs);
    if (!signedIn || isDemo) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _client = client;
        _isDemo = isDemo;
        _signedIn = signedIn;
        _people = const <ShareOwner>[];
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _client = client;
      _signedIn = true;
      _isDemo = isDemo;
    });

    await _refresh();
  }

  Future<void> _refresh() async {
    final SharedPreferences? prefs = _prefs;
    final SyncApiClient? client = _client;
    if (prefs == null || client == null) return;
    final String schoolNumber = prefs.getString(
          SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber'),
        ) ??
        '';

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<ShareOwner> people = await client.fetchDirectory(schoolNumber);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } on SyncException catch (failure) {
      if (!mounted) return;
      setState(() {
        _people = const <ShareOwner>[];
        _loading = false;
        _error = failure.message;
      });
    }
  }

  /// Öffnet die Shares der Person, deren zehn Wörter in der Suchzeile stehen.
  ///
  /// Der frühere eigene Menüpunkt „Nutzername eingeben" ist entfallen: Es ist
  /// derselbe Text in derselben Zeile – die Suche erkennt eine Wortphrase und
  /// behandelt sie als Nutzernamen.
  Future<void> _openByUsername(String username) async {
    final SharedPreferences? prefs = _prefs;
    final SyncApiClient? client = _client;
    if (prefs == null || client == null || username.isEmpty) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (_resolving) return;
    setState(() => _resolving = true);

    // Die eingegebenen Wörter sind der Nutzername der anderen Person. Daraus
    // lässt sich deren Share-ID berechnen – der Server muss den Namen also
    // nie im Klartext speichern, um ihn auffindbar zu machen.
    //
    // Die ID hängt **nur** am Nutzernamen, nicht an der Schulnummer: Deshalb
    // funktioniert dieser Weg auch für jemanden aus einer anderen Schule. Das
    // Suchverzeichnis zeigt dagegen nur die eigene Schule – wer dort nicht
    // steht, ist nur über die zehn Wörter zu erreichen.
    //
    // Eine Person kann mehrere Shares haben. Deren IDs hängen an der ersten
    // plus einem Zähler (`<id>-2`, `<id>-3` …), deshalb werden die Varianten
    // nacheinander abgeklopft – sonst wäre über den Nutzernamen nur der erste
    // Share zu erreichen, während das Suchverzeichnis alle zeigt.
    //
    // Sobald eine ID nichts liefert, ist Schluss: `nextShareId` vergibt die
    // Zähler lückenlos, es sei denn, jemand hat mittendrin einen Share
    // gelöscht. Genau dafür wäre das ganze Fenster hier durchzugehen – und
    // bei einem Tippfehler im Nutzernamen wären das bis zu 50 Anfragen, die
    // nur Fehlschläge sind. Wer den ersten Share gelöscht hat, ist über die
    // Schulnummern-Suche ohnehin erreichbar.
    final List<ShareSummary> shares = <ShareSummary>[];
    for (int index = 1; index <= ShareManager.maxShares; index++) {
      try {
        final ShareRecord record =
            await client.fetchShare(ShareManager.shareIdFor(username, index));
        shares.add(ShareSummary(
          id: record.id,
          username: username,
          displayName: username,
          label: '',
          hasPassword: record.hasPassword,
          updatedAt: record.updatedAt,
        ));
      } on SyncException {
        break;
      }
    }

    if (!mounted) return;
    setState(() => _resolving = false);
    if (shares.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shareErrorWrongCredentials)));
      return;
    }
    await _openShares(ShareOwner(
      username: username,
      displayName: username,
      shares: shares,
    ));
  }

  Future<void> _openShares(ShareOwner owner) async {
    if (!mounted) return;
    final SharedPreferences? prefs = _prefs;
    final SyncApiClient? client = _client;
    if (prefs == null || client == null) return;

    final ShareImportResult? imported = await Navigator.push<ShareImportResult>(
      context,
      MaterialPageRoute<ShareImportResult>(
        builder: (BuildContext context) =>
            ShareImportPage(client: client, owner: owner, prefs: prefs),
      ),
    );
    if (imported == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.shareImportDone(
            owner.displayName,
            imported.importedPersons,
            imported.importedClasses,
            imported.importedPlans,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // ListPage behandelt die Safe Area selbst; außen darf kein zweiter
      // permanenter unterer iOS-Abstand entstehen.
      body: SafeArea(
        bottom: false,
        child: ListPage(
          title: l10n.shareBrowse,
          onRefresh: _signedIn && !_isDemo ? _refresh : null,
          children: <Widget>[
            if (_loading) const Center(child: LoadingIndicator()),
            if (_isDemo)
              _emptyState(
                  l10n.shareDemoNoShares, l10n.shareBrowseEmptySubtitle),
            if (!_isDemo && !_signedIn)
              _emptyState(l10n.shareBrowseLoginRequired,
                  l10n.shareBrowseLoginRequiredSubtitle),
            if (_signedIn && !_isDemo) ...<Widget>[
              // Die Suchzeile steht über allem: Sie ist der einzige Weg in
              // diese Liste – sowohl für einen Namen als auch für die zehn
              // Wörter einer Person.
              InputField(
                controller: _search,
                labelText: l10n.shareBrowseSearchHint,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (_isPassphrase) _openByUsername(_query);
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              // Erkannte Wortphrase: Dann ist der Text ein Nutzername, kein
              // Suchbegriff – und die Trefferliste darunter wäre irreführend
              // leer. Stattdessen wird der direkte Weg angeboten.
              if (_isPassphrase)
                _passphraseTile(l10n)
              else ...<Widget>[
                for (final ShareOwner person in _visiblePeople)
                  _personTile(l10n, person),
                if (_visiblePeople.isEmpty && _error == null)
                  _emptyState(
                    _query.isEmpty
                        ? l10n.shareBrowseEmpty
                        : l10n.shareBrowseNoMatch,
                    _query.isEmpty
                        ? l10n.shareBrowseEmptySubtitle
                        : l10n.shareBrowseSearchHint,
                  ),
              ],
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 40, 30, 20),
        child: Column(
          children: <Widget>[
            const Icon(Icons.group_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _personTile(AppLocalizations l10n, ShareOwner person) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              // Zuerst werden alle Shares dieser Person gezeigt – ein Klick auf
              // die Person öffnet die Liste, erst dort wählt man einen Share.
              onTap: () => _openShares(person),
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: const Icon(Icons.person_rounded),
              ),
              title: Text(person.displayName,
                  style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                l10n.shareOf(person.displayName),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w100,
                    color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ),
      );

  /// Der Eintrag, der erscheint, sobald in der Suchzeile eine Wortphrase
  /// steht: Er öffnet die Shares genau dieser Person.
  Widget _passphraseTile(AppLocalizations l10n) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _resolving ? null : () => _openByUsername(_query),
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: _resolving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: LoadingIndicator(size: 24),
                      )
                    : const Icon(Icons.key_rounded),
              ),
              title: Text(l10n.shareBrowseOpenByUsername,
                  style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                l10n.shareBrowseEnterUsernameSubtitle,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w100,
                    color: Colors.grey),
              ),
            ),
          ),
        ),
      );
}

/// Filtert das Verzeichnis nach [query] und sortiert es alphabetisch.
///
/// **Leerer Suchbegriff** heißt: alles anzeigen. So steht beim Öffnen
/// sofort die vollständige Liste der suchbaren Shares da, statt eines leeren
/// Bildschirms.
///
/// Gesucht wird in Anzeigename **und** Nutzername – wer nur einen der beiden
/// kennt, findet die Person trotzdem. Verglichen wird über
/// [NameGuard.normalize], also ohne Groß-/Kleinschreibung und ohne Diakritika.
///
/// Als eigene Funktion (statt inline im Widget), weil sich das Sortieren und
/// Filtern so unmittelbar prüfen lässt: Es braucht keinen Server.
List<ShareOwner> filterAndSortOwners(List<ShareOwner> people, String query) {
  final String needle = NameGuard.normalize(query.trim());
  final List<ShareOwner> matches = people.where((ShareOwner person) {
    if (needle.isEmpty) return true;
    return NameGuard.normalize(person.displayName).contains(needle) ||
        NameGuard.normalize(person.username).contains(needle);
  }).toList();

  // Alphabetisch nach dem Anzeigenamen; bei gleichem Namen entscheidet der
  // Nutzername, damit die Reihenfolge nicht von der Serverantwort abhängt.
  matches.sort((ShareOwner a, ShareOwner b) {
    final int byName =
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    return byName != 0
        ? byName
        : a.username.toLowerCase().compareTo(b.username.toLowerCase());
  });
  return matches;
}
