/// Welcher Plan in einer Ansicht geöffnet werden soll.
///
/// ## Wozu das hier ist
///
/// Auf iOS ist die Plan-**Übersicht** ein nativer Bildschirm
/// (`PlanOverviewScreen`). Tippt man dort auf eine Klasse, ist der Plan dieser
/// Klasse weiterhin ein Flutter-Bildschirm – dort steht das Wochenraster, für
/// das es keinen vernünftigen Ersatz in einer Tabelle gibt.
///
/// Die native Seite öffnet dafür eine eigene Ansicht und sagt ihr in den
/// **Startargumenten**, worum es geht:
///
/// ```
/// --substitute-role=tool --plan-class-id=8a --plan-person-id=1699…
/// ```
///
/// ## Warum Startargumente und nicht die Route
///
/// Die Route entscheidet nur, **welcher** Bildscreen geöffnet wird
/// (`/plan/tag` oder `/plan/woche`). **Welche** Klasse, kann sie nicht
/// sinnvoll tragen: `/plan/8a` wäre eine Route pro Klasse, und die müsste
/// jemand pflegen, der sie nur zum Aufbau braucht – mit dem Risiko, dass
/// eine Klasse einen Schrägstrich im Namen hat und die Route dann
/// auseinanderfällt.
///
/// ## Warum nur die Kennung und nicht die ganze Person
///
/// Eine Person ist ein Datensatz mit Namen, Klasse und Kursliste. Ihn als
/// JSON mitzuschicken hieße, ihn zu **kopieren** – und die Kopie wäre
/// veraltet, sobald jemand in Flutter den Namen ändert. Die Kennung nicht:
/// Sie bleibt, auch wenn sich alles andere ändert.
class PlanTarget {
  const PlanTarget._();

  static const String _classPrefix = '--plan-class-id=';
  static const String _personPrefix = '--plan-person-id=';

  /// Die Kennung der Klasse dieser Ansicht, oder `''`.
  static String classId = '';

  /// Die Kennung der Person dieser Ansicht, oder `null`.
  ///
  /// `null` heißt: Es geht um die **ganze Klasse**, nicht um eine einzelne
  /// Person in ihr. Der Unterschied ist nicht kosmetisch – der Plan einer
  /// Person blendet die Kurse aus, die sie nicht hat.
  static String? personId;

  /// Liest das Ziel aus den Startargumenten.
  ///
  /// Auf Android, im Web und in den Tests ist `args` leer – dort bleibt alles
  /// leer, und die App verhält sich exakt wie vorher.
  static void read(List<String> args) {
    classId = '';
    personId = null;
    for (final String arg in args) {
      if (arg.startsWith(_classPrefix)) {
        classId = arg.substring(_classPrefix.length);
      } else if (arg.startsWith(_personPrefix)) {
        final String wert = arg.substring(_personPrefix.length);
        // Nur setzen, wenn wirklich etwas dahintersteht: `--plan-person-id=`
        // ohne Wert soll „ganze Klasse" bedeuten und nicht „Person ohne
        // Namen", denn Letzteres gäbe einen Plan, der alles zeigt und sich
        // auf keine Person filtern lässt.
        if (wert.isNotEmpty) personId = wert;
      }
    }
  }

  /// Setzt das Ziel direkt – nur für Tests.
  static void debugSet({String klasse = '', String? person}) {
    classId = klasse;
    personId = person;
  }

  /// Ist in dieser Ansicht überhaupt ein Plan zu sehen?
  ///
  /// Wird von `main.dart` geprüft, bevor die Route `/plan/…` aufgelöst wird.
  /// Ohne Klasse gäbe es nichts zu öffnen, und ein Plan ohne Klasse wäre eine
  /// leere Seite mit einem Zurück-Pfeil – besser, gar keine zu zeigen.
  static bool get isGesetzt => classId.isNotEmpty;
}