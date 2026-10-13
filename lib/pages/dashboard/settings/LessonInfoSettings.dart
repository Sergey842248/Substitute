import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';

import '../../../models/ListPage.dart';
import '../../../models/SettingsSwitchTile.dart';

/// Untermenü der Plan-Einstellungen: Welche Angaben der Vertretungsplan zeigt.
///
/// Hier stehen die drei Schalter, die alle dasselbe betreffen – **welche
/// Informationen zu einer Stunde sichtbar sind** (Zeiten, Lehrername) bzw.
/// **was daneben noch erscheint** (der Personenbereich der Übersicht). Sie
/// standen früher direkt in den Plan-Einstellungen und haben die Seite mit
/// einer bunten Mischung aus Ansichts- und Inhaltsfragen gefüllt.
///
/// Die Einstellungen selbst bleiben unverändert gespeichert; verschoben wurde
/// nur, wo man sie findet. Ein bereits gesetzter Wert bleibt also erhalten.
class LessonInfoSettings extends StatefulWidget {
  const LessonInfoSettings({Key? key}) : super(key: key);

  @override
  State<LessonInfoSettings> createState() => _LessonInfoSettingsState();
}

class _LessonInfoSettingsState extends State<LessonInfoSettings> {
  bool _hideLessonTimes = true;
  bool _hideTeacher = false;
  bool _hidePersons = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // One-time migration: ältere Versionen speicherten 'hidePersons' mit
    // einem Standard von AUS. Einmal zurücksetzen, damit der neue Standard
    // gilt. Siehe PlanSettings.
    if (!(prefs
            .getBool(SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated')) ??
        false)) {
      await prefs.remove(SchoolStorage.scopedKey(prefs, 'hidePersons'));
      await prefs.setBool(
          SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated'), true);
    }
    if (!mounted) return;
    setState(() {
      _hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
      _hideTeacher =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideTeacher')) ?? false;
      _hidePersons =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hidePersons')) ?? false;
    });
  }

  Future<void> _set(String key, bool value, void Function(bool) apply) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SchoolStorage.scopedKey(prefs, key), value);
    if (!mounted) return;
    setState(() => apply(value));
  }

  Future<void> _toggleLessonTimes(bool v) =>
      _set('hideLessonTimes', v, (bool x) => _hideLessonTimes = x);

  Future<void> _toggleTeacher(bool v) =>
      _set('hideTeacher', v, (bool x) => _hideTeacher = x);

  Future<void> _togglePersons(bool v) =>
      _set('hidePersons', v, (bool x) => _hidePersons = x);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListPage(
          title: l10n.lessonInfoSettings,
          children: [
            SettingsSwitchTile(
              icon: Icons.access_time_rounded,
              title: l10n.hideLessonTimes,
              subtitle: l10n.hideLessonTimesSubtitle,
              value: _hideLessonTimes,
              onChanged: _toggleLessonTimes,
            ),
            SettingsSwitchTile(
              icon: Icons.person_outline_rounded,
              title: l10n.hideTeacher,
              subtitle: l10n.hideTeacherSubtitle,
              value: _hideTeacher,
              onChanged: _toggleTeacher,
            ),
            SettingsSwitchTile(
              icon: Icons.groups_outlined,
              title: l10n.hidePersons,
              subtitle: l10n.hidePersonsSubtitle,
              value: _hidePersons,
              onChanged: _togglePersons,
            ),
          ],
        ),
      ),
    );
  }
}
