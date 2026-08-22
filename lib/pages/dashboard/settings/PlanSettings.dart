import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';

import '../../../models/ListPage.dart';
import './Lessons.dart';

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
    if (!(prefs.getBool('hidePersonsMigrated') ?? false)) {
      await prefs.remove('hidePersons');
      await prefs.setBool('hidePersonsMigrated', true);
    }
    setState(() {
      _hideLessonTimes = prefs.getBool('hideLessonTimes') ?? true;
      _hideTeacher = prefs.getBool('hideTeacher') ?? false;
      _hidePersons = prefs.getBool('hidePersons') ?? false;
    });
  }

  Future<void> _toggleLessonTimes(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideLessonTimes', value);
    setState(() {
      _hideLessonTimes = value;
    });
  }

  Future<void> _toggleHideTeacher(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTeacher', value);
    setState(() {
      _hideTeacher = value;
    });
  }

  Future<void> _toggleHidePersons(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hidePersons', value);
    setState(() {
      _hidePersons = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.planSettings,
          children: [
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: SwitchListTile(
                    secondary: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.access_time_rounded),
                    ),
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        _hideLessonTimes ? l10n.hideLessonTimes : l10n.showLessonTimes,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        _hideLessonTimes ? l10n.hideLessonTimesSubtitle : l10n.showLessonTimesSubtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    value: _hideLessonTimes,
                    onChanged: _toggleLessonTimes,
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: SwitchListTile(
                    secondary: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.hideTeacher,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.hideTeacherSubtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    value: _hideTeacher,
                    onChanged: _toggleHideTeacher,
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: SwitchListTile(
                    secondary: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.groups_outlined),
                    ),
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.hidePersons,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.hidePersonsSubtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    value: _hidePersons,
                    onChanged: _toggleHidePersons,
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: ListTile(
                    leading: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.schedule_rounded),
                    ),
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.lessonTimes,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        l10n.lessonTimesSubtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: Lessons(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
