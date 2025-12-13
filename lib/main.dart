import 'dart:io';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:expandiware/introduction/introscreen.dart';

import 'package:expandiware/models/Button.dart';
import 'package:expandiware/models/ModalBottomSheet.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import './android_colors.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import 'dart:convert';
import 'background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/* pages */
import 'pages/vplan/VPlan.dart';
import 'pages/teacherVPlan/TeacherVPlan.dart';
import 'pages/dashboard/Dashboard.dart';

Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
  return <String, dynamic>{
    'version.securityPatch': build.version.securityPatch,
    'version.sdkInt': build.version.sdkInt,
    'version.release': build.version.release,
    'version.previewSdkInt': build.version.previewSdkInt,
    'version.incremental': build.version.incremental,
    'version.codename': build.version.codename,
    'version.baseOS': build.version.baseOS,
    'board': build.board,
    'bootloader': build.bootloader,
    'brand': build.brand,
    'device': build.device,
    'display': build.display,
    'fingerprint': build.fingerprint,
    'hardware': build.hardware,
    'host': build.host,
    'id': build.id,
    'manufacturer': build.manufacturer,
    'model': build.model,
    'product': build.product,
    'supported32BitAbis': build.supported32BitAbis,
    'supported64BitAbis': build.supported64BitAbis,
    'supportedAbis': build.supportedAbis,
    'tags': build.tags,
    'type': build.type,
    'isPhysicalDevice': build.isPhysicalDevice,
    'androidId': build.androidId,
    'systemFeatures': build.systemFeatures,
  };
}

Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
  return <String, dynamic>{
    'name': data.name,
    'systemName': data.systemName,
    'systemVersion': data.systemVersion,
    'model': data.model,
    'localizedModel': data.localizedModel,
    'identifierForVendor': data.identifierForVendor,
    'isPhysicalDevice': data.isPhysicalDevice,
    'utsname.sysname:': data.utsname.sysname,
    'utsname.nodename:': data.utsname.nodename,
    'utsname.release:': data.utsname.release,
    'utsname.version:': data.utsname.version,
    'utsname.machine:': data.utsname.machine,
  };
}

