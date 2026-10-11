import 'dart:ui' show Locale;

import 'package:shared_preferences/shared_preferences.dart';

/// Die Sprache, in der die App spricht.
///
/// Drei Möglichkeiten: **die Systemsprache** (der Normalfall), **Deutsch**
/// oder **Englisch**. Als Kennung steht in den Einstellungen entweder ein
/// Sprachcode (`de`, `en`) oder [system].
///
/// Das Auslagern in eine eigene Klasse hat einen Grund: Die Auflösung muss
/// **vor** dem ersten Bild stehen, sonst zeichnet `MaterialApp` den allerersten
/// Frame in der Systemsprache und baut danach den ganzen Bildschirm ein zweites
/// Mal in der eingestellten um. Ein Bildschirm, der sich beim Start sichtbar
/// einmal neu aufbaut, ist genau das, was man vermeidet.
class AppLanguage {
  const AppLanguage._();

  /// Der Schlüssel in den Einstellungen für „der Systemsprache folgen".
  ///
  /// Bewusst **kein** Sprachcode: Wer `de` speichert und `de` liest, kann
  /// Deutsch nicht mehr von „der Systemsprache, die zufällig Deutsch ist"
  /// unterscheiden.
  static const String system = 'system';

  /// Das, was in den Einstellungen steht, wenn noch nichts gewählt wurde.
  ///
  /// Vorher stand hier fest `de`. Damit hätte ein frisch installiertes Gerät in
  /// Französisch Deutsch angezeigt, bis jemand das Menü findet und etwas
  /// ändert – obwohl die Sprache des Handys ohne jede Einstellung bekannt wäre.
  static const String defaultChoice = system;

  /// Der Schlüssel, unter dem die Wahl steht.
  static const String storageKey = 'languageCode';

  /// Merkt, dass [migrate] einmal gelaufen ist.
  ///
  /// Ohne dieses Merkmal wäre die Unterscheidung unten nicht möglich: „Der Wert
  /// fehlt" heißt bei einer bestehenden Installation **nicht**, dass noch nie
  /// eine Sprache eingestellt wurde – siehe [migrate].
  static const String migratedKey = 'languageCode.migrated';

  /// Die Sprachen, für die es eine Übersetzung gibt.
  static const List<String> supported = <String>['de', 'en'];

  /// Die Sprache, die vor der Systemsprache-Option die Vorgabe war.
  static const String previousDefault = 'de';

  /// Einmalig beim Start: Altbestände bekommen ihre bisherige Sprache
  /// festgeschrieben, neue Installationen die Systemsprache.
  ///
  /// ## Warum es hier überhaupt etwas zu tun gibt
  ///
  /// Die alte App hat **nie** etwas in [storageKey] geschrieben. Sie hat
  /// `prefs.getString('languageCode') ?? 'de'` gezeigt: Wer Deutsch eingestellt
  /// hatte, sah Deutsch – aber im Speicher stand nichts. Wer nichts angefasst
  /// hatte, sah ebenfalls Deutsch, ebenfalls ohne Eintrag.
  ///
  /// Damit sieht „kein Eintrag" bei beiden gleich aus. Und auf einen fehlenden
  /// Wert „also war das eine Neuinstallation" zu schließen, war genau der
  /// Fehler, der beim Update passiert ist: Alle mit [previousDefault]
  /// gelaufenen Geräte sprangen auf die Systemsprache um. Eine Kollegin, die
  /// sich **deutsch eingestellt** hatte, sah nach dem Update Englisch – weil
  /// ihre Einstellung nie existiert hatte, nur ihr Ergebnis.
  ///
  /// ## Die Unterscheidung
  ///
  /// [firstTimeStorageKey] ist `null`, solange die Einführung nicht begonnen
  /// wurde, und `false`, sobald sie durch ist. Ein Gerät, das schon fertig
  /// eingeführt ist, hat diese App also **vor** diesem Update benutzt – bei einer
  /// wirklich frischen Installation ist das nicht der Fall. Das ist kein
  /// schlüssiger Beweis, aber die einzige Spur, die ein Update hinterlässt,
  /// ohne dafür einen alten Versionsstand führen zu müssen.
  ///
  /// Der Eintrag wird dabei **geschrieben**. Danach ist der Unterschied nicht
  /// mehr nötig, und die App kommt auch dann zu einem Ergebnis, wenn jemand
  /// später `languageCode` löscht.
  ///
  /// ## Der eine Fall, der danebenliegt
  ///
  /// Wer die Einführung noch nicht durch hatte, gilt als neu und bekommt die
  /// Systemsprache. Früher hätte er Deutsch gesehen. Praktisch ist das eine
  /// App, die nie benutzt wurde, bei der also nichts eingestellt war, was
  /// erhalten bleiben könnte.
  static Future<void> migrate(SharedPreferences prefs) async {
    if (prefs.getBool(migratedKey) == true) return;

    // Wer selbst gewählt hat, wird nicht angetastet – auch nicht, wenn der
    // Eintrag aus einem Grund kürzlich von Hand entfernt wurde.
    final String stored = prefs.getString(storageKey) ?? '';
    if (stored.isEmpty || !supported.contains(stored)) {
      final bool bereitsEingefuehrt = prefs.getBool(firstTimeStorageKey) == false;
      prefs.setString(
        storageKey,
        bereitsEingefuehrt ? previousDefault : system,
      );
    }
    await prefs.setBool(migratedKey, true);
  }

