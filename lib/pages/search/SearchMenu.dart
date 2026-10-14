import 'package:substitute/models/ListItem.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/NativeShell.dart';

import '../../models/swipe_page_transition.dart';
import '../dashboard/FindRoom.dart';
import '../dashboard/SickTrack.dart';
import '../teacherVPlan/TeacherVPlan.dart';

/// Zentrales Such-Menü: bündelt alle Suchfunktionen (Lehrer, freie Räume,
/// Raumplan) **und** den Krankheitstracker. Wird als eigener Tab im unteren
/// Menü angezeigt.
///
/// ## Warum der Krankheitstracker hier steht
///
/// Er stand vorher im „Dashboard“ – einem Bildschirm am rechten Rand der
/// Leiste, der inzwischen die Einstellungen sind und selbst nichts mehr war.
/// Dort war er der einzige Eintrag, der nichts mit einem Suchbegriff zu tun
/// hatte, und wer eine verpasste Stunde nachsehen wollte, musste erst den
/// rechten Reiter finden.
///
/// Der Tracker **sucht** genauso wie die beiden anderen: nach der Klasse, der
/// die Stunden gefehlt haben. Er gehoert damit an dieselbe Stelle und nicht in
/// eine Liste, die sich um etwas anderes dreht.
///
/// Auf iOS ist das derselbe Weg: Dort liegt der Such-Reiter als Flutter-Ansicht
/// in der nativen Schale, und der Werkzeugkasten ist nicht mehr dafuer da.
class SearchMenu extends StatelessWidget {
  SearchMenu({Key? key}) : super(key: key);

  final double margin = 8;

  @override
  Widget build(BuildContext context) {
    // Als [List] und nicht als [Map]: Eine [Map] garantiert die Reihenfolge
    // nicht, und hier ist sie ausdrücklich gewollt.
    //
    // Der Krankheitstracker steht **oben**: Nach einer verpassten Stunde ist er
    // das Erste, was jemand nachschlägt – und er ist der einzige der drei
    // Wege, bei dem es um etwas geht, das man *schon* weiß („welche Stunden
    // habe ich verpasst?“). Die beiden anderen beantworten erst die Frage
    // *wonach*.
    List<dynamic> elements = [
      {
        'icon': Icon(
          Icons.sick_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.sickTrack,
        'subtitle': AppLocalizations.of(context)!.sickTrackSubtitle,
        'link': const SickTrack(),
      },
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
      // Keine eigene Hoehe mehr: Vorher stand hier `size.height * 0.69` plus
      // ein weiteres Zehntel als unterer Rand – zusammen fast vier Fuenftel des
      // Bildschirms fuer drei Eintraege, die nicht so viel brauchen. Die Liste
      // nimmt jetzt den Platz, der da ist, und hoeher wird sie dadurch nicht.
      //
      // Die Android-Leiste bleibt ausserhalb des Inhalts. Auf iOS steht der
      // Abstand dagegen ausschliesslich am Ende der Liste, damit die native
      // Leiste direkt ueber dem Inhalt liegen kann.
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
            const NativeShellScrollEndInset(),
          ],
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
