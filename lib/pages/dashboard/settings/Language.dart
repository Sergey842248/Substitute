import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(AppLocalizations.of(context)!.language),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                RadioListTile(
                  title: Text('English'),
                  value: 'en',
                  groupValue: _currentLanguage,
                  onChanged: (String? value) {
                    if (value != null) {
                      _changeLanguage(value);
                    }
                  },
                ),
                RadioListTile(
                  title: Text('Deutsch'),
                  value: 'de',
                  groupValue: _currentLanguage,
                  onChanged: (String? value) {
                    if (value != null) {
                      _changeLanguage(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
