import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ListPage.dart';

class PlanSettings extends StatefulWidget {
  @override
  State<PlanSettings> createState() => _PlanSettingsState();
}

class _PlanSettingsState extends State<PlanSettings> {
  bool _showLessonTimes = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _showLessonTimes = prefs.getBool('showLessonTimes') ?? false;
    });
  }

  Future<void> _toggleLessonTimes(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showLessonTimes', value);
    setState(() {
      _showLessonTimes = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: AppLocalizations.of(context)!.planSettings,
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
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
                  AppLocalizations.of(context)!.showLessonTimes,
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  AppLocalizations.of(context)!.showLessonTimesSubtitle,
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
      ],
    );
  }
}