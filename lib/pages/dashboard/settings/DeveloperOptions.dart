import 'package:expandiware/models/Button.dart';
import 'package:expandiware/models/InputField.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../models/ListPage.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class DeveloperOptions extends StatelessWidget {
  void deleteOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setStringList('offlineVPData', []);
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> options = [
      {
        'title': 'Disable developer options',
        'actionText': 'Disable',
        'action': () => SharedPreferences.getInstance().then(
              (instance) => instance.setBool('developerOptions', false),
            ),
      },
      {
        'title': 'Delete offline substitution plan',
        'actionText': 'Delete',
        'action': deleteOfflineData,
      },
      {
        'title': 'Stop Background service',
        'actionText': 'Stop',
        'action': () =>
            FlutterBackgroundService().sendData({'action': 'stopService'}),
      },
      {
        'title': 'Clear all SharedPreferences',
        'actionText': 'Clear',
        'action': () => SharedPreferences.getInstance()
            .then((instance) => instance.clear()),
      },
      {
        'title': 'Remove Teacher abbreviations',
        'actionText': 'Remove',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('teacherShorts', '');
        },
      },
      {
        'title': 'Clear notified dates',
        'actionText': 'Clear',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setStringList('notified', []);
        },
      },
      {
        'title': 'Clear news feeds',
        'actionText': 'Clear',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('newsfeeds', '[]');
        },
      },
      {
        'title': 'Toggle Material You',
        'actionText': 'Toggle',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool('materialyou', !prefs.getBool('materialyou')!);
          Fluttertoast.showToast(
            msg:
                'prefs.getBool(\'materialyou\') => ${prefs.getBool('materialyou')}',
          );
        },
      },
      {
        'title': 'Delete lesson times',
        'actionText': 'Delete',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('lesson times', '[]');
        },
      },
      {
        'title': 'firstTime to true',
        'actionText': 'Set',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool('firstTime', true);
        },
      },
      {
        'title': 'Analysis code',
        'actionText': 'Enter',
        'action': () async {
          TextEditingController _controller = new TextEditingController();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text('Enter analysis code'),
              content: Container(
                alignment: Alignment.center,
                height: 100,
                child: InputField(
                  controller: _controller,
                  labelText: 'Analysis code',
                ),
              ),
              actions: [
                Button(
                  text: 'Enter',
                  onPressed: () async {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    if (_controller.text == 'JuIGZxo0Na') {
                      prefs.setBool('analysis', false);
                      Fluttertoast.showToast(msg: 'no analysis anymore');
                    } else {
                      Fluttertoast.showToast(msg: 'incorrect code');
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      },
    ];
    return Scaffold(
      body: ListPage(
        title: 'developer options',
        children: [
          ...options.map(
            (e) => Container(
              margin: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    e['title'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Button(
                    text: e['actionText'],
                    onPressed: e['action'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
