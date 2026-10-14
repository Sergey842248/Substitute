import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/services/NativeShell.dart';

import '../../models/swipe_page_transition.dart';

import 'Schools.dart';
import 'settings/Language.dart';
import 'settings/VPlanLogin.dart';
import 'settings/DeveloperOptions.dart';
import 'settings/TeacherShorts.dart';
import 'settings/PlanSettings.dart';
import 'settings/AppearanceSettings.dart';
import 'settings/ConfigBackupSettings.dart';

/// Die Einstellungen.
///
/// ## Warum hier **keine** Kopfzeile ist
///
/// Diese Seite ist der rechte Reiter der Navigationsleiste – und ein Reiter
/// liegt bereits unter der Kopfzeile der App. `ListPage` brächte für sich noch
/// eine mit: 10 % der Bildschirmhöhe für eine Zeile mit dem Wort „Einstellungen“.
/// Zwei Kopfzeilen übereinander, deren untere genau dasselbe sagen würde wie das
/// Symbol, das man gerade gedrückt hat – und beide auf Kosten des Inhalts.
///
/// Siehe [SyncShareHub], das aus demselben Grund genauso gebaut ist. Wer einen
/// Titel braucht, hat die Kopfzeile der App direkt über sich, und welcher Reiter
/// aktiv ist, sagt das Symbol in der Leiste.
///
/// ## Die Reihenfolge
///
/// Sie ist auf beiden Plattformen **gleich** und wird hier nur einmal
/// festgeschrieben: iOS baut dieselbe Liste nativ in `MoreScreen.swift`, und
/// zwei Reihenfolgen an zwei Stellen liefen auseinander, sobald eine Zeile
/// verschoben wurde.
///
/// Von oben nach unten: Was man beim ersten Öffnen sucht, was den Alltag
/// betrifft, was man ab und zu braucht, und ganz unten die Dinge, die man nur
/// anfasst, wenn etwas nicht stimmt.
///
/// * **Aussehen** ganz oben: Es ist die einzige Einstellung, die man sucht,
///   wenn einem die App *auf Anhieb* nicht gefällt.
/// * **Zugangsdaten** und direkt darunter **Schulen**: Beide sagen, *wo* die
///   Daten herkommen. Wer den Bereich wechselt, fasst danach die Schulen an –
///   sie gehören deshalb nicht an zwei getrennte Stellen in der App.
class Settings extends StatefulWidget {
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  /// Die Liste braucht einen `ScrollController`, und es muss **derselbe** sein
  /// wie der am `ScrollView` – sonst hat der Rollenbalken keine Scrollposition
  /// und wird gar nicht gezeichnet.
  ///
  /// Er wird hier gehalten und im `dispose` freigegeben, statt ihn bei jedem
  /// Umbau neu zu erzeugen: Ein Controller, der bei jedem Aufbau entsteht,
  /// hängt nie an einer Position.
  final ScrollController _rollen = ScrollController();

  @override
  void dispose() {
    _rollen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // Als [List] und nicht als [Map]: Eine [Map] garantiert die Reihenfolge
    // nicht, und hier ist sie ausdrücklich gewollt (siehe [Settings]).
    final List<Map<String, dynamic>> eintraege = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': l10n.appearance,
        'subtitle': l10n.appearanceSubtitle,
        'icon': Icons.palette_rounded,
        'link': const AppearanceSettings(),
      },
      <String, dynamic>{
        'title': l10n.planSettings,
        'subtitle': l10n.planSettingsSubtitle,
        'icon': Icons.schedule_rounded,
        'link': PlanSettings(),
      },
      <String, dynamic>{
        'title': l10n.language,
        'subtitle': l10n.languageSubtitle,
        'icon': Icons.language_rounded,
        'link': Language(),
      },
      <String, dynamic>{
        'title': l10n.setTeacherAbbreviations,
        'subtitle': l10n.setTeacherAbbreviationsSubtitle,
        'icon': Icons.people_alt_outlined,
        'link': TeacherShorts(),
      },
      <String, dynamic>{
        'title': l10n.credentials,
        'subtitle': l10n.credentialsSubtitle,
        'icon': Icons.lock_outline_rounded,
        'link': VPlanLogin(),
      },
      <String, dynamic>{
        'title': l10n.schools,
        'subtitle': l10n.schoolsSubtitle,
        'icon': Icons.school_rounded,
        'link': const Schools(),
      },
      <String, dynamic>{
        'title': l10n.backup,
        'subtitle': l10n.backupSubtitle,
        'icon': Icons.settings_backup_restore_rounded,
        'link': const ConfigBackupSettings(),
      },
      <String, dynamic>{
        'title': l10n.developerOptions,
        'subtitle': l10n.developerOptionsSubtitle,
        'icon': Icons.developer_mode_rounded,
        'link': DeveloperOptions(),
      },
    ];

    return Container(
      // Keine eigene Hoehe: Der Abschluss der Liste bekommt den Platz fuer die
      // ueberlagerte iOS-Leiste. Er steht als letztes Listenelement und nicht
      // dauerhaft unter dem ganzen Bildschirm.
      child: Scrollbar(
        thickness: 3,
        radius: const Radius.circular(100),
        thumbVisibility: true,
        controller: _rollen,
        child: ListView(
          controller: _rollen,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          shrinkWrap: true,
          children: <Widget>[
            for (final Map<String, dynamic> eintrag in eintraege)
              Center(
                child: ListItem(
                  padding: 16,
                  leading: Icon(
                    eintrag['icon'] as IconData,
                    color: Theme.of(context).focusColor,
                  ),
                  title: Container(
                    margin: const EdgeInsets.only(top: 5, bottom: 5),
                    child: Text(
                      eintrag['title'] as String,
                      style: TextStyle(
                        color: Theme.of(context).focusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: Container(
                    margin: const EdgeInsets.only(top: 5, bottom: 5),
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
            const NativeShellScrollEndInset(),
          ],
        ),
      ),
    );
  }
}
