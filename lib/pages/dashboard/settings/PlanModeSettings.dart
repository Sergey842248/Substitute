import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/SchoolStorage.dart';

import '../../../models/ListPage.dart';

class PlanModeSettings extends StatefulWidget {
  const PlanModeSettings({Key? key}) : super(key: key);

  @override
  State<PlanModeSettings> createState() => _PlanModeSettingsState();
}

class _PlanModeSettingsState extends State<PlanModeSettings> {
  String _defaultPlanModePerson = 'auto';
  String _defaultPlanModeClass = 'auto';
  String _defaultPlanModePreview = 'auto';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _defaultPlanModePerson =
          prefs.getString(SchoolStorage.scopedKey(prefs, 'defaultPlanModePerson')) ??
              'auto';
      _defaultPlanModeClass =
          prefs.getString(SchoolStorage.scopedKey(prefs, 'defaultPlanModeClass')) ??
              'auto';
      _defaultPlanModePreview =
          prefs.getString(SchoolStorage.scopedKey(prefs, 'defaultPlanModePreview')) ??
              'auto';
    });
  }

  Future<void> _setDefaultPlanModePerson(String mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        SchoolStorage.scopedKey(prefs, 'defaultPlanModePerson'), mode);
    if (mounted) {
      setState(() {
        _defaultPlanModePerson = mode;
      });
    }
  }

  Future<void> _setDefaultPlanModeClass(String mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        SchoolStorage.scopedKey(prefs, 'defaultPlanModeClass'), mode);
    if (mounted) {
      setState(() {
        _defaultPlanModeClass = mode;
      });
    }
  }

  Future<void> _setDefaultPlanModePreview(String mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        SchoolStorage.scopedKey(prefs, 'defaultPlanModePreview'), mode);
    if (mounted) {
      setState(() {
        _defaultPlanModePreview = mode;
      });
    }
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
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
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
                            l10n.defaultPlanModePerson,
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            l10n.defaultPlanModePersonAutoSubtitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w100,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePersonAuto),
                        subtitle: Text(l10n.defaultPlanModePersonAutoSubtitle),
                        value: 'auto',
                        groupValue: _defaultPlanModePerson,
                        onChanged: (val) =>
                            _setDefaultPlanModePerson(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePersonLatest),
                        subtitle: Text(l10n.defaultPlanModePersonLatestSubtitle),
                        value: 'latest',
                        groupValue: _defaultPlanModePerson,
                        onChanged: (val) =>
                            _setDefaultPlanModePerson(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePersonToday),
                        subtitle: Text(l10n.defaultPlanModePersonTodaySubtitle),
                        value: 'today',
                        groupValue: _defaultPlanModePerson,
                        onChanged: (val) =>
                            _setDefaultPlanModePerson(val!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          margin: EdgeInsets.all(4),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Icon(Icons.view_agenda_rounded),
                        ),
                        title: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            l10n.defaultPlanModeClass,
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            l10n.defaultPlanModeClassAutoSubtitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w100,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModeClassAuto),
                        subtitle: Text(l10n.defaultPlanModeClassAutoSubtitle),
                        value: 'auto',
                        groupValue: _defaultPlanModeClass,
                        onChanged: (val) =>
                            _setDefaultPlanModeClass(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModeClassLatest),
                        subtitle: Text(l10n.defaultPlanModeClassLatestSubtitle),
                        value: 'latest',
                        groupValue: _defaultPlanModeClass,
                        onChanged: (val) =>
                            _setDefaultPlanModeClass(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModeClassToday),
                        subtitle: Text(l10n.defaultPlanModeClassTodaySubtitle),
                        value: 'today',
                        groupValue: _defaultPlanModeClass,
                        onChanged: (val) =>
                            _setDefaultPlanModeClass(val!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          margin: EdgeInsets.all(4),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Icon(Icons.visibility_rounded),
                        ),
                        title: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            l10n.defaultPlanModePreview,
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            l10n.defaultPlanModePreviewAutoSubtitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w100,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePreviewAuto),
                        subtitle: Text(l10n.defaultPlanModePreviewAutoSubtitle),
                        value: 'auto',
                        groupValue: _defaultPlanModePreview,
                        onChanged: (val) =>
                            _setDefaultPlanModePreview(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePreviewLatest),
                        subtitle: Text(l10n.defaultPlanModePreviewLatestSubtitle),
                        value: 'latest',
                        groupValue: _defaultPlanModePreview,
                        onChanged: (val) =>
                            _setDefaultPlanModePreview(val!),
                      ),
                      RadioListTile<String>(
                        title: Text(l10n.defaultPlanModePreviewToday),
                        subtitle: Text(l10n.defaultPlanModePreviewTodaySubtitle),
                        value: 'today',
                        groupValue: _defaultPlanModePreview,
                        onChanged: (val) =>
                            _setDefaultPlanModePreview(val!),
                      ),
                    ],
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
