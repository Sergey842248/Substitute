import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/PlanModePreferences.dart';

import '../../../models/ListPage.dart';

/// Standard-Planmodi: getrennt für Personen, Klassen, die Vorschau der Klassen
/// und die Vorschau der Personen.
class PlanModeSettings extends StatefulWidget {
  const PlanModeSettings({Key? key}) : super(key: key);

  @override
  State<PlanModeSettings> createState() => _PlanModeSettingsState();
}

/// Schreibt einen Modus über [PlanModePreferences] in die Einstellungen.
typedef _ModeWriter = Future<void> Function(
  SharedPreferences prefs,
  String mode,
);

class _PlanModeSettingsState extends State<PlanModeSettings> {
  String _class = PlanModePreferences.auto;
  String _person = PlanModePreferences.auto;
  String _previewClass = PlanModePreferences.auto;
  String _previewPerson = PlanModePreferences.auto;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String classMode = await PlanModePreferences.readClass(prefs);
    final String personMode = await PlanModePreferences.readPerson(prefs);
    final String previewClassMode =
        await PlanModePreferences.readPreviewClass(prefs);
    final String previewPersonMode =
        await PlanModePreferences.readPreviewPerson(prefs);
    if (!mounted) return;
    setState(() {
      _class = classMode;
      _person = personMode;
      _previewClass = previewClassMode;
      _previewPerson = previewPersonMode;
    });
  }

  Future<void> _setMode(
    _ModeWriter write,
    void Function(String mode) apply,
    String mode,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await write(prefs, mode);
    if (mounted) setState(() => apply(mode));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Die drei Auswahlmöglichkeiten heißen in jeder Gruppe gleich, deshalb
    // werden die Beschriftungen einmal aus der Übersetzung geholt.
    final labels = _ModeLabels(
      auto: l10n.defaultPlanModePreviewAuto,
      latest: l10n.defaultPlanModePreviewLatest,
      today: l10n.defaultPlanModePreviewToday,
    );
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.planSettings,
          children: [
            _ModeGroup(
              icon: Icons.person_outline_rounded,
              title: l10n.defaultPlanModePerson,
              labels: labels,
              subtitles: _ModeSubtitles(
                auto: l10n.defaultPlanModePersonAutoSubtitle,
                latest: l10n.defaultPlanModePersonLatestSubtitle,
                today: l10n.defaultPlanModePersonTodaySubtitle,
              ),
              value: _person,
              onChanged: (mode) => _setMode(
                PlanModePreferences.writePerson,
                (m) => _person = m,
                mode,
              ),
            ),
            _ModeGroup(
              icon: Icons.view_agenda_rounded,
              title: l10n.defaultPlanModeClass,
              labels: labels,
              subtitles: _ModeSubtitles(
                auto: l10n.defaultPlanModeClassAutoSubtitle,
                latest: l10n.defaultPlanModeClassLatestSubtitle,
                today: l10n.defaultPlanModeClassTodaySubtitle,
              ),
              value: _class,
              onChanged: (mode) => _setMode(
                PlanModePreferences.writeClass,
                (m) => _class = m,
                mode,
              ),
            ),
            _ModeGroup(
              icon: Icons.grid_view_rounded,
              title: l10n.defaultPlanModePreviewClass,
              labels: labels,
              subtitles: _ModeSubtitles(
                auto: l10n.defaultPlanModePreviewClassAutoSubtitle,
                latest: l10n.defaultPlanModePreviewClassLatestSubtitle,
                today: l10n.defaultPlanModePreviewClassTodaySubtitle,
              ),
              value: _previewClass,
              onChanged: (mode) => _setMode(
                PlanModePreferences.writePreviewClass,
                (m) => _previewClass = m,
                mode,
              ),
            ),
            _ModeGroup(
              icon: Icons.face_retouching_natural_rounded,
              title: l10n.defaultPlanModePreviewPerson,
              labels: labels,
              subtitles: _ModeSubtitles(
                auto: l10n.defaultPlanModePreviewPersonAutoSubtitle,
                latest: l10n.defaultPlanModePreviewPersonLatestSubtitle,
                today: l10n.defaultPlanModePreviewPersonTodaySubtitle,
              ),
              value: _previewPerson,
              onChanged: (mode) => _setMode(
                PlanModePreferences.writePreviewPerson,
                (m) => _previewPerson = m,
                mode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die drei festen Auswahlmöglichkeiten. In allen Gruppen gleich benannt.
class _ModeLabels {
  const _ModeLabels({
    required this.auto,
    required this.latest,
    required this.today,
  });

  final String auto;
  final String latest;
  final String today;
}

/// Die Erklärtexte unter den Auswahlmöglichkeiten.
class _ModeSubtitles {
  const _ModeSubtitles({
    required this.auto,
    required this.latest,
    required this.today,
  });

  final String auto;
  final String latest;
  final String today;
}

/// Eine Auswahlgruppe: Überschrift mit Icon plus drei Radiobuttons.
class _ModeGroup extends StatelessWidget {
  const _ModeGroup({
    required this.icon,
    required this.title,
    required this.labels,
    required this.subtitles,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final _ModeLabels labels;
  final _ModeSubtitles subtitles;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(icon),
                ),
                title: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    subtitles.auto,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w100,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              RadioListTile<String>(
                title: Text(labels.auto),
                subtitle: Text(subtitles.auto),
                value: PlanModePreferences.auto,
                groupValue: value,
                onChanged: (val) => onChanged(val!),
              ),
              RadioListTile<String>(
                title: Text(labels.latest),
                subtitle: Text(subtitles.latest),
                value: PlanModePreferences.latest,
                groupValue: value,
                onChanged: (val) => onChanged(val!),
              ),
              RadioListTile<String>(
                title: Text(labels.today),
                subtitle: Text(subtitles.today),
                value: PlanModePreferences.today,
                groupValue: value,
                onChanged: (val) => onChanged(val!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
