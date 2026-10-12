import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'NativeShell.dart';

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
  ///
  /// Meldet die Änderung auch an die **native** Seite, falls es eine gibt: Auf
  /// iOS wird das Aussehen an zwei Orten eingestellt – in den nativen
  /// Einstellungen und in den Flutter-Bildschirmen. Damit beide dasselbe zeigen,
  /// muss der andere jeweils erfahren, dass etwas geschrieben wurde.
  static Future<void> setTheme(
    SharedPreferences prefs,
    String wert,
  ) async {
    await prefs.setString(_themeKey, wert);
    aenderung.value++;
    NativeShell.notifySettingsChanged();
  }

  /// Schaltet den Sync-Eintrag ein oder aus.
  static Future<void> setShowSyncShareTab(
    SharedPreferences prefs,
    bool wert,
  ) async {
    await prefs.setBool(_showSyncKey, wert);
    aenderung.value++;
    NativeShell.notifySettingsChanged();
  }

  /// Liest das Theme **neu** ein, weil die native Seite es geändert hat.
  ///
  /// Nötig aus demselben Grund, warum es [notifySettingsChanged] gibt, nur in
  /// der Gegenrichtung: [SharedPreferences] hält fest, was **es** zuletzt
  /// gelesen oder geschrieben hat. Ein Wert, den die native Seite inzwischen
  /// geschrieben hat, steht hier noch nicht – ohne dieses erneute Lesen würde
  /// die App ihren eigenen Sprung nicht mitmachen.
  ///
  /// Deshalb wird hier ausdrücklich nicht der neue Wert übergeben: Dart holt
  /// ihn sich selbst, und damit kann es nicht zwei Stellen geben, die
  /// unterschiedliche Werte für dieselbe Sache behaupten.
  static Future<ThemeMode> reloadTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ThemeMode mode = modeOf(themeOf(prefs));
    aenderung.value++;
    return mode;
  }
}
