import 'package:expandiware/main.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget title(BuildContext context) => Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/img/logo.png',
            width: MediaQuery.of(context).size.width * 0.2,
            color: Theme.of(context).focusColor,
          ),
          SizedBox(height: 15),
          Text(
            'Substitute',
            style: TextStyle(
              fontFamily: 'Crackman',
              fontSize: 40,
            ),
          ),
          SizedBox(height: 50),
          /* SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
              strokeWidth: 1,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'initialisiere App...',
            style: TextStyle(
              color: Theme.of(context).focusColor.withOpacity(0.5),
            ),
          ), */
          Text(
            'Welcome to Substitute',
          ),
        ],
      ),
    );

Future<bool> titleAction() async {
  // register the App
  return true;
}

Widget getStarded(BuildContext context) => Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/img/logo.png',
                width: MediaQuery.of(context).size.width * 0.08,
                color: Theme.of(context).focusColor,
              ),
              SizedBox(width: 15),
              Text(
                'Substitute',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Crackman',
                ),
              ),
            ],
          ),
          SizedBox(height: 50),
          Text(
            'The Substitution schedule for students based on Indiware',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Enjoy Substitute',
            style: TextStyle(
                // fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );

start() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('firstTime', false);
  runApp(MyApp());
}

Widget vplanLogin(BuildContext context) => Container();

Widget classes(BuildContext context) => Container();

Widget login(BuildContext context) => Container();

Widget news(BuildContext context) => Container();
