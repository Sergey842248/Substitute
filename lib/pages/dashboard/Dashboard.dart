
import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';

import '../../models/ListItem.dart';
import 'package:substitute/models/ListPage.dart';

import 'package:animations/animations.dart';

import './Settings.dart';
import './SickTrack.dart';

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
