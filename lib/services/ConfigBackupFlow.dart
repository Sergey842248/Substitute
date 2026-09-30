import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/ConfigBackup.dart';

/// Antwort des Nutzers im Warn-Dialog vor dem Teilen.
enum _CredentialChoice { with_, without }

/// Export-/Import-Ablauf der Konfiguration.
///
/// Bewusst als freie Funktionen und nicht als Teil von
/// [ConfigBackupSettings]: Der Import wird auch auf der Anmeldeseite
/// gebraucht, damit ein Import gleich beim ersten Start der App möglich ist.
class ConfigBackupFlow {
  const ConfigBackupFlow._();

  /// Erzeugt die Exportdatei und öffnet das Teilen-Menü des Systems.
  /// Gibt true zurück, wenn erfolgreich exportiert wurde.
  ///
  /// Enthält die Konfiguration Zugangsdaten, wird vorher gefragt – der Nutzer
  /// kann dann entscheiden, ob er sie mit exportieren oder bewusst weglassen
  /// möchte. Mit [withCredentials] == false werden die Zugangsdaten von vornherein
  /// nicht exportiert und es kommt keine Rückfrage.
  static Future<bool> export(
    BuildContext context, {
    bool withCredentials = true,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var export = await ConfigBackup.buildExport(prefs,
          includeCredentials: withCredentials);

      if (withCredentials &&
          ConfigBackup.containsCredentials(
              export['settings'] as Map<String, dynamic>)) {
        final _CredentialChoice? choice =
            await _askAboutCredentials(context, l10n);
        if (choice == null) return false;
        if (choice == _CredentialChoice.without) {
          export = await ConfigBackup.buildExport(prefs,
              includeCredentials: false);
        }
      }

      final bool includesCredentials = ConfigBackup.containsCredentials(
          export['settings'] as Map<String, dynamic>);

      String version = '';
      try {
        version = (await PackageInfo.fromPlatform()).version;
      } catch (_) {}

      final Uint8List bytes = Uint8List.fromList(utf8.encode(
        ConfigBackup.encodeExport(export,
            exportedAt: DateTime.now(), appVersion: version),
      ));

      final String fileName = exportFileName();
      await SharePlus.instance.share(buildShareParams(
        bytes: bytes,
        fileName: fileName,
        subject: l10n.backupExportSubject,
        text: includesCredentials
            ? l10n.backupExportText
            : l10n.backupExportTextWithoutCredentials,
      ));
      return true;
    } catch (_) {
      if (context.mounted) _showMessage(context, l10n.backupFailed);
      return false;
    }
  }

  /// Liest eine Exportdatei ein und fragt, ob ersetzt oder ergänzt werden
  /// soll. Gibt das Ergebnis zurück oder null, wenn abgebrochen wurde.
  ///
  /// [askReplace] == false übernimmt die Datei ohne Rückfrage (z.B. auf der
  /// Anmeldeseite, wo es nichts Vorhandenes zu erhalten gibt).
  static Future<ConfigImportResult?> importConfig(
    BuildContext context, {
    bool askReplace = true,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: l10n.backupImport,
        type: FileType.any,
      );
    } catch (_) {
      if (context.mounted) _showMessage(context, l10n.backupImportFailed);
      return null;
    }
    // Leere Liste = Nutzer hat den Dialog abgebrochen.
    if (picked.isEmpty) return null;

    Uint8List? bytes;
    try {
      bytes = await picked.first.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      if (context.mounted) _showMessage(context, l10n.backupImportFailed);
      return null;
    }

    Map<String, dynamic> settings;
    try {
      settings = ConfigBackup.parseExport(utf8.decode(bytes));
    } on FormatException catch (e) {
      if (context.mounted) {
        _showMessage(context, _formatError(l10n, e));
      }
      return null;
    }

    bool replace = false;
    if (askReplace) {
      final bool? answer =
          await _askReplace(l10n, context: context);
      if (answer == null) return null;
      replace = answer;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ConfigImportResult result = await ConfigBackup.applyImport(
        prefs,
        settings,
        replace: replace,
      );

      // Die In-Memory-Caches leeren, damit die neuen Werte greifen.
      await loadDisplayCache(prefs);
      vplanBackgroundRefresh.value++;
      return result;
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, l10n.backupImportFailed);
      }
      return null;
    }
  }

  /// Baut die Parameter für das Teilen der Exportdatei.
  ///
  /// [fileNameOverrides] ist dabei entscheidend: Bei `XFile.fromData`
  /// ignoriert cross_file den im XFile angegebenen Namen auf allen Plattformen
  /// außer im Web und vergibt stattdessen eine zufällige ID als Dateinamen –
  /// die empfangene Datei hieße dann z.B. "3f2a9c….json" statt
  /// "Substitute-Export___2026-09-27___14-35-02.json". Erst der Override
  /// setzt den Namen tatsächlich durch.
  @visibleForTesting
  static ShareParams buildShareParams({
    required Uint8List bytes,
    required String fileName,
    required String subject,
    required String text,
  }) {
    return ShareParams(
      files: <XFile>[
        XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
      ],
      fileNameOverrides: <String>[fileName],
      subject: subject,
      text: text,
    );
  }

  /// Präfix, das jeder Exportdateiname trägt.
  static const String exportFileNamePrefix = 'Substitute-Export___';

  /// Dateiname des Exports: Präfix, Datum und Uhrzeit, z.B.
  /// `Substitute-Export___2026-09-27___14-35-02.json`.
  static String exportFileName({DateTime? at}) {
    final DateTime now = at ?? AppClock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final String date = '${now.year}-${two(now.month)}-${two(now.day)}';
    final String time = '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    return '${exportFileNamePrefix}${date}___$time.json';
  }

  /// Auswahl im Warn-Dialog: mit Zugangsdaten exportieren, ohne teilen oder
  /// abbrechen.
  static Future<_CredentialChoice?> _askAboutCredentials(
      BuildContext context, AppLocalizations l10n) async {
    return showDialog<_CredentialChoice>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.backupCredentialsTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: Text(l10n.backupCredentialsWarning, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _CredentialChoice.without),
            child: Text(l10n.backupShareWithoutCredentials),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _CredentialChoice.with_),
            child: Text(l10n.backupCredentialsContinue),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _askReplace(AppLocalizations l10n,
      {required BuildContext context}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.backupImportTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: Text(l10n.backupImportQuestion, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backupImportMerge),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.backupImportReplace),
          ),
        ],
      ),
    );
  }

  static String _formatError(AppLocalizations l10n, FormatException e) {
    switch (e.message) {
      case 'foreignApp':
        return l10n.backupErrorForeign;
      case 'futureSchema':
        return l10n.backupErrorFutureSchema;
      default:
        return l10n.backupImportFailed;
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void showResult(BuildContext context, ConfigImportResult result) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    _showMessage(
      context,
      l10n.backupImportDone(result.appliedKeys.length, result.removedKeys.length),
    );
  }
}
