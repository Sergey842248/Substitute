import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

import '../../models/ListPage.dart';
import '../../models/LoadingProcess.dart';
import 'ShareListPage.dart';

/// Zeigt alle Shares einer Person und lässt einen davon importieren.
///
/// Der Ablauf entspricht der Anforderung: erst werden **alle** Shares der
/// Person aufgelistet, und erst wenn einer davon gewählt ist, öffnet sich die
/// Auswahl der Pläne und Personen.
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

class _ShareImportPageState extends State<ShareImportPage> {
  String? _selectedShareId;
  Map<String, dynamic>? _payload;
  ({int classes, int persons, int plans})? _counts;
  bool _busy = false;
  String? _error;
  bool _needsPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.owner.shares.length == 1) {
      _open(widget.owner.shares.first);
    }
  }

  String get _schoolNumber => widget.prefs.getString(
            SchoolStorage.scopedKey(widget.prefs, 'vplanSchoolnumber'),
          ) ??
      '';

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
      setState(() => _busy = true);
    }

    try {
      final Map<String, dynamic> payload = ShareManager.unlock(
        record,
        widget.owner.username,
        schoolNumber: _schoolNumber,
        sharePassword: sharePassword,
        schoolPassword:
            sharePassword == null && _schoolPassword.isNotEmpty
                ? _schoolPassword
                : null,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _counts = ShareManager.countContents(payload);
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

  Future<void> _import(ShareImportMode mode) async {
    final Map<String, dynamic>? payload = _payload;
    if (payload == null) return;
    setState(() => _busy = true);
    try {
      final ShareImportResult result = await ShareManager.applyImport(
        widget.prefs,
        payload,
        mode: mode,
        displayName: widget.owner.displayName,
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
        child: ListPage(
          title: l10n.shareOf(widget.owner.displayName),
          children: <Widget>[
            if (_busy) const Center(child: LoadingProcess()),
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
            // gewählt ist, wird er markiert – sonst ist nicht erkennbar, welcher
            // gerade geöffnet wird.
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

            // Schritt 2: Was steckt drin, und wie soll es importiert werden?
            if (payload != null && _counts != null) ...<Widget>[
              _sectionTitle(l10n.shareContents),
              _contentLine(l10n.shareContentsClasses(_counts!.classes)),
              _contentLine(l10n.shareContentsPersons(_counts!.persons)),
              _contentLine(l10n.shareContentsPlans(_counts!.plans)),
              _sectionTitle(l10n.shareImportModeTitle),
              _modeTile(
                l10n,
                ShareImportMode.original,
                l10n.shareImportModeOriginal,
                l10n.shareImportModeOriginalSubtitle,
              ),
              _modeTile(
                l10n,
                ShareImportMode.plans,
                l10n.shareImportModePlans,
                l10n.shareImportModePlansSubtitle,
              ),
              _modeTile(
                l10n,
                ShareImportMode.persons,
                l10n.shareImportModePersons,
                l10n.shareImportModePersonsSubtitle,
              ),
              const SizedBox(height: 30),
            ],
          ],
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
                child: Icon(
                  share.isGlobal ? Icons.public_rounded : Icons.folder_rounded,
                ),
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
                  if (share.isGlobal)
                    Text(l10n.shareBrowseGlobalOnly,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ),
      );

  Widget _modeTile(
    AppLocalizations l10n,
    ShareImportMode mode,
    String title,
    String subtitle,
  ) =>
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: ListTile(
              onTap: _busy ? null : () => _import(mode),
              leading: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(100)),
                child: Icon(switch (mode) {
                  ShareImportMode.original => Icons.copy_rounded,
                  ShareImportMode.plans => Icons.event_note_rounded,
                  ShareImportMode.persons => Icons.people_rounded,
                }),
              ),
              title: Text(title, style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w100,
                    color: Colors.grey),
              ),
            ),
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

  Widget _contentLine(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 2, 20, 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
}
