import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../models/ListPage.dart';
import '../../../main.dart';

class Language extends StatefulWidget {
  @override
  _LanguageState createState() => _LanguageState();
}

class _LanguageState extends State<Language> {
  String? _currentLanguage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguage = prefs.getString('languageCode') ?? 'en';
    });
  }

  void _changeLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    MyApp.setLocale(context, Locale(languageCode, ''));
    setState(() {
      _currentLanguage = languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.language,
          children: [
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: RadioListTile<String>(
                    value: 'en',
                    groupValue: _currentLanguage,
                    onChanged: (String? value) {
                      if (value != null) {
                        _changeLanguage(value);
                      }
                    },
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'English',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    secondary: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.language_rounded),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Container(
                margin: EdgeInsets.all(10),
                child: Center(
                  child: RadioListTile<String>(
                    value: 'de',
                    groupValue: _currentLanguage,
                    onChanged: (String? value) {
                      if (value != null) {
                        _changeLanguage(value);
                      }
                    },
                    title: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'Deutsch',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    secondary: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(Icons.location_on_rounded),
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
