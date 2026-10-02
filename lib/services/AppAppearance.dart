import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wie die App aussieht – und was in der Navigationsleiste steht.
///
/// ## Warum ein Dienst und nicht zwei Aufrufe von `SharedPreferences`
///
/// Die beiden Einstellungen wirken an **zwei** Stellen, die nicht
/// voneinander wissen: Das Theme wird von `_MyAppState` gebaut, die
/// Navigationsleiste von `_HomePageState` – zwei verschiedene Bildschirme
/// derselben App. Ohne gemeinsame Quelle holt sich jeder die Werte beim
/// Aufbau, und beim Zurückkehren von der Einstellungsseite wüsste niemand,
/// dass sich etwas geändert hat: Man käme auf den alten Bildschirm zurück und
/// nichts hätte sich bewegt.
///
/// Die [ValueNotifier] lösen das: Wer umschaltet, erhöht den Zähler, und beide
/// Bildschirme bauen sich neu. Einstellungen, die irgendwo im Bildschirm
/// sichtbar sind, brauchen diese Form – siehe `vplanBackgroundRefresh` in
/// `VPlanAPI` für dasselbe Problem.
///
/// ## Standardwerte
///
/// **Dunkel**, und das ist Absicht: So sah die App aus, bevor es diese
/// Einstellung gab. Wer sie zum ersten Mal öffnet, bekommt das gewohnte
/// Bild, nicht ein anderes.
///
/// Und die Navigationsleiste zeigt den Sync-Eintrag, weil die drei Funktionen
/// zu den wenigen gehören, für die man die App braucht. Wer sie nicht braucht,
/// schaltet sie ab – dann ist die Leiste wieder die von früher, mit drei
/// Einträgen.
class AppAppearance {
  const AppAppearance._();

  static const String _themeKey = 'appearance.theme';
  static const String _showSyncKey = 'appearance.showSyncShareTab';

  /// `dark`, `light` oder `system`.
  static const String dark = 'dark';
  static const String light = 'light';

  /// Wird erhöht, wenn sich etwas geändert hat.
  static final ValueNotifier<int> aenderung = ValueNotifier<int>(0);

  /// Das gewählte Theme.
  static ThemeMode modeOf(String wert) {
    switch (wert) {
      case light:
        return ThemeMode.light;
      case dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// `dark` oder `light` – ohne `system`, denn die Auswahl bietet nur zwei an.
  static String themeOf(SharedPreferences prefs) =>
      prefs.getString(_themeKey) ?? dark;

  /// true, wenn der Sync-Eintrag in der Navigationsleiste stehen soll.
  static bool showSyncShareTab(SharedPreferences prefs) =>
      prefs.getBool(_showSyncKey) ?? true;

  /// Setzt das Theme und benachrichtigt beide Bildschirme.
  static Future<void> setTheme(
    SharedPreferences prefs,
    String wert,
  ) async {
    await prefs.setString(_themeKey, wert);
    aenderung.value++;
  }

  /// Schaltet den Sync-Eintrag ein oder aus.
  static Future<void> setShowSyncShareTab(
    SharedPreferences prefs,
    bool wert,
  ) async {
    await prefs.setBool(_showSyncKey, wert);
    aenderung.value++;
  }
}
