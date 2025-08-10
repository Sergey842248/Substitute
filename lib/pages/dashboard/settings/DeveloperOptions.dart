import 'package:expandiware/models/Button.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../models/ListPage.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class DeveloperOptions extends StatefulWidget {
  void deleteOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setStringList('offlineVPData', []);
  }

  @override
  _DeveloperOptionsState createState() => _DeveloperOptionsState();
}

class _DeveloperOptionsState extends State<DeveloperOptions> {
  bool _isAnalysisEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysisStatus();
  }

  Future<void> _loadAnalysisStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAnalysisEnabled = prefs.getBool('analysis') ?? false;
    });
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
        'action': widget.deleteOfflineData,
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
        'title': 'Toggle Analysis',
        'actionText': _isAnalysisEnabled ? 'Disable' : 'Enable',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool currentStatus = prefs.getBool('analysis') ?? false;
          await prefs.setBool('analysis', !currentStatus);
          setState(() {
            _isAnalysisEnabled = !currentStatus;
          });
          Fluttertoast.showToast(
            msg: currentStatus ? 'Analysis disabled' : 'Analysis enabled',
            toastLength: Toast.LENGTH_SHORT,
          );
        },
      },
    ];
    return Scaffold(
      body: ListPage(
        title: 'Developer options',
        children: [
          // ... other options
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
