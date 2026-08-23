import 'dart:async';

import 'package:substitute/models/InputField.dart';
import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';

import '../models/swipe_page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './TeacherPlan.dart';

import 'package:substitute/models/LoadingProcess.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/models/Button.dart';

import '../vplan/VPlanAPI.dart';
import '../dashboard/settings/VPlanLogin.dart';
import '../../services/SchoolStorage.dart';

Timer? _debounceTimer;
late VoidCallback _textListener;

class TeacherVPlan extends StatefulWidget {
  const TeacherVPlan({Key? key}) : super(key: key);
  @override
  _TeacherVPlanState createState() => _TeacherVPlanState();
}

class _TeacherVPlanState extends State<TeacherVPlan> {
  String teacherShort = '';
  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  TextEditingController textFieldController = new TextEditingController();

  void setTeacherShort(String newValue) {
    teacherShort = newValue;
    textFieldController.text = newValue;
  }

  /// Schlüssel für den oberen Bereich (Suchfeld, Datum, Button), dessen Höhe
  /// gemessen wird, damit die Lehrerliste den restlichen Platz bis zum
  /// unteren Bildschirmrand ausfüllt.
  final GlobalKey _topSectionKey = GlobalKey();
  double _gridHeight = 250;

  void _measureGridHeight() {
    if (!mounted) return;
    final BuildContext? topCtx = _topSectionKey.currentContext;
    if (topCtx == null) return;
    final RenderBox? box = topCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // Verfügbare Höhe im ListPage-Inhalt: Bildschirm minus Statusleiste,
    // minus Header (~10% Höhe + abgerundete Ecken) und minus der Padding der
    // Inhaltsfläche.
    final double screenH = MediaQuery.of(context).size.height;
    final double statusBar = MediaQuery.of(context).padding.top;
    final double available = screenH - statusBar - screenH * 0.1 - 30 - 15 - 10;
    final double h = available - box.size.height;
    if (h > 100 && (h - _gridHeight).abs() > 1) {
      setState(() => _gridHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureGridHeight());
    return ListPage(
      title: AppLocalizations.of(context)!.searchTeachers,
      smallTitle: true,
      children: [
        Column(
          key: _topSectionKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputField(
              controller: textFieldController,
              labelText: AppLocalizations.of(context)!.teacherAbbreviationHint,
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    });
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.selectedDate(
                        selectedDate.day.toString(),
                        selectedDate.month.toString(),
                        selectedDate.year.toString(),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Button(
              text: AppLocalizations.of(context)!.see,
              onPressed: () async {
                // Prüfe, ob Zugangsdaten vorhanden sind
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String? username = prefs
                    .getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

                if (username == null || username == '') {
                  // Zeige Login-Dialog wenn keine Zugangsdaten vorhanden sind
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
                            Text(AppLocalizations.of(context)!
                                .dontForgetCredentials),
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
                  return;
                }

                // Wenn Zugangsdaten vorhanden sind, navigiere weiter
                Navigator.push(
                  context,
                  SwipePageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: TeacherPlan(
                      teacher: textFieldController.text,
                      selectedDate: selectedDate,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        FutureBuilder(
          future: Future.delayed(const Duration(microseconds: 1)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingProcess();
            }
            return TeacherList(
              setTeacherShort: setTeacherShort,
              textController: textFieldController,
              height: _gridHeight,
            );
          },
        ),
      ],
    );
  }
}

class TeacherList extends StatefulWidget {
  final Function setTeacherShort;
  final TextEditingController textController;
  final double height;

  const TeacherList({
    Key? key,
    required this.setTeacherShort,
    required this.textController,
    this.height = 300,
  }) : super(key: key);

  @override
  _TeacherListState createState() => _TeacherListState();
}

class _TeacherListState extends State<TeacherList> {
  List<dynamic> teachers = [];
  String searchText = '';
  Timer? _debounceTimer;

  Future<void> getTeachers() async {
    // Prüfe, ob Zugangsdaten vorhanden sind
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

    if (username == null || username == '') {
      // Zeige Login-Dialog wenn keine Zugangsdaten vorhanden sind
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

    // Wenn Zugangsdaten vorhanden sind, lade die Lehrer
    VPlanAPI vplanAPI = new VPlanAPI();
    List<String> teacherShorts = await vplanAPI.getTeachers();

    teachers = [];
    for (int i = 0; i < teacherShorts.length; i++) {
      teachers.add({
        'short': teacherShorts[i],
        'name': await vplanAPI.replaceTeacherShort(teacherShorts[i]),
      });
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getTeachers();

    _textListener = () {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 5000), () {
        if (!mounted) return;
        setState(() {
          searchText = widget.textController.text;
        });
      });
    };

    widget.textController.addListener(_textListener);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.textController.removeListener(_textListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create a filtered list for display without modifying the original
    List<dynamic> displayTeachers = List.from(teachers);

    if (searchText != '' &&
        displayTeachers.isNotEmpty &&
        displayTeachers[0] !=
            AppLocalizations.of(context)!.scanningTeacherAbbreviations) {
      List<dynamic> filteredList = [];
      try {
        RegExp exp = new RegExp(
          '${searchText.toLowerCase()}[a-z,ö,ä,ü]*',
        );
        for (int i = 0; i < displayTeachers.length; i++) {
          if (exp
              .hasMatch(displayTeachers[i]['short'].toString().toLowerCase())) {
            filteredList.add(displayTeachers[i]);
          }
        }
        displayTeachers = filteredList;
      } catch (e) {
        // If regex fails, show all teachers
      }
    }

    return Container(
      height: widget.height,
      child: displayTeachers.isEmpty ||
              displayTeachers[0] ==
                  AppLocalizations.of(context)!.scanningTeacherAbbreviations
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: displayTeachers.isEmpty
                  ? [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color:
                            Theme.of(context).focusColor.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noTeachersFound,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .focusColor
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ]
                  : displayTeachers
                      .map(
                         (e) => Text(
                           e,
                           style: TextStyle(
                             fontWeight: FontWeight.w600,
                             fontSize: 16,
                             color: Theme.of(context).colorScheme.onSurface,
                           ),
                         ),
                      )
                      .toList(),
            )
          : GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: BouncingScrollPhysics(),
              childAspectRatio: 2 / 1.1,
              children: [
                ...displayTeachers.map(
                  (e) => Container(
                    margin: EdgeInsets.all(3),
                    child: InkWell(
                      onTap: () => widget.setTeacherShort(e['short']),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            e['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
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
