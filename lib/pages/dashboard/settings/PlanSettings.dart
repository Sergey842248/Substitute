import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:page_transition/page_transition.dart';

import '../../../models/swipe_page_transition.dart';

import '../../../models/ListPage.dart';
import '../../../models/SettingsSwitchTile.dart';
import './PreviewSettings.dart';
import './Lessons.dart';
import './PlanModeSettings.dart';

class PlanSettings extends StatefulWidget {
  @override
  State<PlanSettings> createState() => _PlanSettingsState();
}

class _PlanSettingsState extends State<PlanSettings> {
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
    // One-time migration: older versions stored 'hidePersons' with a default
    // of OFF. Reset any stored value once so the new default applies.
    if (!(prefs
            .getBool(SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated')) ??
        false)) {
      await prefs.remove(SchoolStorage.scopedKey(prefs, 'hidePersons'));
      await prefs.setBool(
          SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated'), true);
    }
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

  Future<void> _toggleLessonTimes(bool hideLessonTimes) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        SchoolStorage.scopedKey(prefs, 'hideLessonTimes'), hideLessonTimes);
    setState(() {
      _hideLessonTimes = hideLessonTimes;
    });
  }

  Future<void> _toggleHideTeacher(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SchoolStorage.scopedKey(prefs, 'hideTeacher'), value);
    setState(() {
      _hideTeacher = value;
    });
  }

  Future<void> _toggleHidePersons(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SchoolStorage.scopedKey(prefs, 'hidePersons'), value);
    setState(() {
      _hidePersons = value;
    });
  }

  /// Eintrag, der eine weitere Einstellungsseite öffnet.
  Widget _entryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: ListTile(
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
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: page,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.planSettings,
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
              onChanged: _toggleHideTeacher,
            ),
            SettingsSwitchTile(
              icon: Icons.groups_outlined,
              title: l10n.hidePersons,
              subtitle: l10n.hidePersonsSubtitle,
              value: _hidePersons,
              onChanged: _toggleHidePersons,
            ),
            _entryTile(
              icon: Icons.visibility_rounded,
              title: l10n.previewSettings,
              subtitle: l10n.previewSettingsSubtitle,
              page: const PreviewSettings(),
            ),
            _entryTile(
              icon: Icons.view_agenda_rounded,
              title: l10n.defaultPlanModePreviewEntryTitle,
              subtitle: l10n.defaultPlanModePreviewEntrySubtitle,
              page: const PlanModeSettings(),
            ),
            _entryTile(
              icon: Icons.schedule_rounded,
              title: l10n.lessonTimes,
              subtitle: l10n.lessonTimesSubtitle,
              page: Lessons(),
            ),
          ],
        ),
      ),
    );
  }
}
