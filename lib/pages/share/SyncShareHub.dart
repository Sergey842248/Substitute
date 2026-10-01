import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListPage.dart';

import '../../models/swipe_page_transition.dart';
import 'package:substitute/pages/dashboard/settings/SyncSettings.dart';
import 'package:substitute/pages/share/ShareBrowsePage.dart';
import 'package:substitute/pages/share/ShareListPage.dart';

/// Die Sammelseite für alles, was Daten zwischen Geräten und Menschen bewegt.
///
/// Sie gibt dem Ganzen einen eigenen Platz in der Navigationsleiste. Vorher
/// lagen Sync, Share und „Shares finden" als drei Einträge unter den
/// Einstellungen – tief in einer Liste, die man aufsuchen musste, obwohl es
/// um eine der wenigen Funktionen geht, für die man die App überhaupt braucht.
///
/// ## Warum eine Seite statt drei Kacheln in der Leiste
///
/// Die Leiste hat Platz für Symbole, nicht für Erklärungen. „Share" und „Sync"
/// sehen als Symbol fast gleich aus, und wer nicht weiß, welches welches ist,
/// tippt im schlimmsten Fall das falsche und findet dort nichts. Die Seite
/// trägt die Überschriften mit, und die Leiste trägt nur die Richtung.
class SyncShareHub extends StatefulWidget {
  const SyncShareHub({Key? key, this.showBackButton = false}) : super(key: key);

  /// Ob in der Kopfzeile ein Zurück-Pfeil erscheint.
  ///
  /// Von der Navigationsleiste aus ist das unnötig – dort gibt es keinen
  /// Bildschirm, zu dem man zurückkehren könnte. Von einem anderen Bildschirm
  /// aus schon.
  final bool showBackButton;

  @override
  State<SyncShareHub> createState() => _SyncShareHubState();
}

class _SyncShareHubState extends State<SyncShareHub> {
  /// Die drei Zugänge. Als Liste statt als [Map], weil eine [Map] die
  /// Reihenfolge nicht garantiert – und hier ist die Reihenfolge Absicht:
  /// erst die eigenen Geräte, dann das Teilen mit anderen, dann deren Angebote
  /// durchsuchen. Das ist ein Weg von „mir" über „uns" zu „den anderen".
  List<Map<String, dynamic>> get _eintraege {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'title': l10n.sync,
        'subtitle': l10n.syncSubtitle,
        'icon': Icons.sync_rounded,
        'link': const SyncSettings(),
      },
      <String, dynamic>{
        'title': l10n.share,
        'subtitle': l10n.shareSubtitle,
        'icon': Icons.people_alt_rounded,
        'link': const ShareListPage(),
      },
      <String, dynamic>{
        'title': l10n.shareBrowse,
        'subtitle': l10n.shareBrowseSubtitle,
        'icon': Icons.travel_explore_rounded,
        'link': const ShareBrowsePage(),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ListPage(
      title: l10n.syncShareHub,
      showBackButton: widget.showBackButton,
      children: <Widget>[
        for (final Map<String, dynamic> eintrag in _eintraege)
          // Material statt einer farbigen Box: Sonst malt das ListTile seinen
          // Hintergrund und die Berührung wird unsichtbar.
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Container(
              margin: const EdgeInsets.all(10),
              child: Center(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    SwipePageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: eintrag['link'] as Widget,
                    ),
                  ),
                  leading: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Icon(eintrag['icon'] as IconData),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      eintrag['title'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    eintrag['subtitle'] as String,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
