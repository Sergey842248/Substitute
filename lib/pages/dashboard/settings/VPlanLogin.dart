import 'dart:convert';

import 'package:substitute/models/Button.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';
import '../../../models/swipe_page_transition.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/ListPage.dart';
import '../../../models/InputField.dart';

import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../models/QRScanner.dart';
import '../../../main.dart';
import '../../../services/SchoolStorage.dart';

class VPlanLogin extends StatefulWidget {
  /// Wenn true (z.B. beim ersten App-Start, solange noch keine Zugangsdaten
  /// hinterlegt sind), ist die Seite eine Pflicht-Anmeldung: Der Zurück-Pfeil
  /// und die iOS-Back-Geste sind deaktiviert, damit man ohne Zugangsdaten
  /// nicht aus der Seite herauskommt. Beim normalen Ändern der Zugangsdaten
  /// bleibt das Zurückgehen dagegen möglich.
  final bool blockBack;

  const VPlanLogin({Key? key, this.blockBack = false}) : super(key: key);

  @override
  State<VPlanLogin> createState() => _VPlanLoginState();
}

class _VPlanLoginState extends State<VPlanLogin> {
  TextEditingController schoolnumberController = new TextEditingController();
  TextEditingController usernameController = new TextEditingController();
  TextEditingController passwordController = new TextEditingController();

  TextEditingController customUrlController = new TextEditingController();

  String schoolnumber = '';

  String username = '';

  String password = '';

  @override
  void initState() {
    super.initState();
    getLoginData();
  }

  void getLoginData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String schoolnumberKey =
        SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber');
    final String usernameKey = SchoolStorage.scopedKey(prefs, 'vplanUsername');
    final String passwordKey = SchoolStorage.scopedKey(prefs, 'vplanPassword');
    final String customUrlKey = SchoolStorage.scopedKey(prefs, 'customUrl');

    schoolnumberController.text = prefs.getString(schoolnumberKey) == null
        ? ''
        : prefs.getString(schoolnumberKey)!;

    usernameController.text = prefs.getString(usernameKey) == null
        ? ''
        : prefs.getString(usernameKey)!;

    passwordController.text = prefs.getString(passwordKey) == null
        ? ''
        : prefs.getString(passwordKey)!;

    customUrlController.text = prefs.getString(customUrlKey) == null
        ? ''
        : prefs.getString(customUrlKey)!;

