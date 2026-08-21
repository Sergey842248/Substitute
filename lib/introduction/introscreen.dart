import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';

import 'package:expandiware/models/Button.dart';

import 'introTiles.dart';

Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.from(
    alpha: c.a,
    red: (c.r * f).clamp(0.0, 1.0),
    green: (c.g * f).clamp(0.0, 1.0),
    blue: (c.b * f).clamp(0.0, 1.0),
  );
}

class Introduction extends StatefulWidget {
  const Introduction({Key? key}) : super(key: key);

  @override
  _IntroductionState createState() => _IntroductionState();
}

class _IntroductionState extends State<Introduction> {
  @override
  Widget build(BuildContext context) {
    Color primaryColor = Color(0xffAF69EE); //1fbe88); // ECA44D
    int scaffoldBGDark = 70;

    final backgroundColor = Color(0xff1e1f25); //Color(0xff101012);
    final backgroundColorLight = Colors.grey.shade300;

    final primarySwatch = primaryColor;
    final primarySwatchLight = primaryColor;
    final dividerColor = Color(0xff0d0d0f);
    final dividerColorLight = Colors.white;

    final indicatorColor = primaryColor;
    final indicatorColorLight = primaryColor;

    return MaterialApp(
      title: 'Substitute',
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        primaryColor: primarySwatch,
        dividerColor: dividerColor,
        focusColor: Colors.white,
        indicatorColor: indicatorColor,
        colorScheme: ColorScheme.dark(
          error: Color.fromARGB(158, 119, 18, 18),
          surface: darken(backgroundColor, 5),
        ),
        scaffoldBackgroundColor: darken(backgroundColor, scaffoldBGDark),
        splashColor: Colors.white,
      ),
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.light,
        primaryColor: primarySwatchLight,
        indicatorColor: indicatorColorLight,
        focusColor: Colors.black,
        dividerColor: dividerColorLight,
        colorScheme: ColorScheme.light(
          error: Color.fromARGB(158, 119, 18, 18),
          surface: backgroundColorLight,
        ),
        scaffoldBackgroundColor: Colors.white,
        splashColor: Colors.black,
      ),
      home: Scaffold(
        body: SafeArea(child: Intro()),
      ),
    );
  }
}

class Intro extends StatefulWidget {
  const Intro({Key? key}) : super(key: key);

  @override
  _IntroState createState() => _IntroState();
}

class _IntroState extends State<Intro> {
  int pageCount = 0;

  bool ableToGoOn = false;

  void nextPage() {
    setState(() => pageCount++);
    ableToGoOn = false;
  }

  executeFun(Function fun) async {
    ableToGoOn = await fun();
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> pages = [
      [title(context), titleAction],
      [getStarded(context), () => start()],
      //[vplanLogin(context), () => true],
      /* [classes(context), () => true],
      [login(context), () => true],
      [news(context), () => true], */
    ];

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        // systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width * pages.length,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            left: -MediaQuery.of(context).size.width * pageCount,
            child: SvgPicture.asset(
              'assets/img/wave.svg',
              colorFilter: ColorFilter.mode(
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
                BlendMode.srcIn,
              ),
              width: MediaQuery.of(context).size.width * pages.length * 2,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            left: -MediaQuery.of(context).size.width * pageCount,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ...pages.map(
                  (e) => Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: e[0],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Button(
              text: pageCount == pages.length - 1
                  ? 'Start Substitute'
                  : 'Next',
              onPressed: () {
                executeFun(pages[pageCount][1]);
                nextPage();
              },
            ),
          ),
        ],
      ),
    );
  }
}
