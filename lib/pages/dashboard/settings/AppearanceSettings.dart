import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/AppAppearance.dart';

import '../../../models/ListPage.dart';
import '../../../models/SettingsSwitchTile.dart';

/// Wie die App aussieht – und was in der Navigationsleiste steht.
///
/// Zwei Dinge, die beide das **Aussehen** betreffen und deshalb hierher
/// gehören statt in zwei getrennte Seiten:
///
/// * **Dunkel oder hell.** Dunkel ist der Standard, weil die App vorher
///   ausschließlich so aussah. Wer zum ersten Mal hier öffnet, bekommt das
///   gewohnte Bild.
/// * **Der Sync-Eintrag in der Leiste.** Die Leiste ist knapp, und nicht jeder
///   braucht die drei Funktionen. Ausgeschaltet verschwindet der Eintrag; die
///   Funktionen selbst bleiben erreichbar, sonst wären sie weg.
///
/// ## Warum die Änderungen sofort sichtbar sind
///
/// Beide wirken an Bildschirmen, die gerade **nicht** im Vordergrund sind: Das
/// Theme wird von der App-Wurzel gebaut, die Leiste vom Startbildschirm. Ohne
/// gemeinsame Quelle (`AppAppearance`) wüsste beim Zurückkehren niemand, dass
/// sich etwas geändert hat, und man käme auf den alten Bildschirm zurück,
/// ohne dass sich etwas bewegt hätte.
class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({Key? key}) : super(key: key);

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  /// `dark` oder `light`.
  String _theme = AppAppearance.dark;

  bool _showSyncTab = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _theme = AppAppearance.themeOf(prefs);
      _showSyncTab = AppAppearance.showSyncShareTab(prefs);
    });
  }

  Future<void> _setTheme(String wert) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _theme = wert);
    await AppAppearance.setTheme(prefs, wert);
  }

  Future<void> _setShowSyncTab(bool wert) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _showSyncTab = wert);
    await AppAppearance.setShowSyncShareTab(prefs, wert);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool dunkel = _theme == AppAppearance.dark;
    return Scaffold(
      body: ListPage(
        title: l10n.appearance,
        children: <Widget>[
          // Dunkel/Hell als zwei Kacheln statt als Schalter: Es sind zwei
          // gleichwertige Möglichkeiten, und ein Schalter müsste durch seinen
          // Zustand sagen, was passiert, wenn man ihn umstellt. Zwei Kacheln
          // zeigen beide Möglichkeiten, und die aktive ist markiert.
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            margin: const EdgeInsets.all(10),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.palette_rounded),
                  ),
                  title: Text(
                    l10n.appearanceTheme,
                    style: const TextStyle(fontSize: 18),
                  ),
                  subtitle: Text(
                    l10n.appearanceThemeSubtitle,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _auswahl(
                          context,
                          text: l10n.appearanceThemeDark,
                          icon: Icons.dark_mode_rounded,
                          gewaehlt: dunkel,
                          onTap: () => _setTheme(AppAppearance.dark),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _auswahl(
                          context,
                          text: l10n.appearanceThemeLight,
                          icon: Icons.light_mode_rounded,
                          gewaehlt: !dunkel,
                          onTap: () => _setTheme(AppAppearance.light),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SettingsSwitchTile(
            icon: Icons.sync_rounded,
            title: l10n.appearanceShowSyncTab,
            subtitle: l10n.appearanceShowSyncTabSubtitle,
            value: _showSyncTab,
            onChanged: _setShowSyncTab,
          ),
        ],
      ),
    );
  }

  /// Eine der beiden Möglichkeiten, mit Markierung der aktiven.
  Widget _auswahl(
    BuildContext context, {
    required String text,
    required IconData icon,
    required bool gewaehlt,
    required VoidCallback onTap,
  }) {
    return Material(
      // Die ausgewählte Kachel bekommt die Grundfarbe des Themes. Sonst wäre
      // „dunkel gewählt" an einem dunklen Bildschirm gar nicht zu sehen – und
      // gerade da, wo es am wichtigsten ist, sähe man den Unterschied nicht.
      color: gewaehlt ? Theme.of(context).primaryColor : null,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: gewaehlt ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).focusColor,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: gewaehlt ? FontWeight.bold : FontWeight.normal,
                  color: gewaehlt ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).focusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
