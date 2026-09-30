import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/NameGuard.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

import '../../../models/Button.dart';
import '../../../models/InputField.dart';
import '../../../models/ListPage.dart';
import '../../../models/LoadingProcess.dart';
import '../../../models/SettingsSwitchTile.dart';

import '../dashboard/settings/SyncSettings.dart';
import 'ShareEditPage.dart';

/// Die eigenen Shares.
///
/// Der Nutzername steht oben, weil er das Einzige ist, was andere wissen
/// müssen. Der Anzeigename darunter – er steht im Suchmenü der Schule, und
/// genau deshalb wird er geprüft.
class ShareListPage extends StatefulWidget {
  const ShareListPage({Key? key}) : super(key: key);

  @override
  State<ShareListPage> createState() => _ShareListPageState();
}

class _ShareListPageState extends State<ShareListPage> {
  SharedPreferences? _prefs;
  SyncApiClient? _client;
  List<LocalShare> _shares = const <LocalShare>[];
  String _username = '';
  String _displayName = '';
  bool _busy = false;

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
    await ShareManager.ensureIdentity(prefs);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _client = SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
      _shares = ShareManager.readShares(prefs);
      _username = ShareManager.readUsername(prefs) ?? '';
      _displayName = ShareManager.readDisplayName(prefs) ?? '';
    });
  }

  Future<void> _openEdit({LocalShare? share}) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ShareEditPage(
          client: SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs)),
          prefs: prefs,
          share: share,
        ),
      ),
    );
    if (created == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.sharePublished)));
    }
  }

  Future<void> _delete(LocalShare share) async {
    final SharedPreferences? prefs = _prefs;
    final SyncApiClient? client = _client;
    if (prefs == null || client == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shareDeleteConfirmTitle),
        content: Text(l10n.shareDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.shareDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    await ShareManager(client: client).remove(prefs, share.id);
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shareDeleted)));
  }

  Future<void> _editDisplayName() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final TextEditingController controller =
        TextEditingController(text: _displayName);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shareDisplayName),
        content: InputField(
          controller: controller,
          labelText: l10n.shareDisplayName,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null) return;

    // Die Prüfung passiert schon hier, damit der Grund direkt sichtbar ist und
    // nicht erst nach dem Speichern.
    final NameVerdict verdict = NameGuard.check(name);
    if (verdict.isBlocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (verdict.reason) {
            'tooShort' => l10n.shareNameTooShort,
            'tooLong' => l10n.shareNameTooLong,
            'empty' => l10n.shareNameEmpty,
            _ => l10n.shareNameBlocked,
          }),
        ),
      );
      return;
    }
    await ShareManager.setDisplayName(prefs, name);
    await _load();
  }

  Future<void> _copyUsername() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: _username));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.syncPassphraseCopied)),
    );
  }

  Future<void> _regenerateUsername() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shareUsernameRegenerateConfirmTitle),
        content: Text(l10n.shareUsernameRegenerateConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.shareUsernameRegenerate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final String fresh = ShareManager.generateUsername();
    await prefs.setString(ShareManager.usernameStorageKey, fresh);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.shareTitle,
          children: <Widget>[
            if (_busy || _prefs == null) const Center(child: LoadingProcess()),
            if (_prefs != null) ...<Widget>[
              _usernameTile(l10n),
              _displayNameTile(l10n),
              for (final LocalShare share in _shares) _shareTile(l10n, share),
              if (_shares.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.shareEmpty,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ),
              Button(
                text: l10n.shareCreate,
                onPressed: _busy ? null : () => _openEdit(),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _usernameTile(AppLocalizations l10n) => Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.person_rounded, size: 18),
                const SizedBox(width: 8),
                Text(l10n.shareUsername,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.shareUsernameSubtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            SelectableText(
              _username,
              style: const TextStyle(fontSize: 16, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _copyUsername,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l10n.syncPassphraseCopy,
                      style: const TextStyle(fontSize: 13)),
                ),
                TextButton.icon(
                  onPressed: _regenerateUsername,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l10n.shareUsernameRegenerate,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _displayNameTile(AppLocalizations l10n) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _editDisplayName,
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: const Icon(Icons.badge_rounded),
              ),
              title: Text(l10n.shareDisplayName,
                  style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                '$_displayName\n${l10n.shareDisplayNameSubtitle}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w100,
                    color: Colors.grey),
              ),
            ),
          ),
        ),
      );

  Widget _shareTile(AppLocalizations l10n, LocalShare share) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: () => _openEdit(share: share),
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: Icon(
                  share.isGlobal ? Icons.public_rounded : Icons.people_rounded,
                ),
              ),
              title: Text(share.displayLabel,
                  style: const TextStyle(fontSize: 18)),
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (share.searchable)
                    const Chip(
                      label: Text('searchable', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (share.isGlobal)
                    const Chip(
                      label: Text('global', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (share.hasPassword)
                    const Chip(
                      label: Text('password', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  Text(
                    '${share.selection.classIds.length} '
                    '${l10n.shareSelectClasses.toLowerCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _busy ? null : () => _delete(share),
              ),
            ),
          ),
        ),
      );
}

/// Hilfsfunktion, die die lokalen Klassen als Auswahl liefert – von der
/// Share-Seite und der Bearbeitungsseite gemeinsam benutzt.
List<String> readClassShorts(SharedPreferences prefs) {
  final List<String> raw =
      prefs.getStringList(SchoolStorage.scopedKey(prefs, 'classes')) ??
          const <String>[];
  final List<String> result = <String>[];
  for (final String entry in raw) {
    try {
      final Object? decoded = jsonDecode(entry);
      if (decoded is Map) {
        final String name = decoded['name']?.toString() ?? '';
        if (name.isNotEmpty) result.add(name);
      }
    } catch (_) {
      // Beschädigter Eintrag wird übersprungen.
      continue;
    }
  }
  return result;
}

/// Und die lokalen Personen als Auswahl.
List<({String id, String name})> readPersons(SharedPreferences prefs) {
  final List<String> raw =
      prefs.getStringList(SchoolStorage.scopedKey(prefs, 'persons')) ??
          const <String>[];
  final List<({String id, String name})> result =
      <({String id, String name})>[];
  for (final String entry in raw) {
    try {
      final Object? decoded = jsonDecode(entry);
      if (decoded is! Map) continue;
      final String id = decoded['id']?.toString() ?? '';
      final String name = decoded['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      result.add((id: id, name: name));
    } catch (_) {
      continue;
    }
  }
  return result;
}

/// Nur für die Fehleranzeige der Share-Seiten.
String shareErrorMessage(AppLocalizations l10n, String code) =>
    switch (code) {
      'nameBlocked' => l10n.shareNameBlocked,
      'noUsername' => l10n.shareErrorNoUsername,
      'nothingSelected' => l10n.shareErrorNothingSelected,
      'wrongCredentials' => l10n.shareErrorWrongCredentials,
      'unreadable' => l10n.shareErrorUnreadable,
      _ => syncErrorMessage(l10n, code),
    };

/// Wird von der Bearbeitungsseite genutzt, um einen Schalter zu zeichnen.
Widget shareSwitch({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) =>
    SettingsSwitchTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );
