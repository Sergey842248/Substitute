import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

import '../../../models/Button.dart';
import '../../../models/InputField.dart';
import '../../../models/ListPage.dart';
import '../../../models/LoadingProcess.dart';
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

  late List<String> _classes;
  late List<({String id, String name})> _persons;

  bool _searchable = true;
  bool _isGlobal = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classes = readClassShorts(widget.prefs);
    _persons = readPersons(widget.prefs);
    final LocalShare? share = widget.share;
    _selection = share?.selection ?? const ShareSelection();
    _labelController =
        TextEditingController(text: share?.label ?? _defaultLabel());
    _passwordController = TextEditingController(
      text: share == null || !share.hasPassword
          ? ''
          : (ShareManager.readSharePassword(widget.prefs) ?? ''),
    );
    _searchable = share?.searchable ?? true;
    _isGlobal = share?.isGlobal ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Ein Vorschlag, der die Auswahl benennt – ein Share ohne Namen ist in der
  /// Liste später nicht wiederzufinden.
  String _defaultLabel() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_selection.classIds.isEmpty && _selection.personIds.isEmpty) {
      return l10n.shareCreate;
    }
    if (_selection.classIds.length == 1) return _selection.classIds.first;
    return '${l10n.shareCreate} ${_selection.classIds.length}';
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
          isGlobal: _isGlobal,
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
          isGlobal: _isGlobal,
          selection: _selection,
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
        _error = '${l10n.syncFailed}: ${failure.message}';
      });
    }
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

    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: widget.share == null ? l10n.shareCreate : l10n.shareEdit,
          children: <Widget>[
            if (_busy) const Center(child: LoadingProcess()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),

            _sectionTitle(l10n.shareSelectClasses),
            if (_classes.isEmpty)
              _empty(l10n.noPersonsYet)
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
              Column(
                children: _persons
                    .map((({String id, String name}) person) => CheckboxListTile(
                          value: _selection.personIds.contains(person.id),
                          title: Text(person.name),
                          dense: true,
                          onChanged: (bool? value) =>
                              _togglePerson(person.id, value ?? false),
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
            _switchTile(
              l10n.shareGlobal,
              l10n.shareGlobalSubtitle,
              _isGlobal,
              (bool value) => setState(() => _isGlobal = value),
            ),
            if (_isGlobal)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  l10n.shareGlobalNote,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),

            _sectionTitle(l10n.sharePassword),
            _switchTile(
              l10n.sharePasswordOwn,
              l10n.sharePasswordSubtitle,
              _passwordController.text.trim().isNotEmpty,
              (bool value) => setState(() {
                if (value) {
                  _passwordController.text = ShareManager.generateSharePassword();
                } else {
                  _passwordController.clear();
                }
              }),
            ),
            if (_passwordController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: <Widget>[
                    InputField(
                      controller: _passwordController,
                      labelText: l10n.sharePasswordHint,
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

            _sectionTitle(l10n.shareIncludePlans),
            _switchTile(
              l10n.shareIncludePlans,
              l10n.shareIncludePlansSubtitle,
              _selection.includePlans,
              (bool value) =>
                  setState(() => _selection = _selection.copyWith(includePlans: value)),
            ),
            if (_selection.includePlans)
              _switchTile(
                l10n.shareIncludeHistory,
                l10n.shareIncludeHistorySubtitle(ShareManager.historyDays),
                _selection.includeHistory,
                (bool value) => setState(
                    () => _selection = _selection.copyWith(includeHistory: value)),
              ),
            _switchTile(
              l10n.shareIncludeSettings,
              l10n.shareIncludeSettingsSubtitle,
              _selection.includeSettings,
              (bool value) => setState(
                  () => _selection = _selection.copyWith(includeSettings: value)),
            ),

            _sectionTitle(l10n.shareLabel),
            InputField(
              controller: _labelController,
              labelText: l10n.shareLabelHint,
            ),

            Button(
              text: l10n.shareImport,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

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
                  personIds: _persons.map((({String id, String name}) p) => p.id).toSet(),
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
              child:
                  Text(l10n.shareSelectNothing, style: const TextStyle(fontSize: 13)),
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
