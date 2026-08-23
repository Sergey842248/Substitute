import 'package:substitute/models/ListItem.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';

import '../../models/swipe_page_transition.dart';
import '../dashboard/FindRoom.dart';
import '../teacherVPlan/TeacherVPlan.dart';

/// Zentrales Such-Menü: bündelt alle Suchfunktionen (Lehrer, freie Räume,
/// Raumplan) an einem Ort. Wird als eigener Tab im unteren Menü angezeigt.
class SearchMenu extends StatelessWidget {
  SearchMenu({Key? key}) : super(key: key);

  final double margin = 8;

  @override
  Widget build(BuildContext context) {
    List<dynamic> elements = [
      {
        'icon': Icon(
          Icons.person_search_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.searchTeachers,
        'subtitle': AppLocalizations.of(context)!.searchTeachersSubtitle,
        'link': const TeacherVPlan(),
      },
      {
        'icon': Icon(
          Icons.meeting_room_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.roomPlan,
        'subtitle': AppLocalizations.of(context)!.roomPlanSubtitle,
        'link': const FindRoom(),
      },
    ];
    return Container(
      height: MediaQuery.of(context).size.height * 0.69,
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.1),
      alignment: Alignment.center,
      child: Scrollbar(
        thickness: 3,
        radius: const Radius.circular(100),
        thumbVisibility: true,
        controller: ScrollController(),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          shrinkWrap: true,
          children: [
            ...elements.map(
              (e) => Center(
                child: ListItem(
                  padding: 20,
                  leading: e['icon'],
                  title: Container(
                    margin: EdgeInsets.only(top: margin, bottom: margin),
                    child: Text(
                      e['title'],
                      style: TextStyle(
                        color: Theme.of(context).focusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: Container(
                    margin: EdgeInsets.only(top: margin, bottom: margin),
                    child: Text(e['subtitle']),
                  ),
                  onClick: () => Navigator.push(
                    context,
                    SwipePageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: e['link'],
                    ),
                  ),
                  actionButton: IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Theme.of(context).focusColor,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      SwipePageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: e['link'],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
