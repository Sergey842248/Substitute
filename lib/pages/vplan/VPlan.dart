import 'package:substitute/models/Button.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/pages/dashboard/settings/Lessons.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:convert';

import 'package:page_transition/page_transition.dart';

import '../../models/swipe_page_transition.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';

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
  List<Map<String, dynamic>> persons = [];
  bool hidePersons = false;
  final listKey = GlobalKey<AnimatedListState>();

  void getClasses() async {
    classes = [];

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    List<String>? prefClasses =
        prefs.getStringList(SchoolStorage.scopedKey(prefs, 'classes'));
    if (prefClasses == null) {
      prefClasses = [];
    }

    final listState = listKey.currentState;
    if (listState != null) {
      for (int i = 0; i < prefClasses.length; i++) {
        listState.insertItem(i);
        classes.add(prefClasses[i]);
      }
    } else {
      classes.addAll(prefClasses);
    }

    // One-time migration: older versions stored 'hidePersons' with a default
    // of OFF. Reset any stored value once so the new default applies.
    if (!(prefs
            .getBool(SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated')) ??
        false)) {
      await prefs.remove(SchoolStorage.scopedKey(prefs, 'hidePersons'));
      await prefs.setBool(
          SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated'), true);
    }
    hidePersons =
        prefs.getBool(SchoolStorage.scopedKey(prefs, 'hidePersons')) ?? false;
    persons = await VPlanAPI().getPersons();
    if (!mounted) return;
    setState(() {});

    String? username =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

    if (classes.length == 0 && (username == null || username == '')) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                    SwipePageTransition(
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

  Widget _personsSection() {
    // Persons section can be hidden in the plan settings
    if (hidePersons) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(
                AppLocalizations.of(context)!.persons,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: _openAddPerson,
              icon: Icon(Icons.person_add_alt_1_rounded),
              tooltip: AppLocalizations.of(context)!.addPerson,
            ),
          ],
        ),
        ...persons.map((person) {
          return ListItem(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person['name'],
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  person['classId'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            actionButton: IconButton(
              onPressed: () => _deletePerson(person),
              icon: Icon(
                Icons.delete_rounded,
                color: Theme.of(context).focusColor.withValues(alpha: 0.5),
              ),
            ),
            onClick: () {
              Navigator.push(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: Scaffold(
                    body: Plan(
                      classId: person['classId'],
                      person: person,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  void _deletePerson(Map<String, dynamic> person) async {
    await VPlanAPI().deletePerson(person['id']);
    setState(() {
      persons.remove(person);
    });
  }

  Future<void> _openAddPerson() async {
    final VPlanAPI vplanAPI = VPlanAPI();

    // Step 1: Pick a class for the new person
    final completer = Completer<String?>();
    await Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: SelectClass(
            personMode: true,
            pop: (className) {
              if (!completer.isCompleted) completer.complete(className);
            },
            favs: [],
          ),
        ),
      ),
    ).then((_) {
      // If the user left the class selection without picking one, abort
      if (!completer.isCompleted) completer.complete(null);
    });
    final String? className = await completer.future;
    if (className == null || !mounted) return;

    // Step 2: Enter the person's name
    final TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.personName,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.personName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    // Step 3: Choose the courses to show for this person
    final person = {
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'classId': className,
      'courses': <String>[],
    };
    await Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: PersonCourses(
            classId: className,
            person: person,
            isNew: true,
          ),
        ),
      ),
    );

    persons = await vplanAPI.getPersons();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _personsSection(),
            const SizedBox(height: 2),
            ListItem(
              margin: 5,
              title: Text(
                AppLocalizations.of(context)!.selectClass,
                style: TextStyle(
                  fontSize: 19,
                ),
              ),
              onClick: () => Navigator.push(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: SelectClass(
                    pop: (String classId) {
                      listKey.currentState!.insertItem(classes.length);
                      classes.add(classId);
                    },
                    favs: classes,
                  ),
                ),
              ),
            ),
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Scrollbar(
                radius: Radius.circular(100),
                child: AnimatedList(
                  padding: EdgeInsets.zero,
                  physics: BouncingScrollPhysics(),
                  key: listKey,
                  initialItemCount: classes.length,
                  itemBuilder: (context, index, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: ClassWidget(
                      classId: classes[index],
                      classIndex: index,
                      onDelete: () async {
                        String classId = classes[index];
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        List<String>? newClasses = prefs.getStringList(
                            SchoolStorage.scopedKey(prefs, 'classes'));
                        if (newClasses == null) {
                          newClasses = [];
                        }
                        newClasses.remove(classId);
                        prefs.setStringList(
                            SchoolStorage.scopedKey(prefs, 'classes'),
                            newClasses);
                        // Auch die gespeicherten Kurs-Auswahlen und den
                        // benutzerdefinierten Namen der Klasse zurücksetzen,
                        // damit eine später erneut hinzugefügte Klasse wieder
                        // mit allen Kursen startet.
                        await VPlanAPI().removeHiddenCoursesForClass(classId);
                        await VPlanAPI().removeClassName(classId);

                        listKey.currentState!.removeItem(
                          index,
                          (context, animation) => SizeTransition(
                            sizeFactor: animation,
                            child: ListItem(
                              onClick: () {},
                              title: Text(
                                classId,
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
                      openContainer: () => Navigator.push(
                        context,
                        SwipePageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: Plan(
                            classId: classes[index],
                          ),
                        ),
                      ),
                    ), // closes ClassWidget
                  ), // closes SizeTransition
                ), // closes AnimatedList
              ), // closes Scrollbar
            ), // closes the height Container
          ], // closes Column's children
        ), // closes Column
      ), // closes SingleChildScrollView
    ); // closes outer Container
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
  String? customName;
  bool hideLessonTimes = true;

  Future<void> _loadCustomName() async {
    String? name = await VPlanAPI().getClassName(widget.classId);
    if (mounted && name != customName) {
      setState(() {
        customName = name;
      });
    }
  }

  Future<void> _renameClass() async {
    final TextEditingController nameController =
        TextEditingController(text: customName ?? widget.classId);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.renameClass,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.classNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    await VPlanAPI().setClassName(widget.classId, newName);
    if (mounted) {
      setState(() {
        customName = newName.isEmpty ? null : newName;
      });
    }
  }

  TimeOfDay? _safeToTimeOfDay(dynamic value) {
    final String time = value?.toString() ?? '';
    if (time.isEmpty || !time.contains(':')) return null;
    try {
      final List<String> parts = time.split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Aktualisiert die „Nächste Stunde“-Vorschau. Zuerst wird offline (ohne
  /// Netzwerkwarten) die zuletzt bekannte Vorschau angezeigt, anschließend
  /// werden im Hintergrund frische Daten geholt und die Vorschau nur ersetzt,
  /// wenn sich tatsächlich etwas geändert hat – es wird nie eine
  /// Ladeanimation gezeigt.
  ///
  /// [forceRefresh] == true lädt frisch vom Server, andernfalls werden
  /// (ohne Ladezeit) die lokal gespeicherten Daten verwendet.
  getData({bool silent = false, bool forceRefresh = false}) async {
    final Map<String, dynamic> oldNextLesson = nextLesson;
    final VPlanAPI vplanAPI = VPlanAPI();

    void refreshIfChanged() {
      if (silent && mapEquals(oldNextLesson, nextLesson)) return;
      if (mounted) setState(() {});
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
    } catch (_) {
      hideLessonTimes = true;
    }

    List<String> hiddenCourses = [];
    try {
      hiddenCourses = await vplanAPI.getHiddenCourses(widget.classId);
    } catch (_) {
      hiddenCourses = [];
    }

    dynamic vplan;
    try {
      vplan = forceRefresh
          ? await vplanAPI
              .getLessonsForToday(widget.classId, forceRefresh: true)
          : await vplanAPI.getCachedLessonsForToday(widget.classId);
    } catch (_) {
      refreshIfChanged();
      return;
    }
    if (vplan is! Map || vplan['data'] is! List) {
      refreshIfChanged();
      return;
    }

    await _setNextLessonFromPlan(vplanAPI, vplan, hiddenCourses,
        allowNextDay: forceRefresh);
    // Zuletzt berechnete Vorschau speichern, damit sie beim nächsten Öffnen
    // sofort (ohne Ladezeit) angezeigt wird.
    saveNextLesson(widget.classId, nextLesson);
    refreshIfChanged();
  }

  /// Berechnet die „Nächste Stunde“-Vorschau aus einem Plan und setzt
  /// [nextLesson]. [allowNextDay] == false (sofortiger Cache-Pfad) löst keine
  /// weitere Netzwerkanfrage für den Folgetag aus – das übernimmt der
  /// Hintergrund-Refresh.
  Future<void> _setNextLessonFromPlan(
    VPlanAPI vplanAPI,
    Map vplan,
    List<String> hiddenCourses, {
    bool allowNextDay = true,
  }) async {
    List<dynamic> realVPlan = [];
    for (var i = 0; i < vplan['data'].length; i++) {
      bool add = !vplanAPI.isLessonHidden(vplan['data'][i], hiddenCourses) &&
          vplan['data'][i]['course'] != '---' &&
          vplan['data'][i]['lesson'] != null;
      if (add) {
        realVPlan.add(vplan['data'][i]);
      }
    }

    // GET NEXT LESSON
    TimeOfDay currentTime = TimeOfDay.now();
    try {
      if (vplan['date'] != null &&
          VPlanAPI()
              .parseStringDatatoDateTime(vplan['date'].toString())
              .isAfter(DateTime.now())) {
        currentTime = TimeOfDay(hour: 0, minute: 0);
      }
    } catch (_) {
      // Datum nicht auswertbar – mit der aktuellen Zeit weiterarbeiten.
    }

    double lowestDifference = 50;
    int lessonIndex = 0;
    bool foundNextLesson = false;
    for (var i = 0; i < realVPlan.length; i++) {
      Map<String, dynamic> lesson = realVPlan[i];
      final TimeOfDay? beginTime = _safeToTimeOfDay(lesson['begin']);
      if (beginTime == null) continue;
      double difference = (beginTime.hour + (beginTime.minute / 60)) -
          (currentTime.hour + (currentTime.minute / 60));
      if (difference < lowestDifference && difference >= 0) {
        lowestDifference = difference;
        lessonIndex = i;
        foundNextLesson = true;
      }
    }

    if (foundNextLesson) {
      nextLesson = realVPlan[lessonIndex];
      return;
    }

    // Keine Stunde mehr heute: Wochenende oder nach Schulschluss.
    DateTime now = DateTime.now();
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      nextLesson = {'weekend': true};
      return;
    }

    bool afterSchool = false;
    if (realVPlan.isNotEmpty) {
      Map<String, dynamic> lastLesson = realVPlan.last;
      final TimeOfDay? endTime = _safeToTimeOfDay(lastLesson['end']);
      if (endTime != null) {
        double lastLessonEndTime = (endTime.hour + (endTime.minute / 60));
        afterSchool = (currentTime.hour + (currentTime.minute / 60)) >
            lastLessonEndTime;
      }
    } else {
      afterSchool = true;
    }

    if (!afterSchool) {
      nextLesson = {};
      return;
    }

    if (!allowNextDay) {
      // Beim sofortigen Cache-Pfad keine weitere Netzwerkanfrage für den
      // Folgetag auslösen – der Hintergrund-Refresh korrigiert das.
      nextLesson = {};
      return;
    }

    // Determine the next school day
    DateTime nextDay = now.add(const Duration(days: 1));
    while (nextDay.weekday == DateTime.saturday ||
        nextDay.weekday == DateTime.sunday) {
      nextDay = nextDay.add(const Duration(days: 1));
    }

    try {
      dynamic nextDayVplan = await VPlanAPI().getLessonsByDate(
        date: nextDay,
        classId: widget.classId,
      );

      if (nextDayVplan != null &&
          nextDayVplan['data'] != null &&
          nextDayVplan['data'].isNotEmpty) {
        // Filter hidden courses from the next day's lessons
        List<dynamic> nextDayRealVPlan = [];
        for (var i = 0; i < nextDayVplan['data'].length; i++) {
          bool add = !vplanAPI.isLessonHidden(
                  nextDayVplan['data'][i], hiddenCourses) &&
              nextDayVplan['data'][i]['course'] != '---' &&
              nextDayVplan['data'][i]['lesson'] != null;
          if (add) {
            nextDayRealVPlan.add(nextDayVplan['data'][i]);
          }
        }

        if (nextDayRealVPlan.isNotEmpty) {
          nextLesson = nextDayRealVPlan.first;
        } else {
          nextLesson = {'weekend': true};
        }
      } else {
        nextLesson = {'weekend': true};
      }
    } catch (e) {
      nextLesson = {'weekend': true};
    }
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
    // Sofort (ohne Ladezeit und ohne await) die zuletzt gespeicherte
    // „Nächste Stunde“-Vorschau anzeigen – der allererste Frame zeigt also
    // bereits den letzten Stand.
    nextLesson = cachedNextLesson(widget.classId) ?? {'': 'loading'};
    // 1) Lokale Vorschau (Cache) anzeigen.
    getData();
    // 2) Im Hintergrund frische Daten laden und – nur wenn nötig – ersetzen.
    getData(silent: true, forceRefresh: true);
    _loadCustomName();
    vplanBackgroundRefresh.addListener(_onBackgroundRefresh);
  }

  /// Reaktioniert auf den Hintergrund-Refresh beim App-Start: Die Vorschau
  /// wird im Hintergrund neu geladen, aber nur für diesen Favoriten neu
  /// gezeichnet, wenn sich die nächste Stunde / der Plan tatsächlich geändert
  /// hat.
  void _onBackgroundRefresh() {
    getData(silent: true, forceRefresh: true);
  }

  @override
  void dispose() {
    vplanBackgroundRefresh.removeListener(_onBackgroundRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double spaceBetween = 10;
    return Container(
      margin: EdgeInsets.only(left: 5, right: 5, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListItem(
            title: Text(
              customName ?? widget.classId,
              style: TextStyle(
                fontSize: 19,
              ),
            ),
            onClick: widget.openContainer,
            actionButton: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _renameClass,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                  tooltip: AppLocalizations.of(context)!.renameClass,
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            margin: 0,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
           GestureDetector(
             onTap: () => widget.openContainer(),
             child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              child: child,
            ),
            child: Container(
              key: ValueKey(nextLesson),
              width: double.infinity,
              alignment: Alignment.center,
              child: nextLesson.toString() == '{: loading}'
                  ? const SizedBox.shrink()
                  : (nextLesson['weekend'] == true
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.weekend_rounded,
                              size: 30,
                              color: Theme.of(context)
                                  .focusColor
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context)!.weekend,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        )
                      : (nextLesson.toString() == '{}'
                          ?                             Text(
                              AppLocalizations.of(context)!.noNextLessonFound,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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
                                      nextLesson['lesson'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 21,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    SizedBox(height: spaceBetween),
                                    Text(
                                      nextLesson['teacher'] ?? '',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    width: MediaQuery.of(context).size.width *
                                        0.3),
                                Column(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!
                                          .room(nextLesson['place'] ?? ''),
                                      style: TextStyle(
                                        fontSize: 19,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    SizedBox(height: spaceBetween),
                                    if (!hideLessonTimes)
                                      Text(
                                          '${nextLesson['begin'] != null ? printTime(_safeToTimeOfDay(nextLesson['begin'])?.hour ?? 0, _safeToTimeOfDay(nextLesson['begin'])?.minute ?? 0) : ''} - ${nextLesson['end'] != null ? printTime(_safeToTimeOfDay(nextLesson['end'])?.hour ?? 0, _safeToTimeOfDay(nextLesson['end'])?.minute ?? 0) : ''}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          )),
                                  ],
                                ),
                              ],
                            ))),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
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
    this.personMode = false,
  }) : super(key: key);

  final Function pop;
  final List<String> favs;
  final bool personMode;

  @override
  State<SelectClass> createState() => _SelectClassState();
}

class _SelectClassState extends State<SelectClass> {
  dynamic classes = [];
  void getClasses() async {
    // Prüfe, ob Zugangsdaten vorhanden sind
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

    if (!mounted) return;

    if (username == null || username == '') {
      // Zeige Login-Dialog wenn keine Zugangsdaten vorhanden sind
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                    SwipePageTransition(
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
    if (mounted) setState(() {});
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
              color: Theme.of(context).colorScheme.surface,
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
              SwipePageTransition(
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
              if (widget.personMode) {
                // Person creation: only report the picked class
                this.widget.pop(className);
                Navigator.pop(context);
                return;
              }
              SharedPreferences instance =
                  await SharedPreferences.getInstance();
              List<String>? _classes = instance
                  .getStringList(SchoolStorage.scopedKey(instance, 'classes'));
              if (_classes == null) {
                _classes = [];
              }
              _classes.add(className);
              instance.setStringList(
                  SchoolStorage.scopedKey(instance, 'classes'), _classes);

              // Optional: ask for a custom name for the class
              final TextEditingController nameController =
                  TextEditingController(text: className);
              final String? customName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Text(
                    AppLocalizations.of(context)!.nameClass,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19),
                  ),
                  content: TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.classNameHint,
                    ),
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
                      onPressed: () =>
                          Navigator.pop(context, nameController.text.trim()),
                      child: Text(
                        AppLocalizations.of(context)!.save,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (customName != null &&
                  customName.isNotEmpty &&
                  customName != className) {
                await VPlanAPI().setClassName(className, customName);
              }

              // Hide all courses for the new class by default – unless we are
              // in demo mode, where every subject should be visible so the
              // substitution plan actually shows lessons.
              final vplanApi = VPlanAPI();
              await vplanApi.login();
              if (!vplanApi.isDemoMode) {
                final courses = await vplanApi.getCourses(className);
                if (courses.isNotEmpty) {
                  final allCourseIds = courses
                      .map((c) => c['course'] as String)
                      .where((c) => c != '---')
                      .toList();
                  await vplanApi.setHiddenCourses(className, allCourseIds);
                }
              }

              // Add the class to VPlan's list
              this.widget.pop(className);

              // Replace SelectClass with Courses so the user lands
              // directly on course selection. Popping Courses later
              // returns to VPlan.
              Navigator.pushReplacement(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: Scaffold(
                    body: Courses(
                      classId: className,
                      updateCourses: () async {},
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
