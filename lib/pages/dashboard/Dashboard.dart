import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';

import '../../models/ListItem.dart';
import '../../models/swipe_page_transition.dart';

import './Settings.dart';
import './SickTrack.dart';
import './Schools.dart';

class Dashboard extends StatelessWidget {
  double margin = 8;

  @override
  Widget build(BuildContext context) {
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
          Icons.school_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': 'Schulen',
        'subtitle': 'Schulbereiche und Zugangsdaten wechseln',
        'link': const Schools(),
      },
      {
        'icon': Icon(
          Icons.settings_rounded,
          color: Theme.of(context).focusColor,
        ),
        'title': AppLocalizations.of(context)!.settingsTitle,
        'subtitle': AppLocalizations.of(context)!.settingsSubtitle,
        'link': Settings(),
      },
    ];
    return Container(
      height: MediaQuery.of(context).size.height * 0.69,
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.1),
      alignment: Alignment.center,
      child: Scrollbar(
        thickness: 3,
        radius: Radius.circular(100),
        thumbVisibility: true,
        controller: ScrollController(),
        child: ListView(
          physics: BouncingScrollPhysics(),
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
