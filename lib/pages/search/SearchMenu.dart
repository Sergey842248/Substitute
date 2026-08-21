import 'package:animations/animations.dart';
import 'package:expandiware/models/ListItem.dart';
import 'package:flutter/material.dart';
import 'package:expandiware/l10n/app_localizations.dart';

import '../dashboard/FindRoom.dart';
import '../dashboard/RoomPlan.dart';
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
          Icons.place_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.findFreeRoom,
        'subtitle': AppLocalizations.of(context)!.findFreeRoomSubtitle,
        'link': const FindRoom(),
      },
      {
        'icon': Icon(
          Icons.meeting_room_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.roomPlan,
        'subtitle': AppLocalizations.of(context)!.roomPlanSubtitle,
        'link': const RoomPlan(),
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
                child: OpenContainer(
                  closedColor: Theme.of(context).scaffoldBackgroundColor,
                  openColor: Theme.of(context).scaffoldBackgroundColor,
                  closedBuilder: (context, openContainer) => ListItem(
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
                    onClick: openContainer,
                    actionButton: IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Theme.of(context).focusColor,
                      ),
                      onPressed: () => openContainer(),
                    ),
                  ),
                  openBuilder: (context, closeBuilder) => Center(
                    child: e['link'],
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
