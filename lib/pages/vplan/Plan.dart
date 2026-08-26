import 'dart:async';
import 'dart:convert';
import 'package:substitute/models/Button.dart';
import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';

import '../../models/swipe_page_transition.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';

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
        currentDate =
            VPlanAPI().parseStringDatatoDateTime(data['data']['date']);
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
        if (currentDate.weekday == 5) {
          // Friday
          days = 3; // Skip weekend
        }
        newDate = currentDate.add(Duration(days: days));
      } else {
        int days = 1;
        if (currentDate.weekday == 1) {
          // Monday
          days = 3; // Skip weekend
        }
        newDate = currentDate.subtract(Duration(days: days));
      }

      // Get lessons for the new date
      dynamic newData = await VPlanAPI().getLessonsByDate(
        date: newDate,
        classId: widget.classId,
      );

      // Wenn für den neuen Tag kein Plan geladen werden konnte
      // (z.B. keine Internetverbindung), die Fehlermeldung anzeigen statt
      // mit einem Cast-Fehler abzustürzen.
      if (newData is! Map || newData['error'] != null) {
        if (mounted) {
          setState(() {
            data = newData is Map ? newData : {'error': 'no internet'};
          });
        }
        return;
      }

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
    if (data is Map && data['data'] != null && data['data']['date'] != null) {
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

  /// Prüft, ob zwei Pläne den gleichen Inhalt haben (Stunden + Zusatzinfo),
  /// damit ein identischer Plan beim erneuten Laden nicht neu gezeichnet wird.
  bool _planDataEqual(dynamic a, dynamic b) {
    if (a is! Map || b is! Map) return identical(a, b) || a == b;
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return false;
    }
  }

  /// Wahr, wenn [data] bereits einen geladenen Plan (ohne Fehler) enthält.
  bool _hasPlan(dynamic d) {
    if (d is! Map || d['error'] != null) return false;
    return d['data'] is Map && d['data']['data'] != null;
  }

  /// Wendet [candidate] als angezeigten Plan an, aber nur, wenn sich das
  /// tatsächlich ändert – sonst passiert nichts (kein unnötiges Neuzeichnen).
  void _applyIfChanged(dynamic candidate) {
    if (!mounted || _planDataEqual(data, candidate)) return;
    data = candidate;
    setState(() {});
  }

  /// Baut aus einem `getLessons*`-Ergebnis die angezeigte Plan-Struktur,
  /// inklusive dem automatischen Wechsel auf den nächsten Schultag, sobald
  /// der heutige Tag vorbei ist. [allowNextDay] == false (Cache-Pfad) zeigt
  /// vorerst nur die vorhandenen Daten ohne weitere Netzwerkanfrage.
  Future<dynamic> _displayData(dynamic lessons, {bool allowNextDay = true}) async {
    if (lessons == null) return null;

    // Check if the day is over (current time is after the last lesson's end time)
    if (allowNextDay && lessons['data'] is List && lessons['data'].isNotEmpty) {
      var lastLesson = lessons['data'].last;
      String? endTimeStr = lastLesson['end']?.toString();
      if (endTimeStr != null && endTimeStr != '---') {
        bool dayOver = false;
        try {
          List<String> parts = endTimeStr.split(':');
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          DateTime now = DateTime.now();
          DateTime lastEnd =
              DateTime(now.year, now.month, now.day, hour, minute);
          if (now.isAfter(lastEnd)) dayOver = true;
        } catch (e) {
          // Ignore parsing errors
        }

        if (dayOver) {
          // Load lessons for the next day
          DateTime tomorrow = DateTime.now().add(Duration(days: 1));
          // Skip weekends
          if (tomorrow.weekday == 6) {
            tomorrow = tomorrow.add(Duration(days: 2)); // Monday
          } else if (tomorrow.weekday == 7) {
            tomorrow = tomorrow.add(Duration(days: 1)); // Monday
          }
          dynamic tomorrowLessons = await VPlanAPI()
              .getLessonsByDate(date: tomorrow, classId: widget.classId);
          if (tomorrowLessons['error'] == null &&
              tomorrowLessons['data'] != null &&
              tomorrowLessons['data'].isNotEmpty) {
            return {
              'data': tomorrowLessons,
              'info': tomorrowLessons['info'],
            };
          }
        }
      }
    }

    return {
      'data': lessons,
      'info': lessons['info'],
    };
  }

  /// Lädt den Plan im Hintergrund: Zuerst wird – ohne jede Ladeanimation und
  /// ohne Netzwerkwarten – der zuletzt bekannte (lokale) Plan angezeigt, im
  /// Hintergrund werden dann frische Daten geholt und der Plan nur ersetzt,
  /// wenn sich tatsächlich etwas geändert hat.
  Future<void> getData({bool showLoading = true}) async {
    final VPlanAPI vplanAPI = VPlanAPI();
    hiddenSubjects = await vplanAPI.getHiddenCourses(widget.classId);

    // 1) Sofort verfügbare Daten (Offline-Cache) anzeigen – keine Ladezeit.
    if (mounted && !_hasPlan(data)) {
      try {
        final dynamic cached =
            await vplanAPI.getCachedLessonsForToday(widget.classId);
        if (mounted && cached != null && cached['data'] is List) {
          _applyIfChanged(await _displayData(cached, allowNextDay: false));
          if (mounted && _hasPlan(data)) {
            savePlanDisplay(widget.classId, data);
          }
        }
      } catch (_) {
        // Cache nicht verfügbar – direkt mit dem Hintergrund-Fetch fortfahren.
      }
    }

    // 2) Im Hintergrund frische Daten laden und nur bei Änderung ersetzen.
    dynamic fresh;
    try {
      fresh = await vplanAPI
          .getLessonsForToday(widget.classId, forceRefresh: true);
    } catch (e) {
      fresh = {'error': 'no internet'};
    }
    if (fresh == null || (fresh is Map && fresh['error'] != null)) {
      // Zeige den Fehler nur, wenn noch kein Plan angezeigt wird – ein
      // bereits sichtbarer Plan bleibt bei einem Hintergrund-Fehler erhalten.
      if (mounted && !_hasPlan(data)) {
        _applyIfChanged(fresh is Map ? fresh : {'error': 'no internet'});
      }
      vplanAPI.cleanVplanOfflineData();
      return;
    }
    if (!mounted) return;

    _applyIfChanged(await _displayData(fresh));
    if (mounted && _hasPlan(data)) {
      savePlanDisplay(widget.classId, data);
    }

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
    // Sofort (ohne Ladezeit und ohne await) den zuletzt gespeicherten Plan
    // anzeigen – der allererste Frame zeigt also bereits den letzten Stand.
    data = cachedPlanDisplay(widget.classId) ?? 'loading';
    _loadSettings();
    getData();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? customName = await vplanAPI.getClassName(widget.classId);
    if (!mounted) return;
    setState(() {
      hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
      hideTeacher =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideTeacher')) ?? false;
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
    String headerTitle =
        widget.person?['name']?.toString() ?? (className ?? widget.classId);
    if (data == null) {
      return Text('no substitution plan');
    }
    if (data is Map && data.containsKey('error')) {
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
        case 'schoolnumber':
          errorText = 'Wrong school-number or no substitution plan available';
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
          final dynamic inner = data['data'];
          if (inner is Map && inner['error'] != null) {
            switch (inner['error']) {
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
      }
      return ListPage(
        title: headerTitle,
        onRefresh: () => getData(),
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
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: VPlanLogin(),
              ),
            ),
          ),
        ],
      );
    }
    if (data is Map && data['data'] is Map && data['data']['date'] != null) {
      try {
        displayDateDateTime = VPlanAPI()
            .parseStringDatatoDateTime(data['data']['date'].toString());
        displayDate = DateFormat('dd.MM.yyyy').format(displayDateDateTime);
      } catch (_) {
        displayDate = '...';
      }
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
      onRefresh: () => getData(showLoading: false),
      actions: [
        IconButton(
          onPressed: () async {
            await VPlanAPI().removePlanByDate(data['data']['date']);
            getData();
          },
          icon: Icon(Icons.refresh, size: 20),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            SwipePageTransition(
              type: PageTransitionType.rightToLeft,
              child: widget.person != null
                  ? PersonCourses(
                      classId: widget.classId,
                      person: widget.person!,
                      isNew: false,
                      onSaved: (courses) {
                        setState(() {
                          widget.person!['courses'] = courses;
                        });
                        getData(showLoading: false);
                      },
                    )
                  : Courses(
                      classId: widget.classId,
                      updateCourses: () => getData(showLoading: false),
                    ),
            ),
          ),
          icon: Icon(
            Icons.settings_rounded,
            size: 20,
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
            ? const <Widget>[SizedBox.shrink()]
            : _buildLessons(data['data']['data'] as List)),
        data != 'loading' ? const SizedBox() : const SizedBox(),
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
      } else if (vplanAPI.isLessonHidden(e, hiddenSubjects ?? [])) {
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
    String? initData =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'initializedClasses'));
    if (initData != null && initData.isNotEmpty) {
      try {
        initialized = Map<String, dynamic>.from(
            Map<String, dynamic>.from(jsonDecode(initData)) as Map);
      } catch (e) {}
    }
    bool isFirstOpen = !initialized.containsKey(widget.classId);
    if (isFirstOpen) {
      initialized[widget.classId] = true;
      await prefs.setString(
          SchoolStorage.scopedKey(prefs, 'initializedClasses'),
          jsonEncode(initialized));
    }

    List<String> hiddenCourses =
        await vplanAPI.getHiddenCourses(widget.classId);
    if (isFirstOpen &&
        !vplanAPI.isDemoMode &&
        hiddenCourses.isEmpty &&
        _courses.isNotEmpty) {
      // Hide all courses for first-time setup (demo mode keeps them
      // visible so the substitution plan shows real lessons).
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

    courses.sort((a, b) {
      final ca = (a['course'] as String?) ?? '';
      final cb = (b['course'] as String?) ?? '';
      final ua = ca.isNotEmpty && ca[0] != ca[0].toLowerCase();
      final ub = cb.isNotEmpty && cb[0] != cb[0].toLowerCase();
      if (ua != ub) return ua ? -1 : 1;
      return ca.toLowerCase().compareTo(cb.toLowerCase());
    });

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
            List<String> allCourses =
                courses.map((c) => c['course'] as String).toList();
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
                    : Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.4),
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
                    await vplanAPI.addHiddenCourse(widget.classId, e['course']);
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
  final bool
      isNew; // true: created & added to storage on save, false: updates existing person
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
                      : Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.4),
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
                                  decoration: !isShown
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: !isShown ? Colors.grey : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '(${e['teacher']})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  decoration: !isShown
                                      ? TextDecoration.lineThrough
                                      : null,
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
                            transitionBuilder:
                                (Widget child, Animation<double> animation) =>
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
