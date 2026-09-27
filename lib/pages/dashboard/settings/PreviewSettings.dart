import 'package:flutter/material.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';

import '../../../models/ListPage.dart';
import '../../../models/SettingsSwitchTile.dart';

/// Untermenü der Plan-Einstellungen: Hier lässt sich global festlegen, ob die
/// „Nächste Stunde“-Vorschau unter den Klassen bzw. unter den Personen
/// angezeigt wird. Für einzelne Klassen und Personen kann das über das Zahnrad
/// im jeweiligen Plan abweichend eingestellt werden.
class PreviewSettings extends StatefulWidget {
  const PreviewSettings({Key? key}) : super(key: key);

  @override
  State<PreviewSettings> createState() => _PreviewSettingsState();
}

class _PreviewSettingsState extends State<PreviewSettings> {
  bool _hidePreviewClasses = VPlanAPI.defaultPreviewClassesHidden;
  bool _hidePreviewPersons = VPlanAPI.defaultPreviewPersonsHidden;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final VPlanAPI vplanAPI = VPlanAPI();
    final bool hideClasses = await vplanAPI.hidePreviewForClassesGlobally();
    final bool hidePersons = await vplanAPI.hidePreviewForPersonsGlobally();
    if (!mounted) return;
    setState(() {
      _hidePreviewClasses = hideClasses;
      _hidePreviewPersons = hidePersons;
    });
  }

  Future<void> _toggleClasses(bool value) async {
    setState(() => _hidePreviewClasses = value);
    await VPlanAPI().setPreviewHiddenForClassesGlobally(value);
  }

  Future<void> _togglePersons(bool value) async {
    setState(() => _hidePreviewPersons = value);
    await VPlanAPI().setPreviewHiddenForPersonsGlobally(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: l10n.previewSettings,
          children: [
            SettingsSwitchTile(
              icon: Icons.grid_view_rounded,
              title: l10n.hidePreviewClasses,
              subtitle: l10n.hidePreviewClassesSubtitle,
              value: _hidePreviewClasses,
              onChanged: _toggleClasses,
            ),
            SettingsSwitchTile(
              icon: Icons.face_retouching_natural_rounded,
              title: l10n.hidePreviewPersons,
              subtitle: l10n.hidePreviewPersonsSubtitle,
              value: _hidePreviewPersons,
              onChanged: _togglePersons,
            ),
          ],
        ),
      ),
    );
  }
}
