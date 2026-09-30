import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

import '../../models/InputField.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingProcess.dart';
import 'ShareImportPage.dart';

/// Das Suchmenü: Wer in der eigenen Schule etwas geteilt hat.
///
/// Zwei Wege hinein:
///
/// * **Suchen** – alle Kolleginnen und Kollegen der eigenen Schulnummer, die
///   ihre Shares ausdrücklich als suchbar markiert haben. Von einer fremden
///   Schule kommt hier nichts: Der Server filtert nach Schulnummer, und ohne
///   Anmeldung gibt es keine Schulnummer.
/// * **Nutzername eingeben** – wenn man die zehn Wörter einer Person kennt,
///   kommt man auch ohne Suchmenü direkt zu deren Shares.
class ShareBrowsePage extends StatefulWidget {
  const ShareBrowsePage({Key? key}) : super(key: key);

  @override
  State<ShareBrowsePage> createState() => _ShareBrowsePageState();
}

class _ShareBrowsePageState extends State<ShareBrowsePage> {
  SharedPreferences? _prefs;
  SyncApiClient? _client;
  List<ShareOwner> _people = const <ShareOwner>[];

  bool _loading = true;
  bool _signedIn = false;
  bool _isDemo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

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

  Future<void> _enterUsername() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final String? username = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ShareUsernamePage(),
      ),
    );
    if (username == null || !mounted) return;

    // Die eingegebenen Wörter sind der Nutzername der anderen Person. Daraus
    // lässt sich deren Share-ID berechnen – der Server muss den Namen also
    // nie im Klartext speichern, um ihn auffindbar zu machen.
    //
    // Zwei IDs werden geprüft: die normale (Schulnummer der Besitzerin geht in
    // den Schlüssel ein) und die globale. Für die globale braucht man die
    // Schulnummer der anderen Person nicht – deshalb funktioniert sie von
    // jeder Schule aus.
    final String ownSchool =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber')) ??
            '';

    final List<ShareSummary> shares = <ShareSummary>[];
    final List<String> tried = <String>[];
    for (final ({String id, bool isGlobal}) candidate in <({String id, bool isGlobal})>[
      if (ownSchool.isNotEmpty)
        (id: ShareManager.shareIdFor(username, ownSchool), isGlobal: false),
      (id: ShareManager.globalShareIdFor(username), isGlobal: true),
    ]) {
      if (tried.contains(candidate.id)) continue;
      tried.add(candidate.id);
      try {
        final ShareRecord record = await _client!.fetchShare(candidate.id);
        shares.add(ShareSummary(
          id: record.id,
          username: username,
          displayName: username,
          label: '',
          isGlobal: record.isGlobal,
          hasPassword: record.hasPassword,
          updatedAt: record.updatedAt,
        ));
      } on SyncException {
        // Dieser Share existiert nicht – den nächsten Versuch.
        continue;
      }
    }

    if (!mounted) return;
    if (shares.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareErrorWrongCredentials)));
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
      body: SafeArea(
        child: ListPage(
          title: l10n.shareBrowse,
          onRefresh: _signedIn && !_isDemo ? _refresh : null,
          children: <Widget>[
            if (_loading) const Center(child: LoadingProcess()),
            if (_isDemo) _emptyState(l10n.shareDemoNoShares, l10n.shareBrowseEmptySubtitle),
            if (!_isDemo && !_signedIn)
              _emptyState(
                  l10n.shareBrowseLoginRequired, l10n.shareBrowseLoginRequiredSubtitle),
            if (_signedIn && !_isDemo) ...<Widget>[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              if (_people.isEmpty && _error == null)
                _emptyState(l10n.shareBrowseEmpty, l10n.shareBrowseEmptySubtitle),
              for (final ShareOwner person in _people) _personTile(l10n, person),
            ],
            if (_signedIn && !_isDemo) _usernameButton(l10n),
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

  Widget _usernameButton(AppLocalizations l10n) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _enterUsername,
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: const Icon(Icons.key_rounded),
              ),
              title: Text(l10n.shareBrowseEnterUsername,
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

/// Fragt die zehn Wörter einer anderen Person ab.
class ShareUsernamePage extends StatefulWidget {
  const ShareUsernamePage({Key? key}) : super(key: key);

  @override
  State<ShareUsernamePage> createState() => _ShareUsernamePageState();
}

class _ShareUsernamePageState extends State<ShareUsernamePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.shareBrowseEnterUsername,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                l10n.shareBrowseEnterUsernameSubtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            InputField(
              controller: _controller,
              labelText: l10n.shareUsername,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                    context, ShareManager.generateUsername()),
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: Text(l10n.sharePasswordGenerate,
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
              child: Text(l10n.shareImport,
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
