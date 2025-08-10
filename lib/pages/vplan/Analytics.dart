import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import './VPlanAPI.dart';
import '../../models/LoadingProcess.dart';
import '../../models/ListItem.dart';

class Analytics extends StatefulWidget {
  Analytics({Key? key}) : super(key: key);

  @override
  _AnalyticsState createState() => _AnalyticsState();
}

class _AnalyticsState extends State<Analytics> {
  Widget content = LoadingProcess();
  final Analysis analysis = new Analysis();

  void getData(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? classes = prefs.getStringList('classes');

    if (classes == null || classes.isEmpty) {
      setState(() {
        content = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/nodata.json', height: 120),
              SizedBox(height: 20),
              Text(
                'No favorite classes found.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Please add a class to your favorites to see the analysis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      });
      return;
    }

    // Use the first favorite class for analysis
    String classId = classes.first;
    dynamic vplanData = await VPlanAPI().getLessonsForToday(classId);

    if (vplanData['error'] != null) {
      setState(() {
        content = Center(child: Text('Could not load VPlan data.'));
      });
      return;
    }

    var data = await analysis.analyseDay(vplanData['data'], context);
    setState(() {
      content = data;
    });
  }

  @override
  void initState() {
    super.initState();
    getData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).focusColor,
      ),
      body: SafeArea(
        child: Container(
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

class Analysis {
  final VPlanAPI vplanAPI = new VPlanAPI();

  Future<Widget> analyseDay(_data, context) async {
    if (_data == null || _data.isEmpty) {
      return Center(child: Text('No data for analysis available.'));
    }

    List<dynamic> teachers = [];

    for (int i = 0; i < _data.length; i++) {
      bool add = true;
      for (int j = 0; j < teachers.length; j++) {
        if (teachers[j]['name'] == _data[i]['teacher']) {
          add = false;
        }
      }
      if (add && _data[i]['teacher'] != null && _data[i]['teacher'] != '---') {
        teachers.add({
          'name': _data[i]['teacher'],
          'lessons': [],
        });
      }
    }

    for (int i = 0; i < _data.length; i++) {
      var lesson = _data[i];
      for (int y = 0; y < teachers.length; y++) {
        if (teachers[y]['name'] == lesson['teacher']) {
          teachers[y]['lessons'].add({
            'lesson': lesson['lesson'],
            'place': lesson['place'],
            'count': lesson['count'],
          });
        }
      }
    }
    
    teachers.sort((a, b) => a['name'].compareTo(b['name']));

    return ListView(
      physics: BouncingScrollPhysics(),
      children: [
        ...teachers.map(
          (e) => ListItem(
            margin: 10,
            padding: 15,
            color: Theme.of(context).backgroundColor,
            title: Text(
              'Teacher: ${e['name']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                ...e['lessons'].map(
                  (lesson) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                        '${lesson['count']}. Hour: ${lesson['lesson']} in Room: ${lesson['place']}'),
                  ),
                ),
              ],
            ),
            onClick: () {},
          ),
        ),
      ],
    );
  }
}
