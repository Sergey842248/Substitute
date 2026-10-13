import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/AppLanguage.dart';

import '../../../models/ListPage.dart';
import '../../../main.dart';

/// Die Sprachauswahl.
///
/// Drei Möglichkeiten, und die dritte ist die wichtigste: **der Systemsprache
/// folgen**. Sie steht deshalb oben und ist voreingestellt – wer nichts tut,
/// bekommt die Sprache seines Handys, und zwar auch dann noch, wenn er sie am
/// Gerät später umstellt.
///
/// Ist die Systemsprache eine, für die es keine Übersetzung gibt, nimmt die App
/// Deutsch. Nicht Englisch, und nicht „nichts anzeigen": Sie kann nur auf
/// Deutsch und Englisch.
class Language extends StatefulWidget {
  const Language({Key? key}) : super(key: key);

  @override
  _LanguageState createState() => _LanguageState();
}

class _LanguageState extends State<Language> {
  String? _currentChoice;

  @override
  void initState() {
    super.initState();
    _loadCurrentChoice();
  }

  Future<void> _loadCurrentChoice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentChoice = AppLanguage.read(prefs);
    });
  }

  Future<void> _changeLanguage(String choice) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppLanguage.storageKey, choice);
    if (!mounted) return;
    // Bei „der Systemsprache folgen" wird `null` gesetzt – das ist der Wert,
    // mit dem `MaterialApp` wieder die Systemsprache nimmt. Deshalb darf hier
    // nicht `Locale('system')` stehen: Das gäbe es als Sprache nicht.
    final Locale? locale = AppLanguage.forMaterialApp(prefs);
    MyApp.setLocale(context, locale);
    setState(() {
      _currentChoice = choice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? choice = _currentChoice;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListPage(
          title: l10n.language,
          children: <Widget>[
            _option(
              value: AppLanguage.system,
              groupValue: choice,
              title: l10n.languageSystem,
              subtitle: l10n.languageSystemSubtitle,
              icon: Icons.phone_android_rounded,
            ),
            _option(
              value: 'de',
              groupValue: choice,
              title: 'Deutsch',
              subtitle: l10n.languageGermanSubtitle,
              icon: Icons.location_on_rounded,
            ),
            _option(
              value: 'en',
              groupValue: choice,
              title: 'English',
              subtitle: l10n.languageEnglishSubtitle,
              icon: Icons.language_rounded,
            ),
          ],
        ),
      ),
    );
  }

  /// Eine der drei Möglichkeiten.
  Widget _option({
    required String value,
    required String? groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
  }) =>
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Center(
            child: RadioListTile<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: (String? code) {
                if (code != null) _changeLanguage(code);
              },
              title: Text(title, style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              secondary: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(icon),
              ),
            ),
          ),
        ),
      );
}
