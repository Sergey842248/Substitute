import 'package:shared_preferences/shared_preferences.dart';

import 'SchoolStorage.dart';

/// Zugriff auf die Standard-Planmodi.
///
/// Es gibt vier getrennte Werte: den Planmodus für Personen, für Klassen, für
/// die „Nächste Stunde“-Vorschau der Klassen und für die der Personen. Vorher
/// gab es nur einen gemeinsamen Wert für beide Vorschauen – der wird hier als
/// Rückfall übernommen, damit bestehende Einstellungen erhalten bleiben.
class PlanModePreferences {
  const PlanModePreferences._();

  static const String auto = 'auto';
  static const String latest = 'latest';
  static const String today = 'today';

  static const List<String> modes = <String>[auto, latest, today];

  static const String _keyClass = 'defaultPlanModeClass';
  static const String _keyPerson = 'defaultPlanModePerson';
  static const String _keyPreviewClass = 'defaultPlanModePreviewClass';
  static const String _keyPreviewPerson = 'defaultPlanModePreviewPerson';

  /// Alter, gemeinsamer Schlüssel für beide Vorschauen. Wird nur noch gelesen,
  /// solange für die jeweilige Vorschau nichts Spezifischeres gespeichert ist.
  static const String _legacyKeyPreview = 'defaultPlanModePreview';

  /// Prüft, ob [mode] ein gültiger Planmodus ist, und fällt sonst auf [auto]
  /// zurück. Unbekannte Werte können durch ein Downgrade oder eine
  /// beschädigte Speicherung entstehen.
  static String sanitize(String? mode) =>
      modes.contains(mode) ? mode! : auto;

  /// Liest den unter [key] gespeicherten Modus. Ist dort nichts gespeichert,
  /// wird – bei den beiden Vorschau-Schlüsseln – der alte gemeinsame Wert
  /// verwendet, zuletzt [auto].
  static Future<String> read(SharedPreferences prefs, String key) async {
    final String? stored = prefs.getString(SchoolStorage.scopedKey(prefs, key));
    if (stored != null) return sanitize(stored);
    final bool isPreview =
        key == _keyPreviewClass || key == _keyPreviewPerson;
    if (isPreview) {
      return sanitize(
        prefs.getString(SchoolStorage.scopedKey(prefs, _legacyKeyPreview)),
      );
    }
    return auto;
  }

  /// Speichert [mode] unter [key].
  static Future<void> write(
    SharedPreferences prefs,
    String key,
    String mode,
  ) =>
      prefs.setString(SchoolStorage.scopedKey(prefs, key), sanitize(mode));

  static Future<String> readClass(SharedPreferences prefs) =>
      read(prefs, _keyClass);

  static Future<String> readPerson(SharedPreferences prefs) =>
      read(prefs, _keyPerson);

  /// Planmodus der Klassen-Vorschau.
  static Future<String> readPreviewClass(SharedPreferences prefs) =>
      read(prefs, _keyPreviewClass);

  /// Planmodus der Personen-Vorschau.
  static Future<String> readPreviewPerson(SharedPreferences prefs) =>
      read(prefs, _keyPreviewPerson);

  static Future<void> writeClass(SharedPreferences prefs, String mode) =>
      write(prefs, _keyClass, mode);

  static Future<void> writePerson(SharedPreferences prefs, String mode) =>
      write(prefs, _keyPerson, mode);

  static Future<void> writePreviewClass(SharedPreferences prefs, String mode) =>
      write(prefs, _keyPreviewClass, mode);

  static Future<void> writePreviewPerson(SharedPreferences prefs, String mode) =>
      write(prefs, _keyPreviewPerson, mode);
}
