import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/ListPage.dart';

class PlanSettings extends StatefulWidget {
  @override
  State<PlanSettings> createState() => _PlanSettingsState();
}

class _PlanSettingsState extends State<PlanSettings> {
  bool _showLessonTimes = false;
  bool _hideTeacher = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _showLessonTimes = prefs.getBool('showLessonTimes') ?? false;
      _hideTeacher = prefs.getBool('hideTeacher') ?? false;
    });
  }

  Future<void> _toggleLessonTimes(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showLessonTimes', value);
    setState(() {
      _showLessonTimes = value;
    });
  }

  Future<void> _toggleHideTeacher(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTeacher', value);
    setState(() {
      _hideTeacher = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: 'Plan Settings',
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
                        'Show Lesson Times',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'Display times for individual lessons in the plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    value: _showLessonTimes,
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
                        'Hide Teacher',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'Hide teacher names in the substitution plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w100,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    value: _hideTeacher,
                    onChanged: _toggleHideTeacher,
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