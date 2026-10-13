import 'package:flutter/material.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';

import '../../../models/swipe_page_transition.dart';

import '../../../models/ListPage.dart';
import './LessonInfoSettings.dart';
import './PreviewSettings.dart';
import './Lessons.dart';
import './PlanModeSettings.dart';

/// Die Plan-Einstellungen.
///
/// Diese Seite ist bewusst nur eine **Übersicht**: Sie verweist auf
/// Untermenüs und zeigt keine Schalter mehr selbst. Vorher standen hier
/// Schalter für einzelne Anzeigedetails direkt neben den Einträgen zu den
/// Untermenüs – wer gezielt etwas ändern wollte, musste an der Liste vorbei an
/// genau einer Zeile drehen, die einen anderen Aufbau hatte als die übrigen.
class PlanSettings extends StatefulWidget {
  PlanSettings({Key? key}) : super(key: key);

  @override
  State<PlanSettings> createState() => _PlanSettingsState();
}

class _PlanSettingsState extends State<PlanSettings> {
  /// Eintrag, der eine weitere Einstellungsseite öffnet.
  Widget _entryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: ListTile(
            leading: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(icon),
            ),
            title: Text(title, style: const TextStyle(fontSize: 18)),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w100,
                color: Colors.grey,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: page,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListPage(
          title: l10n.planSettings,
          children: [
            _entryTile(
              icon: Icons.info_outline_rounded,
              title: l10n.lessonInfoSettings,
              subtitle: l10n.lessonInfoSettingsSubtitle,
              page: const LessonInfoSettings(),
            ),
            _entryTile(
              icon: Icons.visibility_rounded,
              title: l10n.previewSettings,
              subtitle: l10n.previewSettingsSubtitle,
              page: const PreviewSettings(),
            ),
            _entryTile(
              icon: Icons.view_agenda_rounded,
              title: l10n.defaultPlanModePreviewEntryTitle,
              subtitle: l10n.defaultPlanModePreviewEntrySubtitle,
              page: const PlanModeSettings(),
            ),
            _entryTile(
              icon: Icons.schedule_rounded,
              title: l10n.lessonTimes,
              subtitle: l10n.lessonTimesSubtitle,
              page: Lessons(),
            ),
          ],
        ),
      ),
    );
  }
}
