import 'package:substitute/models/ModalBottomSheet.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'dart:convert';

import '../../../models/ListItem.dart';
import '../../../models/ListPage.dart';
import '../../../services/SchoolStorage.dart';

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
      final TimeOfDay? newTime = await showTimePicker(
        context: context,
        initialTime: initTime,
        hourLabelText: 'Hour',
        minuteLabelText: 'Minute',
        cancelText: 'Cancel',
        confirmText: 'OK',
        helpText:
            'Set ${string[i].replaceFirst(string[i][0], string[i][0].toUpperCase())} for ${lessons[index]['count']}.lesson',
      );

      if (!mounted || index >= lessons.length) return;

      if (newTime != null) {
        lessons[index][string[i]] = newTime.toString();
      }
    }
    if (mounted) setState(() {});
  }

  TimeOfDay toTimeOfDay(dynamic value) {
    String time = value?.toString() ?? '';
    time = time.replaceAll('TimeOfDay(', '');
    time = time.replaceAll(')', '');
    final List<String> parts = time.split(':');
    final int hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final int minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    return TimeOfDay(
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
    );
  }

  List<dynamic> normalizeLessons(List<dynamic> decodedLessons) {
    return List<dynamic>.generate(decodedLessons.length, (index) {
      final dynamic rawLesson = decodedLessons[index];
      final Map<dynamic, dynamic> lesson =
          rawLesson is Map ? rawLesson : <dynamic, dynamic>{};
      final int count = int.tryParse(lesson['count']?.toString() ?? '') ??
          index + 1;

      return {
        'count': count,
        'start': lesson['start']?.toString() ??
            TimeOfDay(hour: 0, minute: 0).toString(),
        'end': lesson['end']?.toString() ??
            TimeOfDay(hour: 0, minute: 45).toString(),
      };
    });
  }

  getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = SchoolStorage.scopedKey(prefs, 'lessontimes');
    final String? storedLessons = prefs.getString(key);

    if (storedLessons == null || storedLessons.isEmpty) {
      await prefs.setString(key, '[]');
      lessons = [];
    } else {
      try {
        final dynamic decodedLessons = jsonDecode(storedLessons);
        lessons =
            decodedLessons is List ? normalizeLessons(decodedLessons) : [];
        reorderLessons();
      } catch (_) {
        lessons = [];
        await prefs.setString(key, '[]');
      }
    }

    if (mounted) setState(() {});
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
            'child': Text('don\'t save'),
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

  void reorderLesson(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= lessons.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > lessons.length) newIndex = lessons.length;

    final dynamic lesson = lessons.removeAt(oldIndex);
    if (newIndex > lessons.length) newIndex = lessons.length;
    lessons.insert(newIndex, lesson);
    reorderLessons();
    changed = true;
    saved = false;
    setState(() {});
  }

  save() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(
        SchoolStorage.scopedKey(prefs, 'lessontimes'), jsonEncode(lessons));

    saved = true;
    setState(() {});
    Fluttertoast.cancel();
    Fluttertoast.showToast(msg: 'Times saved');
  }

  Widget buildLessonItem(BuildContext context, int index) {
    final dynamic lesson = lessons[index];

    return Container(
      key: ObjectKey(lesson),
      child: ListItem(
        title: Row(
          children: [
            Text('From:'),
            SizedBox(width: spaceBetween),
            GestureDetector(
              onTap: () => setTime(index, ['start']),
              child: Text(
                printTime(
                  toTimeOfDay(lesson['start']).hour,
                  toTimeOfDay(lesson['start']).minute,
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
                  toTimeOfDay(lesson['end']).hour,
                  toTimeOfDay(lesson['end']).minute,
                ),
                style: textStyle,
              ),
            ),
          ],
        ),
        leading: Text('${lesson['count']}. Lesson'),
        onClick: () => setTime(index, ['start', 'end']),
        actionButton: IconButton(
          icon: Icon(
            Icons.delete,
            color: Theme.of(context).focusColor.withValues(alpha: 0.5),
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
    );
  }

  Widget buildLessonList() {
    if (lessons.isEmpty) return SizedBox.shrink();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lessons.length,
      itemBuilder: buildLessonItem,
      onReorder: reorderLesson,
    );
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: ListPage(
        title: l10n.lessonTimes,
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
            child: buildLessonList(),
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
