import 'package:expandiware/models/ModalBottomSheet.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import '../../../models/ListItem.dart';
import '../../../models/ListPage.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Lessons extends StatefulWidget {
  Lessons({Key? key}) : super(key: key);

  @override
  _LessonsState createState() => _LessonsState();
}

class _LessonsState extends State<Lessons> {
  TextStyle textStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 19,
  );
  double spaceBetween = 5;

  bool saved = false;
  bool changed = false;

  List<dynamic> lessons = [];

  String printTime(int _hour, int _minute) {
    TimeOfDay time = TimeOfDay(hour: _hour, minute: _minute);

    String hour = time.hour < 10 ? '0${time.hour}' : '${time.hour}';
    String minute = time.minute < 10 ? '0${time.minute}' : '${time.minute}';
    return '$hour:$minute';
  }

  setTime(int index, List<String> string) async {
    changed = true;
    saved = false;

    for (int i = 0; i < string.length; i++) {
      TimeOfDay initTime = toTimeOfDay(lessons[index][string[i]]);
      if (index != 0) {
        String foo = (i == 0 ? 'end' : 'start');
        initTime = toTimeOfDay(lessons[index - 1][foo]);
      }
      if (string[i] == 'end') {
        initTime = toTimeOfDay(lessons[index]['start']);
      }
      print(initTime);
      String newTime = (await showTimePicker(
        context: context,
        initialTime: initTime,
        hourLabelText: 'Hour',
        minuteLabelText: 'Minute',
        cancelText: 'Cancel',
        confirmText: 'OK',
        helpText:
            'Set ${string[i].replaceFirst(string[i][0], string[i][0].toUpperCase())} for ${lessons[index]['count']}.lesson',
      ))
          .toString();

      if (newTime != 'null') {
        lessons[index][string[i]] = newTime;
      }
    }
    setState(() {});
  }

  TimeOfDay toTimeOfDay(String time) {
    time = time.replaceAll('TimeOfDay(', '');
    time = time.replaceAll(')', '');

    return TimeOfDay(
      hour: int.parse(time.split(':')[0]),
      minute: int.parse(time.split(':')[1]),
    );
  }

  getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString('lessontimes') == null) {
      prefs.setString('lessontimes', '[]');
    }
    lessons = jsonDecode(prefs.getString('lessontimes')!);
    setState(() {});
  }

  isSaved(BuildContext context) {
    if (!saved && changed) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => ModalBottomSheet(
          title: 'Forgot to save?',
          bigTitle: true,
          submitButtonText: 'Save',
          onPop: () {
            save();
            Navigator.pop(context);
            Navigator.pop(context);
            setState(() {});
          },
          extraButton: {
            'onTap': () {
              Navigator.pop(context);
              Navigator.pop(context);
              setState(() {});
            },
            'child': Text('don\'t save' ),
          },
          content: Container(
            margin: EdgeInsets.only(
              left: MediaQuery.of(context).size.width * 0.2,
              right: MediaQuery.of(context).size.width * 0.2,
            ),
            child: Text(
              'If you don\'t save, the changes will be lost.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.pop(context);
    setState(() {});
  }

  reorderLessons() {
    for (var i = 0; i < lessons.length; i++) {
      lessons[i]['count'] = i + 1;
    }
  }

  save() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('lessontimes', jsonEncode(lessons));

    saved = true;
    setState(() {});
    Fluttertoast.cancel();
    Fluttertoast.showToast(msg: 'Times saved');
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListPage(
        title: 'Lesson times',
        onPop: () => isSaved(context),
        actions: [
          /* IconButton(
            onPressed: () {},
            icon: Icon(Icons.share),
          ), */
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            ),
            child: IconButton(
              key: ValueKey(saved),
              onPressed: save,
              icon: Icon(saved ? Icons.save : Icons.save_outlined),
            ),
          ),
        ],
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.11 * lessons.length,
            child: ReorderableList(
              physics: const BouncingScrollPhysics(),
              /* onReorderStart: (index) {
                print(index); // make item bigger
              }, */
              itemBuilder: (context, index) => Container(
                key: ValueKey(lessons[index]['count']),
                child: ListItem(
                  title: Row(
                    children: [
                      Text('From:'),
                      SizedBox(width: spaceBetween),
                      GestureDetector(
                        onTap: () => setTime(index, ['start']),
                        child: Text(
                          printTime(
                            toTimeOfDay(lessons[index]['start']).hour,
                            toTimeOfDay(lessons[index]['start']).minute,
                          ),
                          style: textStyle,
                        ),
                      ),
                      SizedBox(width: spaceBetween * 5),
                      Text('To:'),
                      SizedBox(width: spaceBetween),
                      GestureDetector(
                        onTap: () => setTime(index, ['end']),
                        child: Text(
                          printTime(
                            toTimeOfDay(lessons[index]['end']).hour,
                            toTimeOfDay(lessons[index]['end']).minute,
                          ),
                          style: textStyle,
                        ),
                      ),
                    ],
                  ),
                  leading: Text('${lessons[index]['count']}. Lesson'),
                  onClick: () => setTime(index, ['start', 'end']),
                  actionButton: IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).focusColor.withOpacity(0.5),
                      size: 18,
                    ),
                    onPressed: () {
                      changed = true;
                      saved = false;
                      lessons.removeAt(index);
                      reorderLessons();
                      setState(() {});
                    },
                  ),
                ),
              ),
              itemCount: lessons.length,
              onReorder: (oldIndex, newIndex) {
                print('start');
                dynamic oldElement = lessons.elementAt(oldIndex);
                lessons[oldIndex] = lessons.elementAt(newIndex);
                lessons[newIndex] = oldElement;
                // setState(() {});
              },
            ),
          ),
          ListItem(
            title: Icon(
              Icons.add_rounded,
              color: Theme.of(context).primaryColor,
            ),
            onClick: () {
              changed = true;
              saved = false;
              lessons.add(
                {
                  'count': lessons.length + 1,
                  'start': TimeOfDay.now().toString(),
                  'end': TimeOfDay.fromDateTime(
                    DateTime.now().add(Duration(minutes: 45)),
                  ).toString(),
                },
              );
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
