import 'package:shared_preferences/shared_preferences.dart';

import 'AppAppearance.dart';

/// Ob Sync und Teilen überhaupt laufen dürfen.
///
/// ## Eine Einstellung, keine zwei
///
/// Die drei Funktionen des Sync-Menüs – Sync, Teilen, Shares finden – hängen an
/// **einem** Schalter: dem Eintrag in der Navigationsleiste. Wer ihn
/// ausblendet, hat damit auch entschieden, dass diese Funktionen nicht laufen
/// sollen; wer ihn wieder einblendet, hat sie wieder gewollt.
///
/// Früher stand hier ein **zweiter** Schalter („alles abschalten"), der nur
/// sichtbar war, wenn der Eintrag schon ausgeblendet war. Das war eine
/// unnötige zweite Stufe: Wer den Eintrag nicht sieht, kann die Funktionen ohne
///hin nicht bedienen, und wer sie doch benutzen will, blendet ihn wieder ein.
/// Zwei Schalter für eine Frage heißen am Ende, dass einer von beiden vergessen
/// wird – und dann läuft etwas weiter, das niemand mehr sehen kann.
///
/// ## Der Schalter ist ein **Verbot**, kein Löschen
///
/// Ausgeschaltet wird **nichts**: Der gespeicherte Sync-Zustand bleibt liegen,
/// die eigenen Shares bleiben in der Liste, und der Server behält, was dort
/// steht. Ein ausgeschalteter Sync ist nur **still** – es findet kein Lauf statt
/// und es wird nichts veröffentlicht. Wer den Eintrag wieder einblendet, ist
/// genau dort, wo er vorher war, ohne einen Sync neu einrichten oder einen Share
/// neu anlegen zu müssen.
///
/// Das Gegenteil wäre ein Datenverlust durch eine Einstellung: „Eintrag
/// ausblenden" heißt nicht „Inhalte löschen".
///
/// ## Warum das Suchmenü auch schließt
///
/// Auch das **Finden** fremder Shares gehört dazu. Eine Suche holt zwar keine
/// fremden Daten herbei, sie zeigt aber, wer hier gerade etwas anbietet – und
/// „der Eintrag ist ausgeblendet" hieße sonst nur „ich sehe nichts davon".
class SyncShareEnabled {
  const SyncShareEnabled._();

  /// true, wenn Sync und Teilen laufen dürfen.
  ///
  /// Gelesen wird derselbe Wert, den auch die Navigationsleiste liest – nicht
  /// ein eigener. Zwei Werte für dieselbe Frage könnten auseinanderlaufen, und
  /// die Leiste würde dann etwas anderes zeigen, als tatsächlich läuft.
  static bool isEnabled(SharedPreferences prefs) =>
      AppAppearance.showSyncShareTab(prefs);

  /// true, wenn Sync und Teilen abgeschaltet sind.
  static bool isDisabled(SharedPreferences prefs) => !isEnabled(prefs);
}
