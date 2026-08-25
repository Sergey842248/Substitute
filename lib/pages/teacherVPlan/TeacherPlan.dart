import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';

import '../vplan/VPlanAPI.dart';
import '../../models/ListItem.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingProcess.dart';

class TeacherPlan extends StatefulWidget {
  const TeacherPlan({
    Key? key,
    required this.teacher,
    required this.selectedDate,
  }) : super(key: key);

  final String teacher;
  final DateTime selectedDate;

  @override
  _TeacherPlanState createState() => _TeacherPlanState();
}

class _TeacherPlanState extends State<TeacherPlan> {
  String date = '';
  List<dynamic> res = [];
  String teacherName = '';

  void getData() async {
    VPlanAPI vplanAPI = new VPlanAPI();
    await vplanAPI.login();

    teacherName = (await vplanAPI.replaceTeacherShort(widget.teacher))!;

    final DateTime normalizedDate = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    // Den passenden Tagesplan laden: für "heute" automatisch Klassen.xml,
    // für andere Tage PlanKl<Datum>.xml. Die interne Datumsangabe des Plans
    // (DatumPlan) weicht am Tagesanfang oft noch auf den letzten Schultag ab
    // – der vom Server gelieferte Plan ist trotzdem die gültige Quelle für
    // den gewählten Tag und wird daher nicht mehr anhand des Datums
    // verworfen.
    dynamic plan;
    try {
      plan = await vplanAPI.getRawPlanByDate(normalizedDate);
    } catch (e) {
      plan = {'error': 'no internet'};
    }

    // Bei ungültigem Ergebnis einmalig frisch vom Server laden.
    bool planInvalid() {
      return plan == null ||
          plan is! Map ||
          plan['error'] != null ||
          plan['data'] == null ||
          plan['data']['Klassen'] == null;
    }

    if (planInvalid()) {
      try {
        plan = await vplanAPI.getRawPlanByDate(
          normalizedDate,
          forceRefresh: true,
        );
      } catch (e) {
        plan = {'error': 'no internet'};
      }
    }

    if (planInvalid()) {
      res = [];
      setState(() {});
      return;
    }

    var data = plan['data'];

    setState(() {
      date = data['Kopf'] != null ? (data['Kopf']['DatumPlan'] ?? '') : '';
    });
    for (int i = 0; i < data['Klassen']['Kl'].length; i++) {
      var currentClass = data['Klassen']['Kl'][i];
      for (int j = 0; j < currentClass['Pl']['Std'].length; j++) {
        var currentLesson = currentClass['Pl']['Std'][j];
        if (currentLesson['Le'].toString().toLowerCase() ==
            widget.teacher.toLowerCase()) {
          res.add({
            'count': int.parse(currentLesson['St']),
            'lesson': currentLesson['Fa'],
            'class': currentClass['Kurz'],
            'place': currentLesson['Ra'],
          });
        }
      }
    }
    res = sort(res);

    setState(() {});
  }

  List<dynamic> sort(List<dynamic> list) {
    if (list.length <= 1) {
      return list;
    }

    int half = list.length ~/ 2;

    List<dynamic> leftList = [];
    for (int i = 0; i < half; i++) {
      leftList.add(list[i]);
    }

    List<dynamic> rightList = [];
    for (int i = 0; i < list.length - half; i++) {
      int count = i + half;
      rightList.add(list[count]);
    }

    leftList = sort(leftList);
    rightList = sort(rightList);

    return merge(leftList, rightList);
  }

  List<dynamic> merge(List<dynamic> leftList, List<dynamic> rightList) {
    List<dynamic> newList = [];

    while (leftList.isNotEmpty && rightList.isNotEmpty) {
      if (leftList[0]['count'] <= rightList[0]['count']) {
        var value = leftList[0];

        newList.add(leftList[0]);
        leftList.remove(value);
      } else {
        var value = rightList[0];

        newList.add(rightList[0]);
        rightList.remove(value);
      }
    } // end of while

    while (leftList.isNotEmpty) {
      var value = leftList[0];

      newList.add(leftList[0]);
      leftList.remove(value);
    }

    while (rightList.isNotEmpty) {
      var value = rightList[0];

      newList.add(rightList[0]);
      rightList.remove(value);
    }

    return newList;
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    String displayDate =
        '${widget.selectedDate.day.toString().padLeft(2, '0')}.'
        '${widget.selectedDate.month.toString().padLeft(2, '0')}.'
        '${widget.selectedDate.year}';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ListPage(
        title: AppLocalizations.of(context)!.classesFromTeacher(teacherName, displayDate),
        smallTitle: true,
        children: res.length == 0
            ? [
                Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No classes found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).focusColor.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No hours available for the selected Date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              ]
            : res
                .map(
                  (e) => ListItem(
                    leading: Text('${e['count']}'),
                    title: Container(
                      alignment: Alignment.centerLeft,
                      width: MediaQuery.of(context).size.width * 0.1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            e['lesson'],
                            style: TextStyle(fontSize: 19),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                  ),
                                  SizedBox(width: 3),
                                  Text(e['place']),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.group_rounded,
                                    size: 16,
                                  ),
                                  SizedBox(width: 3),
                                  Text(e['class']),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(width: 50),
                        ],
                      ),
                    ),
                    onClick: () {},
                  ),
                )
                .toList(),
      ),
    );
  }
}
