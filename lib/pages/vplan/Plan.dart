import 'dart:async';
import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:substitute/models/Button.dart';
import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ListItem.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingProcess.dart';
import '../../pages/dashboard/settings/VPlanLogin.dart';

import './VPlanAPI.dart';

class Plan extends StatefulWidget {
  final String classId;
  final Map<String, dynamic>? person;

  const Plan({
    Key? key,
    required this.classId,
    this.person,
  }) : super(key: key);

  @override
  _PlanState createState() => _PlanState();
}

class _PlanState extends State<Plan> {
  VPlanAPI vplanAPI = new VPlanAPI();

  Future<void> newVP(bool nextDay) async {
    try {
      // Get current date from data if available, otherwise use today's date
      DateTime currentDate;
      if (data is Map && data['data'] != null && data['data']['date'] != null) {
        currentDate = VPlanAPI().parseStringDatatoDateTime(data['data']['date']);
      } else {
        currentDate = DateTime.now();
      }

      setState(() {
        data = 'loading';
      });

      // Calculate new date
      DateTime newDate;
      if (nextDay) {
        int days = 1;
        if (currentDate.weekday == 5) { // Friday
          days = 3; // Skip weekend
        }
        newDate = currentDate.add(Duration(days: days));
      } else {
        int days = 1;
        if (currentDate.weekday == 1) { // Monday
          days = 3; // Skip weekend
        }
        newDate = currentDate.subtract(Duration(days: days));
      }

    // Get lessons for the new date
    dynamic newData = await VPlanAPI().getLessonsByDate(
      date: newDate,
      classId: widget.classId,
    );

    setState(() {
      data = {
        'data': newData,
        'info': newData['info'],
      };
    });
    _loadMissedCourses();
    } catch (e) {
      print('Error loading plan for new date: $e');
      // If there's an error, try to reload current data
      await getData();
    }
  }

  /// Lädt die Kurse, die laut Sick-Track am angezeigten Tag verpasst wurden,
  /// damit im Plan das Stiftsymbol (Unterschrift holen) angezeigt werden kann.
  /// Gespeichert werden neben der Anzahl auch die Krankheitseinträge, aus
  /// denen das Symbol stammt – um die Unterschrift als erledigt markieren zu
  /// können.
  Future<void> _loadMissedCourses() async {
    if (data is Map &&
        data['data'] != null &&
        data['data']['date'] != null) {
      DateTime date =
          VPlanAPI().parseStringDatatoDateTime(data['data']['date'].toString());
      Map<String, Map<String, dynamic>> missed =
          await vplanAPI.getMissedCourseDetailsForDate(widget.classId, date);
      if (mounted) {
        setState(() {
          missedCourses = missed;
        });
      }
    }
  }

