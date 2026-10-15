import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/services/AppColors.dart';
import 'package:substitute/services/crypto/Passphrase.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';
import 'package:substitute/services/sync/SyncEngine.dart';

/// Destruktive Server-Werkzeuge fuer Entwicklung und Support.
///
/// Shares haben keinen separaten Benutzer-Datensatz: Der Benutzer ist die
/// gemeinsame Owner-Angabe seiner Shares. Das Entfernen aller zu einem
/// Nutzernamen gehoerenden Share-IDs entfernt ihn daher vollstaendig aus dem
/// Verzeichnis. Sync-Ketten sind absichtlich nicht an Shares gekoppelt und
/// werden mit ihrer Passphrase gezielt entfernt.
class DeleteShares extends StatefulWidget {
  const DeleteShares({super.key});

  @override
  State<DeleteShares> createState() => _DeleteSharesState();
}

class _DeleteSharesState extends State<DeleteShares> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _syncCode = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _syncCode.dispose();
    super.dispose();
  }

  Future<SyncApiClient> _client() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SyncApiClient(baseUrl: SyncEngine.serverUrl(prefs));
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: TextStyle(color: AppColors.aktionston(context))),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteUserShares() async {
    final String username = Passphrase.normalize(_username.text);
    if (username.isEmpty) {
      setState(() => _message = 'Enter the user name first.');
      return;
    }
    if (!await _confirm(
      'Delete this user’s shares?',
      'All shares belonging to this user will be deleted. This cannot be undone.',
    )) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    final SyncApiClient client = await _client();
    int deleted = 0;
    try {
      deleted = await client.deleteSharesForUsername(username);
      if (mounted) setState(() => _message = '$deleted share(s) deleted.');
    } on SyncException catch (error) {
      if (mounted)
        setState(() => _message = 'Could not delete shares: ${error.message}');
    } finally {
      client.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSyncChain() async {
    final String code = Passphrase.normalize(_syncCode.text);
    if (code.isEmpty) {
      setState(() => _message = 'Enter the sync code first.');
      return;
    }
    if (!await _confirm(
      'Delete this sync chain?',
      'Every device snapshot in this sync chain will be deleted from the server.',
    )) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    final SyncApiClient client = await _client();
    try {
      await client.deleteChain(SyncEngine.chainIdFor(code));
      if (mounted) setState(() => _message = 'Sync chain deleted.');
    } on SyncException catch (error) {
      if (mounted)
        setState(
            () => _message = 'Could not delete sync chain: ${error.message}');
    } finally {
      client.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
          {required String label, required TextEditingController controller}) =>
      TextField(
        controller: controller,
        enabled: !_busy,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListPage(
          title: 'Delete Shares',
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'These tools delete data for any user, including users from other schools. They only affect the server; local copies on other devices remain until their next sync.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child:
                  _field(label: 'User name (ten words)', controller: _username),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: FilledButton.icon(
                onPressed: _busy ? null : _deleteUserShares,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete user shares'),
              ),
            ),
            const Divider(height: 40),
            Padding(
              padding: const EdgeInsets.all(10),
              child:
                  _field(label: 'Sync code (ten words)', controller: _syncCode),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: FilledButton.icon(
                onPressed: _busy ? null : _deleteSyncChain,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Delete sync chain'),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
          ],
        ),
      );
}
