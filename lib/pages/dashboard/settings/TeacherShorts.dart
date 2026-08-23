import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../models/QRScanner.dart';
import 'package:page_transition/page_transition.dart';

import '../../../models/swipe_page_transition.dart';

import '../../../models/InputField.dart';
import '../../../models/ListPage.dart';
import '../../vplan/VPlanAPI.dart';
import '../../../services/SchoolStorage.dart';

class TeacherShorts extends StatefulWidget {
  TeacherShorts({Key? key}) : super(key: key);

  @override
  State<TeacherShorts> createState() => _TeacherShortsState();
}

class _TeacherShortsState extends State<TeacherShorts> {
  List<dynamic> teachers = [];

  getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> teacherShorts = await VPlanAPI().getTeachers();
    final String key = SchoolStorage.scopedKey(prefs, 'teacherShorts');

    if (prefs.getString(key) == null || prefs.getString(key) == '') {
      List<dynamic> addList = [];
      for (int i = 0; i < teacherShorts.length; i++) {
        addList.add({
          'short': teacherShorts[i],
          'realName': '',
        });
      }
      prefs.setString(key, jsonEncode(addList));
    }

    List<dynamic> teacherShortConvert = jsonDecode(prefs.getString(key)!);

    for (int i = 0; i < teacherShorts.length; i++) {
      teachers.add({
        'short': teacherShorts[i],
        'realName': teacherShortConvert[i]['realName'],
        'controller': TextEditingController(
          text: teacherShortConvert[i]['realName'],
        ),
        'currently_added': false,
      });
    }
    teachers.sort((a, b) => a['short'].compareTo(b['short']));
    setState(() {});
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
        title: AppLocalizations.of(context)!.setTeacherAbbreviations,
        /*actions: [
          IconButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              String teacherShorts =
                  prefs.getString(SchoolStorage.scopedKey(prefs, "teacherShorts"))!;

              Navigator.push(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: ScanPage(data: teacherShorts),
                ),
              );
            },
            icon: Icon(
              Icons.share_rounded,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: QRScanner(
                  setData: (String result) async {
                    print('scanned something');
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();

                    List<dynamic> currentTeacherShorts =
                        jsonDecode(prefs.getString(SchoolStorage.scopedKey(prefs, 'teacherShorts'))!);

                    List<dynamic> sharedTeacherShorts = jsonDecode(result);

                    for (int i = 0; i < currentTeacherShorts.length; i++) {
                      if (currentTeacherShorts[i]['realName'] == '') {
                        for (int j = 0; j < sharedTeacherShorts.length; j++) {
                          if (currentTeacherShorts[i]['short'] ==
                              sharedTeacherShorts[j]['short']) {
                            currentTeacherShorts[i]['realName'] =
                                sharedTeacherShorts[i]['realName'];
                          }
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            icon: Icon(Icons.qr_code_scanner_rounded),
          ),
        ],*/
        children: [
          ...teachers.map(
            (e) => Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.all(5),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        e['short'],
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: InputField(
                      controller: e['controller'],
                      labelText: AppLocalizations.of(context)!.realName,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(5),
                    child: InkWell(
                      onTap: () async {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        String value =
                            (e['controller'] as TextEditingController).text;

                        List<dynamic> _teacherShorts = jsonDecode(
                            prefs.getString(SchoolStorage.scopedKey(
                                prefs, 'teacherShorts'))!);

                        for (int i = 0; i < _teacherShorts.length; i++) {
                          if (_teacherShorts[i]['short'] == e['short']) {
                            _teacherShorts[i]['realName'] = value;
                          }
                        }
                        prefs.setString(
                          SchoolStorage.scopedKey(prefs, 'teacherShorts'),
                          jsonEncode(_teacherShorts),
                        );
                        setState(() => e['currently_added'] = true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: e['currently_added']
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            e['currently_added']
                                ? Icons.save_rounded
                                : Icons.save_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanPage extends StatelessWidget {
  const ScanPage({
    Key? key,
    required this.data,
  }) : super(key: key);

  final String data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListPage(
        title: AppLocalizations.of(context)!.shareTeacherName,
        children: [
          Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PrettyQr(
                size: MediaQuery.of(context).size.width,
                data: data,
                elementColor: Colors.black,
                errorCorrectLevel: QrErrorCorrectLevel.L,
                typeNumber: 40,
                roundEdges: false,
                //image: AssetImage('assets/img/logo.png'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