  /// Der Schlüssel, an dem `introTiles` die Einführung abhakt.
  ///
  /// Hier ausgeschrieben statt importiert: Das hängt an
  /// `lib/introduction/introTiles.dart`, und eine Serviceschicht, die eine
  /// Bildschirmdatei einzieht, wäre die falsche Richtung der Abhängigkeit.
  static const String firstTimeStorageKey = 'firstTime';

  /// Der eingestellte Wert – nicht die Sprache, die daraus folgt.
  ///
  /// Der Rückfall ist bewusst [defaultChoice] und nicht `de`: Ein
  /// unerwarteter Wert im Speicher soll die App auf die Systemsprache
  /// zurückfallen lassen, statt sie auf eine Sprache zu setzen, die es
  /// vielleicht gar nicht gibt.
  static String read(SharedPreferences prefs) {
    final String stored = prefs.getString(storageKey) ?? defaultChoice;
    if (stored == system || supported.contains(stored)) return stored;
    return defaultChoice;
  }

  /// Welche Sprache aus einer Wahl wirklich angezeigt wird.
  ///
  /// Bei [system] zählt die Systemsprache des Geräts. Ist sie **weder**
  /// Deutsch **noch** Englisch, wird Deutsch genommen: Die App gibt es nur auf
  /// diesen beiden Sprachen, und Deutsch ist hier die verständlichere der
  /// beiden – eine französische Oberfläche durch Englisch zu ersetzen wäre es
  /// nicht.
  static Locale resolve(String choice, Locale? systemLocale) {
    if (choice != system) return Locale(choice, '');
    final String? code = systemLocale?.languageCode;
    if (code != null && supported.contains(code)) return Locale(code, '');
    return const Locale('de', '');
  }

  /// Wie [resolve], nur eben mit den Einstellungen zusammen.
  static Locale localeFor(SharedPreferences prefs, Locale? systemLocale) =>
      resolve(read(prefs), systemLocale);

  /// Was `MaterialApp` als `locale` bekommen soll.
  ///
  /// Bei „der Systemsprache folgen" ist das **null** – und nicht die
  /// aufgelöste Sprache. `null` heißt für `MaterialApp`: „nimm die
  /// Systemsprache". Damit folgt die App der Systemsprache auch dann noch, wenn
  /// der Nutzer sie später am Gerät umstellt, ohne die App neu zu starten. Ein
  /// festes `Locale` würde beim nächsten Start eine veraltete Sprache zeigen –
  /// man müsste die App also zum Wechseln schließen und öffnen.
  static Locale? forMaterialApp(SharedPreferences prefs) {
    final String choice = read(prefs);
    return choice == system ? null : Locale(choice, '');
  }
}