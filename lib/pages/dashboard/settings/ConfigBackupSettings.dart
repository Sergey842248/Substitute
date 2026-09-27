import 'package:flutter/material.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/ConfigBackup.dart';
import 'package:substitute/services/ConfigBackupFlow.dart';

import '../../../models/ListPage.dart';
import '../../../models/LoadingProcess.dart';

/// Import/Export der gesamten App-Konfiguration: Einstellungen, Klassen,
/// Personen, Kurse und Zugangsdaten.
class ConfigBackupSettings extends StatefulWidget {
  const ConfigBackupSettings({Key? key}) : super(key: key);

  @override
  State<ConfigBackupSettings> createState() => _ConfigBackupSettingsState();
}

class _ConfigBackupSettingsState extends State<ConfigBackupSettings> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ConfigBackupFlow.export(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ConfigImportResult? result =
          await ConfigBackupFlow.importConfig(context);
      if (result != null && mounted) {
        ConfigBackupFlow.showResult(context, result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.backup,
          children: [
            if (_busy) const Center(child: LoadingProcess()),
            _tile(
              icon: Icons.file_upload_rounded,
              title: l10n.backupExport,
              subtitle: l10n.backupExportSubtitle,
              onTap: _busy ? null : _export,
            ),
            _tile(
              icon: Icons.file_download_rounded,
              title: l10n.backupImport,
              subtitle: l10n.backupImportSubtitle,
              onTap: _busy ? null : _import,
            ),
            _note(l10n.backupNote),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: ListTile(
            onTap: onTap,
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
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
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
}
