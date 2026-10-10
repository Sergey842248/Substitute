import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/services/AppColors.dart';

/// Liefert [value] zurück oder "---", wenn die Angabe fehlt. Wird für die
/// einzelnen Felder einer Stunde benutzt, damit eine fehlende Angabe wie in
/// der normalen Planansicht dargestellt wird.
String printPlanValue(String? value) {
  if (value == null) {
    return '---';
  }
  return value;
}

/// Die Stunden eines Tages – in genau der Formatierung, die auch die normale
/// Planansicht verwendet.
///
/// Bewusst als eigenes Widget statt als Teil von [Plan]: Die Wochenansicht
/// zeigt dieselben Stunden, und zwar mit denselben Ausblendungen
/// ([hideLessonTimes]/[hideTeacher]), derselben Hinweis-Färbung und demselben
/// Stiftsymbol für noch einzuholende Unterschriften. Würde sie ihre Zeilen
/// selbst bauen, könnten die beiden Ansichten auseinanderlaufen.
class PlanLessons extends StatelessWidget {
  const PlanLessons({
    Key? key,
    required this.lessons,
    required this.hideLessonTimes,
    required this.hideTeacher,
    required this.isVisible,
    this.missedCourses = const <String, Map<String, dynamic>>{},
    this.onSignatureTap,
  }) : super(key: key);

  final List<dynamic> lessons;

  /// Wenn true, wird die Zeitspanne der Stunde nicht angezeigt.
  final bool hideLessonTimes;

  /// Wenn true, wird der Lehrername der Stunde nicht angezeigt.
  final bool hideTeacher;

  /// Entscheidet, ob eine Stunde überhaupt angezeigt wird – z.B. weil ihr
  /// Kurs in den Klasseneinstellungen ausgeblendet ist oder die Person den
  /// Kurs nicht ausgewählt hat.
  final bool Function(dynamic lesson) isVisible;

  /// Kurs → { 'count': Anzahl benötigter Unterschriften, 'entryIds': [...] }
  final Map<String, Map<String, dynamic>> missedCourses;

  /// Wird beim Tippen auf das Stiftsymbol bzw. die Beschriftung daneben
  /// aufgerufen – mit dem Kurs, um den es geht.
  final void Function(String course)? onSignatureTap;

  @override
  Widget build(BuildContext context) {
    final Set<String> signatureShown = {};
    return Column(
      // `min`, weil das Widget in einer unbeschränkten Höhe (innerhalb einer
      // ListView) steht – mit der Vorgabe `max` wäre die Höhe unbestimmt.
      mainAxisSize: MainAxisSize.min,
      children: lessons.map((dynamic e) {
        if (!isVisible(e)) return const SizedBox.shrink();

        final String course = _courseOf(e);
        // Das Stiftsymbol steht nur bei der ersten occurrence eines Kurses –
        // sonst würde es bei mehreren Stunden desselben Kurses mehrfach
        // erscheinen.
        final int signatureCount = missedCourses[course]?['count'] ?? 0;
        final bool showSignature =
            signatureCount > 0 && !signatureShown.contains(course);
        if (showSignature) signatureShown.add(course);

        // Hinweiszeilen übernehmen normalerweise ihre Schriftfarbe von der
        // Zeile. Die Raumzeile ist die gezielte Ausnahme: Eine Raumänderung
        // soll auch auf gelbem Hintergrund sofort erkennbar bleiben.
        final HinweisTon ton = AppColors.hinweisTonVon(e);
        final bool hinweis = ton != HinweisTon.keiner;
        // Eine Raumänderung muss sich auch innerhalb einer gelben Hinweiszeile
        // als solche abheben. Sie verwendet daher bewusst immer den roten
        // Aktionston statt der sonst für die ganze Zeile geltenden Textfarbe.
        final Color raumAenderungsFarbe = AppColors.aktionston(context);

        return ListItem(
          onClick: () {},
          // Die Fläche einer Stunde mit Hinweistext („Entfall" …). Sie richtet
          // sich nach dem Theme, weil der Text darauf die Theme-Farbe erbt: Ein
          // fest eingetragenes dunkles Rot funktionierte nur im dunklen Modus
          // und machte den Text im hellen unlesbar.
          color: AppColors.hinweisFlaecheVon(context, ton),
          // Die Zeile bekommt ihre eigene Schriftfarbe: Auf der kräftigen
          // Fläche wäre die schwarze Schrift der App nicht zu erkennen.
          foreground: hinweis ? AppColors.hinweisText(context) : null,
          leading: Text(
            printPlanValue('${e['count']}'),
            style: const TextStyle(fontSize: 18),
          ),
          title: Container(
            alignment: Alignment.centerLeft,
            width: MediaQuery.of(context).size.width * 0.1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  printPlanValue(e['lesson']),
                  style: const TextStyle(fontSize: 19),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hideLessonTimes)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            '${printPlanValue(e['begin'])} - ${printPlanValue(e['end'])}',
                          ),
                        ],
                      ),
                    if (!hideLessonTimes) const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: e['placeChanged'] == true
                              ? raumAenderungsFarbe
                              : null,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          printPlanValue(e['place']),
                          style: e['placeChanged'] == true
                              ? TextStyle(
                                  color: raumAenderungsFarbe,
                                  fontWeight: FontWeight.w900,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (!hideTeacher)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: e['teacherChanged'] == true
                                ? raumAenderungsFarbe
                                : null,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            printPlanValue(e['teacher']),
                            style: e['teacherChanged'] == true
                                ? TextStyle(
                                    color: raumAenderungsFarbe,
                                    fontWeight: FontWeight.w900,
                                  )
                                : null,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          subtitle: (e['info'] == null && !showSignature)
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e['info'] != null)
                      Text(
                        '${e['info']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (showSignature) ...[
                      const SizedBox(height: 4),
                      // Tippen auf das Stiftsymbol oder den Text daneben fragt,
                      // ob die Unterschrift für diesen Kurs als erledigt
                      // markiert werden soll.
                      GestureDetector(
                        onTap: () => onSignatureTap?.call(course),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$signatureCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.getSignature,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        );
      }).toList(),
    );
  }

  /// Der Kurs, unter dem die Stunde läuft. Ohne eigenen Kurs ("---") wird der
  /// Stundenname verwendet – sonst gäbe es unter dem Stiftsymbol nichts
  /// wiederzufinden.
  static String _courseOf(dynamic lesson) {
    final String course = lesson['course']?.toString() ?? '';
    if (course.isEmpty || course == '---') {
      return lesson['lesson']?.toString() ?? '';
    }
    return course;
  }
}