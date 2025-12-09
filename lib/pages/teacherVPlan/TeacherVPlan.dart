import 'package:expandiware/models/InputField.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './TeacherPlan.dart';

import 'package:expandiware/models/LoadingProcess.dart';
import 'package:expandiware/models/Button.dart';

import '../vplan/VPlanAPI.dart';
import '../dashboard/settings/VPlanLogin.dart';

class TeacherVPlan extends StatefulWidget {
  const TeacherVPlan({Key? key}) : super(key: key);

  @override
  _TeacherVPlanState createState() => _TeacherVPlanState();
}

class _TeacherVPlanState extends State<TeacherVPlan> {
  String teacherShort = '';
  double spaceBetween = 50;
  String searchText = '';
  DateTime selectedDate = DateTime.now();

  TextEditingController textFieldController = new TextEditingController();

  void setTeacherShort(String newValue) {
    teacherShort = newValue;
    textFieldController.text = newValue;
  }

  @override
  void initState() {
    super.initState();
    textFieldController.addListener(() {
      searchText = textFieldController.text;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget scannWidget = Container(
      margin: EdgeInsets.all(20),
      child: FutureBuilder(
        future: Future.delayed(Duration(microseconds: 1)),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return LoadingProcess();
          }
          return TeacherList(
            setTeacherShort: this.setTeacherShort,
            searchText: searchText,
          );
        },
      ),
    );
    return Container(
      margin: EdgeInsets.only(
        left: 50,
        right: 50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.searchTeachers,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(height: spaceBetween * 0.3),
          InputField(
            controller: textFieldController,
            labelText: AppLocalizations.of(context)!.teacherAbbreviationHint,
          ),
          SizedBox(height: spaceBetween * 0.3),
          Container(
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
              color: Theme.of(context).backgroundColor,
            ),
            child: InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(Duration(days: 30)),
                  lastDate: DateTime.now().add(Duration(days: 30)),
                );
                if (picked != null && picked != selectedDate) {
                  setState(() {
                    selectedDate = picked;
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
                  SizedBox(width: 10),
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
          SizedBox(height: spaceBetween * 0.3),
          Button(
            text: AppLocalizations.of(context)!.see,
            onPressed: () async {
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
                return;
              }
              
              // Wenn Zugangsdaten vorhanden sind, navigiere weiter
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: TeacherPlan(
                    teacher: textFieldController.text,
                    selectedDate: selectedDate,
                  ),
                ),
              );
            },
          ),
          scannWidget,
        ],
      ),
    );
  }
}

class TeacherList extends StatefulWidget {
  final Function setTeacherShort;
  final String searchText;

  const TeacherList({
    Key? key,
    required this.setTeacherShort,
    required this.searchText,
  }) : super(key: key);

  @override
  _TeacherListState createState() => _TeacherListState();
}

class _TeacherListState extends State<TeacherList> {
  List<dynamic> teachers = [];

  Future<void> getTeachers() async {
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
  }

  @override
  Widget build(BuildContext context) {
    // Create a filtered list for display without modifying the original
    List<dynamic> displayTeachers = List.from(teachers);

    if (widget.searchText != '' && displayTeachers.isNotEmpty && displayTeachers[0] != AppLocalizations.of(context)!.scanningTeacherAbbreviations) {
      List<dynamic> filteredList = [];
      try {
        RegExp exp = new RegExp(
          '${widget.searchText.toLowerCase()}[a-z,ö,ä,ü]*',
        );
        for (int i = 0; i < displayTeachers.length; i++) {
          if (exp.hasMatch(displayTeachers[i]['short'].toString().toLowerCase())) {
            filteredList.add(displayTeachers[i]);
          }
        }
        displayTeachers = filteredList;
      } catch (e) {
        // If regex fails, show all teachers
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      child: displayTeachers.isEmpty || displayTeachers[0] == AppLocalizations.of(context)!.scanningTeacherAbbreviations
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: displayTeachers.isEmpty
                  ? [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context).focusColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noTeachersFound,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).focusColor.withOpacity(0.7),
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
                          ),
                        ),
                      )
                      .toList(),
            )
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: BouncingScrollPhysics(),
              childAspectRatio: 2 / 1.3,
              children: [
                ...displayTeachers.map(
                  (e) => Container(
                    margin: EdgeInsets.all(5),
                    child: InkWell(
                      onTap: () => widget.setTeacherShort(e['short']),
                      child: Container(
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Theme.of(context).backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            e['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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
