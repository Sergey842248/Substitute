import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/pages/dashboard/settings/SyncSettings.dart';
import 'package:substitute/pages/share/ShareBrowsePage.dart';
import 'package:substitute/pages/share/ShareListPage.dart';

import '../../models/swipe_page_transition.dart';

/// Die Sammelseite für alles, was Daten zwischen Geräten und Menschen bewegt.
///
/// Sie ist ein **Tab** in der Navigationsleiste – der vierte, nach dem
/// Dashboard. Vorher lagen die drei Funktionen als Einträge unter den
/// Einstellungen: tief in einer Liste, die man aufsuchen musste, obwohl es um
/// eine der wenigen Funktionen geht, für die man die App überhaupt braucht.
///
/// ## Warum hier **keine** Kopfzeile ist
///
/// Der gemeldete Fehler: Als dieser Bildschirm seine eigene Kopfzeile mitbrachte,
/// standen **zwei** übereinander. Ein Tab liegt bereits unter der Kopfzeile der
/// App, und `ListPage` bringt für sich noch eine mit – 10 % der Bildschirmhöhe
/// für eine Zeile, direkt unter einer 20 % hohen Leiste. Dazu kam der Text
/// „Sync & Share" direkt am oberen Rand, wo er hingehört – und der
/// ausklappende Bereich darüber, der mit dem nichts anfangen konnte.
///
/// Der `Dashboard`-Tab löst das einfach richtig: Er ist eine nackte Liste mit
/// fester Höhe, ganz ohne `ListPage`. Diese Seite tut es genauso. Wer einen
/// Titel braucht, hat die Kopfzeile der App direkt über sich – und welcher Tab
/// aktiv ist, sagt das Symbol in der Leiste.
class SyncShareHub extends StatefulWidget {
  const SyncShareHub({Key? key}) : super(key: key);

  @override
  State<SyncShareHub> createState() => _SyncShareHubState();
}

class _SyncShareHubState extends State<SyncShareHub> {
  /// Der Rollenbalken braucht einen `ScrollController`, und es muss **derselbe**
  /// sein wie der am `ScrollView`. Sonst hat er keine Scrollposition und kann
  /// nicht gezeichnet werden – mit `thumbVisibility: true` sagt das Framework
  /// sogar ausdrücklich.
  ///
  /// Er wird hier gehalten und im `dispose` freigegeben, statt ihn im `build`
  /// zu erzeugen: Ein Controller, der bei jedem Umbau entsteht, hängt nie an
  /// einer Position und verliert den Zusammenhang zum Balken.
  final ScrollController _rollen = ScrollController();

  /// Die drei Zugänge. Als Liste statt als [Map], weil eine [Map] die
  /// Reihenfolge nicht garantiert – und hier ist die Reihenfolge Absicht:
  /// erst die eigenen Geräte, dann das Teilen mit anderen, dann deren Angebote
  /// durchsuchen. Ein Weg von „mir" über „uns" zu „den anderen".
  /// [context] wird gebraucht, weil die Symbole in der Farbe der
  /// Kopfzeile gefaert sein sollen – die kennt nur der Kontext.
  static List<Map<String, dynamic>> eintraege(
    AppLocalizations l10n,
    BuildContext context,
  ) =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'title': l10n.sync,
          'subtitle': l10n.syncSubtitle,
          'icon': Icon(Icons.sync_rounded, color: Theme.of(context).focusColor),
          'link': const SyncSettings(),
        },
        <String, dynamic>{
          'title': l10n.share,
          'subtitle': l10n.shareSubtitle,
          'icon': Icon(Icons.people_alt_rounded,
              color: Theme.of(context).focusColor),
          'link': const ShareListPage(),
        },
        <String, dynamic>{
          'title': l10n.shareBrowse,
          'subtitle': l10n.shareBrowseSubtitle,
          'icon': Icon(Icons.travel_explore_rounded,
              color: Theme.of(context).focusColor),
          'link': const ShareBrowsePage(),
        },
      ];

  @override
  void dispose() {
    _rollen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      // Feste Höhe und unterer Rand: Der Tab sitzt zwischen der Kopfzeile der
      // App und der Leiste, und die Leiste braucht ihren Platz. Ohne diese
      // Höhe liefe die Liste unter der Navigationsleiste hindurch, und die
      // untersten Einträge wären nicht erreichbar.
      height: MediaQuery.of(context).size.height * 0.69,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.1,
      ),
      alignment: Alignment.center,
      child: Scrollbar(
        thickness: 3,
        radius: const Radius.circular(100),
        thumbVisibility: true,
        controller: _rollen,
        child: ListView(
          controller: _rollen,
          physics: const BouncingScrollPhysics(),
          shrinkWrap: true,
          children: <Widget>[
            for (final Map<String, dynamic> eintrag in eintraege(l10n, context))
              Center(
                child: ListItem(
                  padding: 20,
                  leading: eintrag['icon'] as Widget,
                  title: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      eintrag['title'] as String,
                      style: TextStyle(
                        color: Theme.of(context).focusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(eintrag['subtitle'] as String),
                  ),
                  onClick: () => Navigator.push(
                    context,
                    SwipePageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: eintrag['link'] as Widget,
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
                        child: eintrag['link'] as Widget,
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
