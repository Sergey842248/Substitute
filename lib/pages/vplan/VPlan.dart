import 'package:expandiware/models/Button.dart';
import 'package:expandiware/models/ListPage.dart';
import 'package:expandiware/pages/dashboard/settings/Lessons.dart';
import 'package:expandiware/pages/vplan/VPlanAPI.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:page_transition/page_transition.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/settings/VPlanLogin.dart';

import '../../models/ListItem.dart';
import '../../models/LoadingProcess.dart';

import './Plan.dart';

class VPlan extends StatefulWidget {
  const VPlan({Key? key}) : super(key: key);

  @override
  _VPlanState createState() => _VPlanState();
}

class _VPlanState extends State<VPlan> {
  List<String> classes = [];
  final listKey = GlobalKey<AnimatedListState>();

  void getClasses() async {
    classes = [];

    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? prefClasses = prefs.getStringList('classes');
    if (prefClasses == null) {
      prefClasses = [];
    }

    for (int i = 0; i < prefClasses.length; i++) {
      listKey.currentState!.insertItem(i);
      classes.add(prefClasses[i]);
    }

    String? username = prefs.getString('vplanUsername');

    if (classes.length == 0 && (username == null || username == '')) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Theme.of(context).backgroundColor,
            title: Text(
              AppLocalizations.of(context)!.addNewClass,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19),
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppLocalizations.of(context)!.dontForgetCredentials),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.later,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: VPlanLogin(),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.add,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getClasses();
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OpenContainer(
            closedColor: Theme.of(context).scaffoldBackgroundColor,
            openColor: Theme.of(context).scaffoldBackgroundColor,
            openElevation: 0,
            closedElevation: 0,
            closedBuilder: (context, openContainer) => ListItem(
              title: Text(
                AppLocalizations.of(context)!.selectClass,
                style: TextStyle(
                  fontSize: 19,
                ),
              ),
              onClick: openContainer,
            ),
            openBuilder: (context, closeContainer) => SelectClass(
              pop: (String classId) {
                listKey.currentState!.insertItem(classes.length);
                classes.add(classId);
              },
              favs: classes,
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Scrollbar(
              radius: Radius.circular(100),
              child: AnimatedList(
                physics: BouncingScrollPhysics(),
                key: listKey,
                initialItemCount: classes.length,
                itemBuilder: (context, index, animation) => SizeTransition(
                  sizeFactor: animation,
                  child: OpenContainer(
                    closedColor: Theme.of(context).scaffoldBackgroundColor,
                    openColor: Theme.of(context).scaffoldBackgroundColor,
                    closedBuilder: (context, openContainer) => ClassWidget(
                      classId: classes[index],
                      classIndex: index,
                      onDelete: () async {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        List<String>? newClasses =
                            prefs.getStringList('classes');
                        if (newClasses == null) {
                          newClasses = [];
                        }
                        newClasses.remove(classes[index]);
                        prefs.setStringList('classes', newClasses);

                        listKey.currentState!.removeItem(
                          index,
                          (context, animation) => SizeTransition(
                            sizeFactor: animation,
                            child: ListItem(
                              onClick: () {},
                              title: Text(
                                classes[index],
                                style: TextStyle(
                                  fontSize: 19,
                                ),
                              ),
                            ),
                          ),
                        );
                        classes.removeAt(index);
                        //getClasses();
                      },
                      openContainer: openContainer,
                    ),
                    openBuilder: (context, closeContainer) => Plan(
                      classId: classes[index],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassWidget extends StatefulWidget {
  const ClassWidget({
    Key? key,
    required this.classId,
    required this.classIndex,
    required this.onDelete,
    required this.openContainer,
  }) : super(key: key);

  final String classId;
  final int classIndex;
  final Function() onDelete;
  final Function openContainer;

  @override
  State<ClassWidget> createState() => _ClassWidgetState();
}

class _ClassWidgetState extends State<ClassWidget> {
  Map<String, dynamic> nextLesson = {'': 'loading'};
  getData() async {
    List<dynamic> realVPlan = [];
    dynamic vplan = await VPlanAPI().getLessonsForToday(widget.classId);
    List<String> hiddenCourses = await VPlanAPI().getHiddenCourses();

    for (var i = 0; i < vplan['data'].length; i++) {
      bool add = true;
      for (var j = 0; j < hiddenCourses.length; j++) {
        if (vplan['data'][i]['course'] == hiddenCourses[j] ||
            vplan['data'][i]['course'] == '---') {
          add = false;
        }
      }
      if (add) {
        realVPlan.add(vplan['data'][i]);
      }
    }

    // GET NEXT LESSON

    TimeOfDay currentTime = TimeOfDay.now();

    if (VPlanAPI()
        .parseStringDatatoDateTime(vplan['date'])
        .isAfter(DateTime.now())) {
      currentTime = TimeOfDay(hour: 0, minute: 0);
    }

    double lowestDifference = 50;
    int lessonIndex = 0;
    bool foundNextLesson = false;

    for (var i = 0; i < realVPlan.length; i++) {
      Map<String, dynamic> lesson = realVPlan[i];

      if (lesson['begin'] == null) {
        nextLesson = {};
        setState(() {});
        return;
      }

      double difference = (toTimeOfDay(lesson['begin']).hour +
              (toTimeOfDay(lesson['begin']).minute / 60)) -
          (currentTime.hour + (currentTime.minute / 60));

      if (difference < lowestDifference && difference >= 0) {
        lowestDifference = difference;
        lessonIndex = i;
        foundNextLesson = true;
      }
    }

    if (foundNextLesson) {
      nextLesson = realVPlan[lessonIndex];
    } else {
      // Check if current time is after the last lesson of the day
      if (realVPlan.isNotEmpty) {
        Map<String, dynamic> lastLesson = realVPlan.last;
        double lastLessonEndTime = (toTimeOfDay(lastLesson['end']).hour +
                (toTimeOfDay(lastLesson['end']).minute / 60));

        if (currentTime.hour + (currentTime.minute / 60) > lastLessonEndTime) {
          // Current time is after last lesson, so get first lesson of next day
          try {
            DateTime today = DateTime.now();
            DateTime tomorrow = today.add(Duration(days: 1));

            // Skip weekend if today is Friday
            if (today.weekday == 5) { // Friday
              tomorrow = today.add(Duration(days: 3));
            }

            dynamic tomorrowVplan = await VPlanAPI().getLessonsByDate(
              date: tomorrow,
              classId: widget.classId,
            );

            if (tomorrowVplan != null &&
                tomorrowVplan['data'] != null &&
                tomorrowVplan['data'].isNotEmpty) {

              // Filter hidden courses from tomorrow's lessons
              List<dynamic> tomorrowRealVPlan = [];
              for (var i = 0; i < tomorrowVplan['data'].length; i++) {
                bool add = true;
                for (var j = 0; j < hiddenCourses.length; j++) {
                  if (tomorrowVplan['data'][i]['course'] == hiddenCourses[j] ||
                      tomorrowVplan['data'][i]['course'] == '---') {
                    add = false;
                  }
                }
                if (add) {
                  tomorrowRealVPlan.add(tomorrowVplan['data'][i]);
                }
              }

              if (tomorrowRealVPlan.isNotEmpty) {
                // Use the first lesson of tomorrow
                nextLesson = tomorrowRealVPlan.first;
              } else {
                nextLesson = {};
              }
            } else {
              nextLesson = {};
            }
          } catch (e) {
            print('Error fetching next day lessons: $e');
            nextLesson = {};
          }
        } else {
          nextLesson = {};
        }
      } else {
        nextLesson = {};
      }
    }

    setState(() {});
  }

  TimeOfDay toTimeOfDay(String time) {
    return TimeOfDay(
      hour: int.parse(time.split(':')[0]),
      minute: int.parse(time.split(':')[1]),
    );
  }

  String printTime(int _hour, int _minute) {
    TimeOfDay time = TimeOfDay(hour: _hour, minute: _minute);

    String hour = time.hour < 10 ? '0${time.hour}' : '${time.hour}';
    String minute = time.minute < 10 ? '0${time.minute}' : '${time.minute}';
    return '$hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    double spaceBetween = 10;
    return Container(
      margin: EdgeInsets.only(left: 5, right: 5, bottom: 5),
      child: Column(
        children: [
          ListItem(
            title: Text(
              '${widget.classId}',
              style: TextStyle(
                fontSize: 19,
              ),
            ),
            onClick: widget.openContainer,
            actionButton: IconButton(
              onPressed: widget.onDelete,
              icon: Icon(
                Icons.delete_rounded,
                color: Theme.of(context).focusColor.withOpacity(0.5),
              ),
            ),
            margin: 0,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              child: child,
            ),
            child: Container(
              key: ValueKey(nextLesson),
              width: double.infinity,
              child: nextLesson.toString() == '{: loading}'
                  ? Center(child: LoadingProcess())
                  : (nextLesson.toString() == '{}'
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.noNextLessonFound,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .focusColor
                                  .withOpacity(0.5),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.nextHour,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .focusColor
                                        .withOpacity(0.5),
                                  ),
                                ),
                                SizedBox(height: spaceBetween),
                                Text(
                                  nextLesson['lesson'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 21,
                                  ),
                                ),
                                SizedBox(height: spaceBetween),
                                Text(nextLesson['teacher'] ?? ''),
                              ],
                            ),
                            SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3),
                            Column(
                              children: [
                                Text(''),
                                Text(
                                  AppLocalizations.of(context)!.room(nextLesson['place'] ?? ''),
                                  style: TextStyle(fontSize: 19),
                                ),
                                SizedBox(height: spaceBetween),
                                Text(
                                    '${nextLesson['begin'] != null ? printTime(toTimeOfDay(nextLesson['begin']).hour, toTimeOfDay(nextLesson['begin']).minute) : ''} - ${nextLesson['end'] != null ? printTime(toTimeOfDay(nextLesson['end']).hour, toTimeOfDay(nextLesson['end']).minute) : ''}'),
                              ],
                            ),
                          ],
                        )),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                color: Theme.of(context).backgroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectClass extends StatefulWidget {
  const SelectClass({
    Key? key,
    required this.pop,
    required this.favs,
  }) : super(key: key);

  final Function pop;
  final List<String> favs;

  @override
  State<SelectClass> createState() => _SelectClassState();
}

class _SelectClassState extends State<SelectClass> {
  dynamic classes = [];
  void getClasses() async {
    // Prüfe, ob Zugangsdaten vorhanden sind
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('vplanUsername');
    
    if (username == null || username == '') {
      // Zeige Login-Dialog wenn keine Zugangsdaten vorhanden sind
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Theme.of(context).backgroundColor,
            title: Text(
              AppLocalizations.of(context)!.addNewClass,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19),
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppLocalizations.of(context)!.dontForgetCredentials),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.later,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: VPlanLogin(),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.add,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return; // Stoppe weitere Ausführung wenn keine Zugangsdaten vorhanden sind
    }
    
    // Wenn Zugangsdaten vorhanden sind, lade die Klassen
    VPlanAPI vplanAPI = new VPlanAPI();
    classes = await vplanAPI.getClassList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getClasses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh classes when returning from VPlanLogin with new credentials
    // This fixes the issue where classes load infinitely after adding credentials
    getClasses();
  }

  @override
  Widget build(BuildContext context) {
    if (classes.toString().contains('error')) {
      String errorText = '';
      Widget extraWidget = SizedBox();
      switch (classes['error']) {
        case '401':
          errorText = 'Der Benutzername oder das Passwort ist falsch!';
          extraWidget = Lottie.asset(
            'assets/animations/lock.json',
            height: 120,
          );
          break;
        case 'schoolnumber':
          errorText = 'Falsche Schulnummer!\n\noder Vertretungsplan verfügbar';
          extraWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Theme.of(context).backgroundColor,
            ),
            margin: EdgeInsets.only(
              left: MediaQuery.of(context).size.width * 0.37,
              right: MediaQuery.of(context).size.width * 0.37,
              bottom: 30,
            ),
            child: Center(
              child: Lottie.asset(
                'assets/animations/attention.json',
                height: 120,
                width: 120,
              ),
            ),
          );
          break;
        case 'no internet':
          errorText = 'No internet connection';
          extraWidget = Lottie.asset(
            'assets/animations/wifi.json',
            height: 120,
          );
          break;
        default:
          switch (classes['data']['error']) {
            case '401':
              errorText = 'Username or password incorrect!';
              extraWidget = Lottie.asset(
                'assets/animations/lock.json',
                height: 120,
              );
              break;
            case 'schoolnumber':
              errorText =
                  'Wrong schoolnumber!\n\nor no substitution plan available!';
              extraWidget = Lottie.asset(
                'assets/animations/attention.json',
                height: 120,
              );
              break;
            case 'no internet':
              errorText = 'No internet connection';
              extraWidget = Lottie.asset(
                'assets/animations/wifi.json',
                height: 120,
              );
              break;
          }
      }
      return ListPage(
        title: AppLocalizations.of(context)!.classSelection,
        animate: true,
        actions: [
          IconButton(
            onPressed: () => getClasses(),
            icon: Icon(Icons.sync_rounded),
          ),
        ],
        children: [
          extraWidget,
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(left: 10, right: 10),
            child: Text(
              errorText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red.shade300,
              ),
            ),
          ),
          SizedBox(height: 30),
          Button(
            text: AppLocalizations.of(context)!.credentials,
            onPressed: () => Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: VPlanLogin(),
              ),
            ),
          ),
        ],
      );
    }
    return ListPage(
      title: AppLocalizations.of(context)!.selectClassTitle,
      animate: true,
      children: [
        classes.length == 0
            ? Center(
                child: LoadingProcess(),
              )
            : SizedBox(),
        ...classes.map((className) {
          bool used = false;
          if (widget.favs.contains(className)) {
            used = true;
          }
          return ListItem(
            title: Text(
              className,
              style: TextStyle(
                fontSize: 19,
                fontWeight: used ? FontWeight.w600 : null,
                color: used ? Colors.black : null,
              ),
            ),
            actionButton: used
                ? IconButton(
                    icon: Icon(
                      Icons.check_rounded,
                      color: used ? Colors.black : null,
                    ),
                    onPressed: () {},
                  )
                : null,
            color: used ? Theme.of(context).indicatorColor : null,
            onClick: () async {
              SharedPreferences instance =
                  await SharedPreferences.getInstance();
              List<String>? _classes = instance.getStringList('classes');
              if (_classes == null) {
                _classes = [];
              }
              _classes.add(className);
              instance.setStringList('classes', _classes);
              this.widget.pop(className);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }
}