  /// Fragt nach, ob die Unterschrift(en) für einen Kurs als erledigt markiert
  /// werden sollen, und speichert das im Sick-Track.
  Future<void> _askMarkSignatureDone(String course) async {
    final details = missedCourses[course];
    if (details == null) return;
    final l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(20.0),
          ),
        ),
        title: Center(child: Text(l10n!.markSignatureDone)),
        titlePadding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        contentPadding: const EdgeInsets.all(15),
        actionsPadding: const EdgeInsets.all(0),
        content: Text(
          l10n.signatureDoneQuestion(course),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      for (final entryId in (details['entryIds'] as List)) {
        await vplanAPI.markSignatureDone(entryId.toString(), course);
      }
      await _loadMissedCourses();
    }
  }

  Future<void> getData() async {
    setState(() => data = 'loading'); // show loading animation
    VPlanAPI vplanAPI = new VPlanAPI();

    dynamic _lessons = await vplanAPI.getLessonsForToday(widget.classId);
    if (_lessons['error'] != null) {
      setState(() => data = _lessons);
      return;
    }

    // Check if the day is over (current time is after the last lesson's end time)
    bool dayOver = false;
    if (_lessons['data'].isNotEmpty) {
      var lastLesson = _lessons['data'].last;
      String? endTimeStr = lastLesson['end']?.toString();
      if (endTimeStr != null && endTimeStr != '---') {
        try {
          List<String> parts = endTimeStr.split(':');
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          DateTime now = DateTime.now();
          DateTime lastEnd = DateTime(now.year, now.month, now.day, hour, minute);
          if (now.isAfter(lastEnd)) {
            dayOver = true;
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    if (dayOver) {
      // Load lessons for the next day
      DateTime tomorrow = DateTime.now().add(Duration(days: 1));
      // Skip weekends
      if (tomorrow.weekday == 6) { // Saturday
        tomorrow = tomorrow.add(Duration(days: 2)); // Monday
      } else if (tomorrow.weekday == 7) { // Sunday
        tomorrow = tomorrow.add(Duration(days: 1)); // Monday
      }
      dynamic tomorrowLessons = await VPlanAPI().getLessonsByDate(date: tomorrow, classId: widget.classId);
      if (tomorrowLessons['error'] == null && tomorrowLessons['data'] != null && tomorrowLessons['data'].isNotEmpty) {
        data = {
          'data': tomorrowLessons,
          'info': tomorrowLessons['info'],
        };
      } else {
        // If no lessons tomorrow or error, keep today's data
        data = {
          'data': _lessons,
          'info': _lessons['info'],
        };
      }
    } else {
      data = {
        'data': _lessons,
        'info': _lessons['info'],
      };
    }

    hiddenSubjects = await vplanAPI.getHiddenCourses(widget.classId);

    setState(() {});

    vplanAPI.cleanVplanOfflineData();

    _loadMissedCourses();
  }

  dynamic data = 'loading';
  List<String>? hiddenSubjects;
  bool hideLessonTimes = true;
  bool hideTeacher = false;
  // Kurs → { 'count': Anzahl benötigter Unterschriften, 'entryIds': [...] }
  Map<String, Map<String, dynamic>> missedCourses = {};
  String? className;

  String printValue(String? value) {
    if (value == null) {
      return '---';
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    getData();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? customName = await vplanAPI.getClassName(widget.classId);
    setState(() {
      hideLessonTimes = prefs.getBool('hideLessonTimes') ?? true;
      hideTeacher = prefs.getBool('hideTeacher') ?? false;
      className = customName;
    });
  }

  int weekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    DateTime displayDateDateTime;
    String displayDate = '...';
    // Kopfzeile: oben steht der Name der Person (falls eine ausgewählt
    // wurde) bzw. der benutzerdefinierte Name der Klasse, darunter das Datum.
    String headerTitle = widget.person?['name']?.toString() ??
        (className ?? widget.classId);
    if (data == null) {
      return Text('no substitution plan');
    }
    if (data.toString().contains('error')) {
      String errorText = '';
      Widget extraWidget = SizedBox();
      switch (data['error']) {
        case '401':
          errorText = 'Username or Password is wrong!';
          extraWidget = Lottie.asset(
            'assets/animations/lock.json',
            height: 120,
          );
          break;
        case 'school-number':
          errorText =
              'Wrong school-number or no substitution plan available';
          extraWidget = Lottie.asset(
            'assets/animations/nodata.json',
            height: 120,
          );
          break;
        case 'no internet':
          errorText = 'No Network connection';
          extraWidget = Lottie.asset(
            'assets/animations/wifi.json',
            height: 120,
          );
          break;
        default:
          switch (data['data']['error']) {
            case '401':
              errorText = 'Username or Password is wrong!';
              extraWidget = Lottie.asset(
                'assets/animations/lock.json',
                height: 120,
              );
              break;
            case 'schoolnumber':
              errorText =
                  'Wrong school-number or no substitution plan available';
              extraWidget = Lottie.asset(
                'assets/animations/nodata.json',
                height: 120,
              );
              break;
            case 'no internet':
              errorText = 'No Network connection';
              extraWidget = Lottie.asset(
                'assets/animations/wifi.json',
                height: 120,
              );
              break;
          }
      }
      return ListPage(
        title: headerTitle,
        actions: [
          IconButton(
            onPressed: () => getData(),
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
            text: 'Credentials',
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
    if (data.toString().contains('data')) {
      displayDateDateTime =
          VPlanAPI().parseStringDatatoDateTime(data['data']['date'].toString());
      displayDate = DateFormat('dd.MM.yyyy').format(displayDateDateTime);
    }
    return ListPage(
      onTitleClick: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(20.0),
              ),
            ),
            title: Center(child: Text('Week')),
            titlePadding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
            contentPadding: const EdgeInsets.all(10),
            actionsPadding: const EdgeInsets.all(0),
            content: Text(
              weekNumber(VPlanAPI().parseStringDatatoDateTime(
                          data['data']['date'].toString())) %
                      2 !=
                  0
                  ? 'A'
                  : 'B',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
       title: '$headerTitle\n$displayDate',
      smallTitle: true,
      actions: [
        IconButton(
          onPressed: () async {
            await VPlanAPI().removePlanByDate(data['data']['date']);
            getData();
          },
          icon: Icon(Icons.refresh, size: 20),
        ),
        // courses
        OpenContainer(
          closedColor: Colors.transparent,
          closedElevation: 0,
          openColor: Theme.of(context).scaffoldBackgroundColor,
          closedBuilder: (context, openContainer) => IconButton(
            onPressed: openContainer,
            icon: Icon(
              Icons.settings_rounded,
              size: 20,
            ),
          ),
          openBuilder: (context, closeContainer) => widget.person != null
              ? PersonCourses(
                  classId: widget.classId,
                  person: widget.person!,
                  isNew: false,
                  onSaved: (courses) {
                    setState(() {
                      widget.person!['courses'] = courses;
                    });
                    getData();
                  },
                )
              : Courses(
                  classId: widget.classId,
                  updateCourses: () => getData(),
                ),
        ),
        IconButton(
          onPressed: () => newVP(false),
          icon: Icon(Icons.arrow_back),
        ),
        IconButton(
          onPressed: () => newVP(true),
          icon: Icon(Icons.arrow_forward),
        ),
      ],
      children: [
        ...(data == 'loading'
            ? [
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.of(context).size.width * 0.2,
                  child: LoadingProcess(),
                )
              ]
            : _buildLessons(data['data']['data'] as List)),
        data != 'loading'
            ? const SizedBox()
            : const SizedBox(),
        data != 'loading'
            ? (data['info'] != null &&
                    data['info'].toString() != '' &&
                    data['info'].toString() != '[]'
                ? ListItem(
                    padding: 20,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(data['info'] as List).map(
                          (e) => Text(
                            '$e',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    onClick: () {},
                  )
                : ListItem(
                    title: Text('No additional information available'),
                    onClick: () {},
                  ))
            : SizedBox(),
      ],
    );
  }

  List<Widget> _buildLessons(List<dynamic> lessons) {
    Set<String> signatureShown = {};
    return lessons.map((e) {
      if (widget.person != null) {
        final List<dynamic>? shown =
            widget.person!['courses'] as List<dynamic>?;
        if (shown != null && !shown.contains(e['course'])) {
          return SizedBox();
        }
      } else if (vplanAPI.isLessonHidden(e, hiddenSubjects!)) {
        return SizedBox();
      }
      String course = e['course']?.toString() ?? '';
      if (course.isEmpty || course == '---') {
        course = e['lesson']?.toString() ?? '';
      }
      bool showSignature = false;
      int signatureCount = missedCourses[course]?['count'] ?? 0;
      if (signatureCount > 0 && !signatureShown.contains(course)) {
        signatureShown.add(course);
        showSignature = true;
      }
      return ListItem(
        onClick: () {},
        color: e['info'] == null ? null : Color.fromARGB(158, 119, 18, 18),
        leading: Text(
          printValue('${e['count']}'),
          style: TextStyle(fontSize: 18),
        ),
        title: Container(
          alignment: Alignment.centerLeft,
          width: MediaQuery.of(context).size.width * 0.1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                printValue(e['lesson']),
                style: TextStyle(fontSize: 19),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hideLessonTimes)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_rounded, size: 16),
                        SizedBox(width: 3),
                        Text(
                            '${printValue(e['begin'])} - ${printValue(e['end'])}'),
                      ],
                    ),
                  if (!hideLessonTimes) SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: e['placeChanged'] == true ? Colors.red : null,
                      ),
                      SizedBox(width: 3),
                      Text(
                        printValue(e['place']),
                        style: e['placeChanged'] == true
                            ? TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  if (!hideTeacher)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person_rounded, size: 16),
                        SizedBox(width: 3),
                        Text(printValue(e['teacher'])),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        subtitle: (e['info'] == null && !showSignature)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e['info'] != null)
                    Text(
                      '${e['info']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (showSignature) ...[
                    SizedBox(height: 4),
                    // Tippen auf das Stiftsymbol oder den Text daneben fragt,
                    // ob die Unterschrift für diesen Kurs als erledigt
                    // markiert werden soll.
                    GestureDetector(
                      onTap: () => _askMarkSignatureDone(course),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$signatureCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!.getSignature,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      );
    }).toList();
  }
}

class Courses extends StatefulWidget {
  final String classId;
  final Function updateCourses;

  Courses({
    required this.classId,
    required this.updateCourses,
  });

  @override
  State<Courses> createState() => _CoursesState();
}

class _CoursesState extends State<Courses> {
  VPlanAPI vplanAPI = new VPlanAPI();
  List<dynamic> courses = [];
  bool? seeAll;
  Timer? _debounce;

  void getData() async {
    List<dynamic> _courses = await vplanAPI.getCourses(widget.classId);

    // On first open for a new class, hide all courses by default
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> initialized = {};
    String? initData = prefs.getString('initializedClasses');
    if (initData != null && initData.isNotEmpty) {
      try {
        initialized = Map<String, dynamic>.from(
            Map<String, dynamic>.from(jsonDecode(initData)) as Map);
      } catch (e) {}
    }
    bool isFirstOpen = !initialized.containsKey(widget.classId);
    if (isFirstOpen) {
      initialized[widget.classId] = true;
      await prefs.setString('initializedClasses', jsonEncode(initialized));
    }

    List<String> hiddenCourses =
        await vplanAPI.getHiddenCourses(widget.classId);
    if (isFirstOpen && hiddenCourses.isEmpty && _courses.isNotEmpty) {
      // Hide all courses for first-time setup
      List<String> allCourses = _courses
          .map((c) => c['course'] as String)
          .where((c) => c != '---')
          .toList();
      await vplanAPI.setHiddenCourses(widget.classId, allCourses);
      hiddenCourses = allCourses;
    }
    for (int i = 0; i < _courses.length; i++) {
      courses.add({
        'course': _courses[i]['course'],
        'teacher': _courses[i]['teacher'],
        'show': !hiddenCourses.contains(_courses[i]['course']),
      });
    }

    setState(() {});
  }

  void _debouncedUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      widget.updateCourses();
    });
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Courses',
      actions: [
        IconButton(
          icon: Icon(Icons.visibility_rounded),
          onPressed: () async {
            for (int i = 0; i < courses.length; i++) {
              courses[i]['show'] = true;
            }
            await vplanAPI.setHiddenCourses(widget.classId, []);
            setState(() {});
            await widget.updateCourses();
          },
        ),
        IconButton(
          icon: Icon(Icons.visibility_off_rounded),
          onPressed: () async {
            for (int i = 0; i < courses.length; i++) {
              courses[i]['show'] = false;
            }
            List<String> allCourses = courses
                .map((c) => c['course'] as String)
                .toList();
            await vplanAPI.setHiddenCourses(widget.classId, allCourses);
            setState(() {});
            await widget.updateCourses();
          },
        ),
      ],
      children: [
        GridView.count(
          childAspectRatio: 3 / 1.5,
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          physics: BouncingScrollPhysics(),
          children: [
            ...courses.map(
              (e) => ListItem(
                color: e['show']
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
                title: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              e['course'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                decoration: !e['show']
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: !e['show'] ? Colors.grey : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '(${e['teacher']})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                decoration: !e['show']
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: !e['show'] ? Colors.grey : null,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        alignment: Alignment.center,
                        width: 17,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 500),
                          child: e['show']
                              ? Icon(
                                  Icons.visibility_outlined,
                                  key: ValueKey(1),
                                  size: 16,
                                )
                              : Icon(
                                  Icons.visibility_off_outlined,
                                  key: ValueKey(2),
                                  size: 16,
                                ),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) =>
                              SizeTransition(
                            sizeFactor: animation,
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                onClick: () async {
                  setState(() {
                    e['show'] = !e['show'];
                  });
                  if (e['show']) {
                    await vplanAPI.removeHiddenCourse(
                        widget.classId, e['course']);
                  } else {
                    await vplanAPI.addHiddenCourse(
                        widget.classId, e['course']);
                  }
                  _debouncedUpdate();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PersonCourses extends StatefulWidget {
  final String classId;
  final Map<String, dynamic> person;
  final bool isNew; // true: created & added to storage on save, false: updates existing person
  final Function(List<String> courses)? onSaved;

  const PersonCourses({
    Key? key,
    required this.classId,
    required this.person,
    this.isNew = false,
    this.onSaved,
  }) : super(key: key);

  @override
  State<PersonCourses> createState() => _PersonCoursesState();
}

class _PersonCoursesState extends State<PersonCourses> {
  VPlanAPI vplanAPI = new VPlanAPI();
  List<dynamic> courses = [];
  Set<String> shown = {};
  bool loading = true;

  void getData() async {
    List<dynamic> _courses = await vplanAPI.getCourses(widget.classId);
    List<dynamic> courseList = [];
    for (int i = 0; i < _courses.length; i++) {
      courseList.add({
        'course': _courses[i]['course'],
        'teacher': _courses[i]['teacher'],
      });
    }

    Set<String> initial;
    if (widget.isNew) {
      // Baseline for new persons: alle Kurse deaktiviert - der Nutzer
      // wählt nur die Kurse aus, die er sehen möchte.
      initial = <String>{};
    } else {
      final List<dynamic>? stored = widget.person['courses'] as List<dynamic>?;
      initial = stored == null
          ? courseList.map((c) => c['course'] as String).toSet()
          : stored.cast<String>().toSet();
    }

    if (!mounted) return;
    setState(() {
      courses = courseList;
      shown = initial;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  void _save() {
    final List<String> selected = courses
        .where((c) => shown.contains(c['course']))
        .map((c) => c['course'] as String)
        .toList();

    if (widget.isNew) {
      widget.person['courses'] = selected;
      vplanAPI.addPerson(widget.person);
    } else {
      vplanAPI.updatePersonCourses(widget.person['id'], selected);
    }

    widget.onSaved?.call(selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: AppLocalizations.of(context)!.coursesFor(widget.person['name']),
      actions: [
        IconButton(
          icon: Icon(Icons.check_rounded),
          tooltip: AppLocalizations.of(context)!.savePerson,
          onPressed: loading ? null : _save,
        ),
      ],
      children: [
        if (loading)
          Center(child: LoadingProcess())
        else
          GridView.count(
            childAspectRatio: 3 / 1.5,
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            physics: BouncingScrollPhysics(),
            children: [
              ...courses.map((e) {
                final bool isShown = shown.contains(e['course']);
                return ListItem(
                  color: isShown
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
                  title: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                e['course'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  decoration:
                                      !isShown ? TextDecoration.lineThrough : null,
                                  color: !isShown ? Colors.grey : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '(${e['teacher']})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  decoration:
                                      !isShown ? TextDecoration.lineThrough : null,
                                  color: !isShown ? Colors.grey : null,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          alignment: Alignment.center,
                          width: 17,
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 500),
                            child: isShown
                                ? Icon(
                                    Icons.visibility_outlined,
                                    key: ValueKey(1),
                                    size: 16,
                                  )
                                : Icon(
                                    Icons.visibility_off_outlined,
                                    key: ValueKey(2),
                                    size: 16,
                                  ),
                            transitionBuilder: (Widget child, Animation<double> animation) =>
                                SizeTransition(
                              sizeFactor: animation,
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onClick: () {
                    setState(() {
                      if (shown.contains(e['course'])) {
                        shown.remove(e['course']);
                      } else {
                        shown.add(e['course']);
                      }
                    });
                  },
                );
              }),
            ],
          ),
      ],
    );
  }
}
