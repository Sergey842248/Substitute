import 'package:expandiware/pages/dashboard/settings/Lessons.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

import 'settings/VPlanLogin.dart';
import 'settings/DeveloperOptions.dart';
import 'settings/Notifications.dart';
import 'settings/TeacherShorts.dart';

import '../../models/ListPage.dart';

class Settings extends StatefulWidget {
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  List<dynamic> settingPages = [
    {
      'title': 'Credentials',
      'icon': Icons.lock_outline_rounded,
      'subtitle': 'stundenplan24 credentials',
      'link': VPlanLogin(),
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications_none_rounded,
      'subtitle': 'Notifications for substitution plan',
      'link': Notifications(),
    },
    {
      'title': 'Set Teacher abbreviations',
      'icon': Icons.people_alt_outlined,
      'subtitle': 'Replace teacher abbreviations with Real ones',
      'link': TeacherShorts(),
    },
    {
      'title': 'Lessons',
      'icon': Icons.list_alt,
      'subtitle': 'Set time periods for lessons',
      'link': Lessons(),
    },
    {
      'title': 'Developer options',
      'icon': Icons.developer_mode_rounded,
      'subtitle': 'Change Settings meant for developers',
      'link': DeveloperOptions(),
    },
  ];

  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Settings',
      children: settingPages
          .map(
            (e) => Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              margin: EdgeInsets.all(10),
              child: Center(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: e['link'],
                    ),
                  ),
                  leading: Container(
                    margin: EdgeInsets.all(4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Icon(e['icon']),
                  ),
                  title: Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      e['title'],
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      e['subtitle'],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w100,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/*Container(
      alignment: Alignment.center,
      child: Stack(
        children: [
          Container(
            alignment: Alignment.topLeft,
            margin: EdgeInsets.only(top: 30, left: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Theme.of(context).focusColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 20),
                Text(
                  'Einstellungen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              child: Scrollbar(
                child: ListView(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  children: [
                    ...settingPages.map(
                      (e) => Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        margin: EdgeInsets.all(10),
                        child: Center(
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeft,
                                child: e['link'],
                              ),
                            ),
                            leading: Container(
                              margin: EdgeInsets.all(4),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: Color(
                                  int.parse('0xff${colors[e['colorIndex']]}'),
                                ),
                              ),
                              child: Icon(e['icon']),
                            ),
                            title: Padding(
                              padding: EdgeInsets.all(4),
                              child: Text(
                                e['title'],
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.all(4),
                              child: Text(
                                e['subtitle'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w100,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ); */