void sendAppOpenData() async {
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  Map<String, dynamic> deviceData = <String, dynamic>{};
  dynamic logindata;

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? schoolnumber = prefs.getString('vplanSchoolnumber');
  schoolnumber ??= prefs.getString('customUrl');
  List<String>? classes = prefs.getStringList('classes');
  classes ??= [];
  try {
    if (Platform.isAndroid) {
      deviceData = _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
      logindata = {
        'schoolnumber': schoolnumber,
        'classes': classes.toString(),
        'device_id': deviceData['id'],
        'android_id': deviceData['androidId'],
        'model': deviceData['model'],
        'manufacturer': deviceData['manufacturer'],
        'os_version': 'Android ${deviceData['version.release']}',
        'last_security_update': deviceData['version.securityPatch'],
        'app_open_time': DateTime.now().toString(),
      };
    } else if (Platform.isIOS) {
      deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
    }
  } on PlatformException {
    deviceData = <String, dynamic>{'Error:': 'Failed to get platform version.'};
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  if (prefs.getBool('firstTime') == null ||
      prefs.getBool('firstTime') == true) {
    runApp(Introduction());
    return;
  }

  if (prefs.getBool('automaticLoad') == true ||
      prefs.getBool('automaticLoad') == null) {
    print('initialize background service');
    await initializeService();
  }
  if (!kDebugMode) sendAppOpenData();
  runApp(MyApp());
}

Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.fromARGB(c.alpha, (c.red * f).round(), (c.green * f).round(),
      (c.blue * f).round());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getLocale().then(setLocale);
  }

  Future<Locale> _getLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String languageCode = prefs.getString('languageCode') ?? 'en';
    return Locale(languageCode, '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getMaterialYouColor(),
      builder: (context, AsyncSnapshot<MaterialYouPalette?> snapshot) {
        Color primaryColor = Color(0xffAF69EE); //1fbe88); // ECA44D
        int scaffoldBGDark = snapshot.data?.neutral2.shade900 == null ? 50 : 70;

        final backgroundColor = snapshot.data?.neutral2.shade900 ??
            Color(0xff1e1f25); //Color(0xff101012);
        final backgroundColorLight =
            snapshot.data?.neutral2.shade100 ?? Colors.grey.shade300;

        final primarySwatch = snapshot.data?.accent1.shade200 ?? primaryColor;
        final primarySwatchLight =
            snapshot.data?.accent1.shade400 ?? primaryColor;
        final dividerColor =
            snapshot.data?.accent3.shade100 ?? Color(0xff0d0d0f);
        final dividerColorLight =
            snapshot.data?.accent3.shade100 ?? Colors.white;

        final indicatorColor = snapshot.data?.accent1.shade100 ?? primaryColor;

        final indicatorColorLight =
            snapshot.data?.accent1.shade100 ?? primaryColor;

        return MaterialApp(
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                textScaleFactor: 0.9,
              ),
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
          title: 'Substitute',
          darkTheme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.dark,
            primaryColor: primarySwatch,
            dividerColor: dividerColor,
            focusColor: Colors.white,
            indicatorColor: indicatorColor,
            errorColor: Color.fromARGB(158, 119, 18, 18),
            backgroundColor: darken(backgroundColor, 5), //Color(0xff161B28),
            scaffoldBackgroundColor: darken(backgroundColor, scaffoldBGDark),
            splashColor: snapshot.data == null ? Colors.white : Colors.black,
          ),
          theme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.light,
            primaryColor: primarySwatchLight,
            indicatorColor: indicatorColorLight,
            focusColor: Colors.black,
            errorColor: Color.fromARGB(158, 119, 18, 18),
            dividerColor: dividerColorLight,
            backgroundColor: backgroundColorLight, //Color(0xffe7e7e7),
            scaffoldBackgroundColor: Colors.white,
            splashColor: Colors.black,
          ),
          home: Scaffold(
            body: HomePage(),
          ),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final String? initialTab;

  const HomePage({Key? key, this.initialTab}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class HomePageWithVPlanTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomePage(initialTab: 'vplanStudents');
  }
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late String activeText;
  bool _hasCheckedForUpdates = false;

  @override
  void initState() {
    super.initState();
    eastereggController = AnimationController(vsync: this);
    // Set initial tab based on constructor parameter, default to vplanStudents
    activeText = widget.initialTab ?? 'vplanStudents';
  }

  void dispose() {
    eastereggController.dispose();
    super.dispose();
  }

  String version = 'loading...';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
    });
    checkForUpdates(context);
  }

  void checkForUpdates(BuildContext context) async {
    if (_hasCheckedForUpdates || version == 'loading...') return; // Check only once per app open
    _hasCheckedForUpdates = true;
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/Sergey842248/Substitute/releases/latest'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final latestVersion = jsonResponse['tag_name'].replaceAll('v', ''); // Assuming tags are like 'v1.2.3'

        if (latestVersion.compareTo(version) > 0) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              title: Row(
                children: [
                  Icon(Icons.system_security_update_outlined),
                  SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.newVersionAvailable),
                ],
              ),
              content: Text(AppLocalizations.of(context)!.newVersionMessage(latestVersion)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.later,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                Button(
                  text: AppLocalizations.of(context)!.download,
                  onPressed: () async {
                    String url = jsonResponse['assets'][0]['browser_download_url']; // Assuming the first asset is the APK
                    try {
                      await launch(url);
                    } catch (e) {
                      print('failed to launch URL: $e');
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        }
      } else {
        print('Failed to fetch latest release: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for updates: $e');
      return;
    }
  }

  void openVPLan(String _prefClass) {}

  void eastereggIconChange() {
    if (eastereggIcon.key == ValueKey(1)) {
      eastereggIcon = Image.asset(
        'assets/img/logo.png',
        key: ValueKey(2),
        color: Theme.of(context).focusColor,
        width: 100,
      );
    } else {
      eastereggIcon = LottieBuilder.asset(
        'assets/animations/bird.json',
        key: ValueKey(1),
      );
      Future.delayed(
        const Duration(milliseconds: 6140),
        eastereggIconChange,
      );
    }
    setState(() {});
  }

  late final AnimationController eastereggController;
  Widget eastereggIcon = SizedBox();

  @override
  Widget build(BuildContext context) {
    if (eastereggIcon.runtimeType == SizedBox)
      eastereggIcon = Image.asset(
        'assets/img/logo.png',
        width: 100,
        key: ValueKey(2),
        color: Theme.of(context).focusColor,
      );
    List<Map<String, dynamic>> pages = [
      {
        'key': 'vplanStudents',
        'text': AppLocalizations.of(context)!.vplanStudents,
        'index': 0,
        'icon': 'assets/img/home.svg',
        'widget': VPlan(),
      },
      {
        'key': 'vplanTeachers',
        'text': AppLocalizations.of(context)!.vplanTeachers,
        'index': 1,
        'icon': 'assets/img/person.svg',
        'widget': TeacherVPlan(),
      },
      {
        'key': 'dashboard',
        'text': AppLocalizations.of(context)!.dashboard,
        'index': 2,
        'icon': 'assets/img/dashboard.svg',
        'widget': Dashboard(),
      },
    ];
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    Widget activeWidget = Text('loading...');
    for (int i = 0; i < pages.length; i++) {
      if (pages[i]['key'] == activeText) {
        activeWidget = pages[i]['widget'];
      }
    }
    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                // APPBAR
                Container(
                  alignment: Alignment.topCenter,
                  color: Theme.of(context).backgroundColor,
                  height: MediaQuery.of(context).size.height * 0.2,
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          height: 45,
                          child: Text(
                            'Substitute',
                            style: TextStyle(
                              fontSize: 23,
                              color: Theme.of(context).focusColor,
                              fontFamily: 'Crackman',
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            // Implement developer mode logic here if needed in the future
                          },
                          child: Container(
                            alignment: Alignment.centerRight,
                            height: 45,
                            margin: EdgeInsets.only(
                              right: MediaQuery.of(context).size.width * 0.07,
                            ),
                            // padding: const EdgeInsets.all(10),
                            child: IconButton(
                              icon: Icon(Icons.more_horiz_rounded),
                              color: Colors.grey.shade400,
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ModalBottomSheet(
                                    title: AppLocalizations.of(context)!.appInfo,
                                    bigTitle: true,
                                    extraButton: {
                                      'onTap': () {
                                        Share.share(
                                          'Check out Substitute on Github: https://www.github.com/Sergey842248/Substitute',
                                        );
                                      },
                                      'child': const Icon(
                                        Icons.share_rounded,
                                        size: 18,
                                      ),
                                    },
                                    content: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 17,
                                                color: Colors.white, // Assuming default text color, adjust if needed
                                              ),
                                              children: [
                                                TextSpan(text: AppLocalizations.of(context)!.mainDeveloper),
                                                TextSpan(
                                                  text: AppLocalizations.of(context)!.developerName,
                                                  style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Theme.of(context).focusColor,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () => launch('https://github.com/Sergey842248'),
                                                ),
                                                TextSpan(text: '\n\n${AppLocalizations.of(context)!.formerDeveloper}'),
                                                TextSpan(
                                                  text: AppLocalizations.of(context)!.formerDeveloperName,
                                                  style: TextStyle(
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Theme.of(context).focusColor,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () => launch('https://github.com/badbryany'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        ...[
                                          {
                                            'name': AppLocalizations.of(context)!.openIssue,
                                            'link':
                                                'https://www.github.com/Sergey842248/Substitute/issues/new?template=bug_report.yml',
                                          },
                                          {
                                            'name': AppLocalizations.of(context)!.github,
                                            'link':
                                                'https://www.github.com/Sergey842248/Substitute',
                                          }
                                        ].map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: InkWell(
                                              onTap: () => launch(e['link']!),
                                              child: Text(
                                                '${e['name']}',
                                                style: TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Theme.of(context)
                                                          .focusColor,
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            AppLocalizations.of(context)!.version(version),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.centerLeft,
                          margin: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.1,
                          ),
                          height: 45,
                          width: 45,
                          child: InkWell(
                            onTap: eastereggIconChange,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                              child: eastereggIcon,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // CONTENT
                Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.14,
                  ),
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(45),
                      topRight: Radius.circular(45),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: activeWidget,
                  ),
                ),
                // FOOTER
                Positioned(
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      color: Theme.of(context).backgroundColor,
                    ),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.1,
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ...pages.map(
                          (e) => Container(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    activeText = e['key'];
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(7),
                                    child: SvgPicture.asset(
                                      e['icon'],
                                      color: activeText == e['key']
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).focusColor,
                                      width: 28,
                                    ),
                                  ),
                                ),
                                SvgPicture.asset(
                                  'assets/img/active.svg',
                                  width: 13,
                                  color: e['key'] == activeText
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