    if (customUrlController.text != '') {
      setState(() => customUrlField = true);
    }
  }

  void setData(dynamic data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic jsonData = {};
    try {
      jsonData = jsonDecode(data);
    } catch (e) {
      return;
    }
    prefs.setString(SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber'),
        jsonData['schoolnumber']);
    prefs.setString(
        SchoolStorage.scopedKey(prefs, 'vplanUsername'), jsonData['username']);
    prefs.setString(
        SchoolStorage.scopedKey(prefs, 'vplanPassword'), jsonData['password']);

    prefs.setString(
        SchoolStorage.scopedKey(prefs, 'customUrl'), jsonData['customUrl']);

    schoolnumberController.text = jsonData['schoolnumber'];
    usernameController.text = jsonData['username'];
    passwordController.text = jsonData['password'];

    customUrlController.text = jsonData['customUrl'];
  }

  /// Öffnet ein Auswahl-Menü, um die Sprache direkt auf der Anmeldeseite zu
  /// wechseln (wichtig, solange die Seite als Pflicht-Anmeldung beim ersten
  /// App-Start angezeigt wird).
  void _showLanguageSheet() {
    final String currentLanguage =
        Localizations.localeOf(context).languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          color: Theme.of(context).colorScheme.surface,
        ),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              width: 100,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Theme.of(context).indicatorColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                AppLocalizations.of(context)!.language,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.language_rounded),
              title: Text('English'),
              trailing: currentLanguage == 'en'
                  ? Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                _setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on_rounded),
              title: Text('Deutsch'),
              trailing: currentLanguage == 'de'
                  ? Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                _setLanguage('de');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Speichert die Sprache und wendet sie sofort auf die ganze App an.
  void _setLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    MyApp.setLocale(context, Locale(languageCode, ''));
  }

  bool customUrlField = false;

  @override
  Widget build(BuildContext context) {
    List<dynamic> inputs = [
      {
        'hintText': AppLocalizations.of(context)!.schoolNumber,
        'controller': schoolnumberController,
        'numeric': true,
      },
      {
        'hintText': AppLocalizations.of(context)!.username,
        'controller': usernameController,
        'numeric': false,
      },
      {
        'hintText': AppLocalizations.of(context)!.password,
        'controller': passwordController,
        'numeric': false,
      },
    ];

    Widget _inputs = Column(
      children: inputs
          .map(
            (e) => InputField(
              controller: e['controller'],
              labelText: e['hintText'],
              keaboardType: e['numeric'] ? TextInputType.number : null,
            ),
          )
          .toList(),
    );

    if (customUrlField) {
      _inputs = InputField(
          controller: customUrlController,
          labelText: AppLocalizations.of(context)!.selfHost);
    }

    return PopScope(
      canPop: !widget.blockBack,
      child: Scaffold(
      body: ListPage(
        title: AppLocalizations.of(context)!.settingsCredentials,
        showBackButton: !widget.blockBack,
        actions: [
          IconButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              String schoolnumber = prefs.getString(
                      SchoolStorage.scopedKey(prefs, "vplanSchoolnumber")) ??
                  '';
              String vplanUsername = prefs.getString(
                      SchoolStorage.scopedKey(prefs, "vplanUsername")) ??
                  '';
              String vplanPassword = prefs.getString(
                      SchoolStorage.scopedKey(prefs, "vplanPassword")) ??
                  '';

              String customUrl = prefs
                      .getString(SchoolStorage.scopedKey(prefs, "customUrl")) ??
                  '';

              dynamic data = {
                'schoolnumber': schoolnumber,
                'username': vplanUsername,
                'password': vplanPassword,
                'customUrl': customUrl,
              };

              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                enableDrag: true,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Container(
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.topCenter,
                          width: double.infinity,
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            width: 100,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: Theme.of(context).indicatorColor,
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.center,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.shareCreds,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(height: 25),
                              Container(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: PrettyQr(
                                    size: 250,
                                    data: jsonEncode(data),
                                    elementColor: Colors.black,
                                    errorCorrectLevel: QrErrorCorrectLevel.H,
                                    typeNumber: 10,
                                    roundEdges: false,
                                    image: AssetImage('assets/img/logo.png'),
                                  ),
                                ),
                              ),
                              SizedBox(height: 25),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 200,
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    color: Theme.of(context).indicatorColor,
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!.save,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.share_rounded,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: QRScanner(setData: setData),
              ),
            ),
            icon: Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            onPressed: _showLanguageSheet,
            icon: Icon(Icons.language_rounded),
          ),
        ],
        children: [
          Container(
            margin: const EdgeInsets.only(left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: child,
                  ),
                  child: _inputs,
                ),

                // CUSTOM URL
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  child: InkWell(
                    onTap: () =>
                        setState(() => customUrlField = !customUrlField),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              height: 1.4,
                              color: Theme.of(context)
                                  .focusColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                customUrlField
                                    ? AppLocalizations.of(context)!.useLogin
                                    : AppLocalizations.of(context)!.useSelfHost,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .focusColor
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1.4,
                              color: Theme.of(context)
                                  .focusColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // CUSTOM URL

                Button(
                  text: AppLocalizations.of(context)!.save,
                  onPressed: () async {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();

                    prefs.setString(
                      SchoolStorage.scopedKey(prefs, 'vplanSchoolnumber'),
                      schoolnumberController.text.toString(),
                    );
                    prefs.setString(
                      SchoolStorage.scopedKey(prefs, 'vplanUsername'),
                      usernameController.text.toString(),
                    );
                    prefs.setString(
                      SchoolStorage.scopedKey(prefs, 'vplanPassword'),
                      passwordController.text.toString(),
                    );
                    if (!customUrlField) {
                      prefs.setString(
                          SchoolStorage.scopedKey(prefs, "customUrl"), '');
                    } else {
                      prefs.setString(
                        SchoolStorage.scopedKey(prefs, "customUrl"),
                        customUrlController.text.toString(),
                      );
                    }
                    Fluttertoast.showToast(
                        msg: AppLocalizations.of(context)!.credsSaved);
                    // Always navigate back to VPlan tab after saving credentials
                    // This fixes the issue where classes load infinitely after adding credentials
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => HomePageWithVPlanTab(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
