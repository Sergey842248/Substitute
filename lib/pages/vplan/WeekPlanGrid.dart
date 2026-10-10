import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/AppColors.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/Weekday.dart';

/// Ein Tag der Wochenübersicht: das Datum und die anzuzeigenden Stunden.
///
/// Die Stunden werden **vor** dem Bauen des Grids bereits gefiltert (ausgeblendete
/// Kurse einer Klasse bzw. die nicht gewählten Kurse einer Person fliegen
/// raus) – sonst entstünden im Grid leere Zilen für Stunden, die es gar nicht
/// anzeigt.
class WeekDayColumn {
  const WeekDayColumn({
    required this.date,
    required this.lessons,
    this.missedCourses = const <String, Map<String, dynamic>>{},
  });

  final DateTime date;
  final List<dynamic> lessons;

  /// Kurs → { 'count': …, 'entryIds': […] } für das Stiftsymbol.
  final Map<String, Map<String, dynamic>> missedCourses;
}

/// Das Wochenraster: die Tage stehen **nebeneinander**, die Stundenzeilen
/// darunter – alles in einem Raster, das ohne Scrollen auf den Bildschirm passt.
///
/// Gegenüber der Tagesansicht ([PlanLessons]) ist nicht die Formatierung
/// verloren gegangen, sondern nur verdichtet: Dieselben Angaben (Stunde, Zeit,
/// Raum, Lehrer, Hinweistext), dieselbe Einfärbung bei Ausfällen und
/// Raum-/Lehreränderungen und dasselbe Stiftsymbol stehen in der Zelle. Eine
/// Zelle ist schmal, deshalb wird der Inhalt bei Bedarf herunterskaliert
/// ([FittedBox]) – so wird keine Zeile abgeschnitten, egal wie viele Stunden
/// und Tage es gibt.
class WeekPlanGrid extends StatelessWidget {
  const WeekPlanGrid({
    Key? key,
    required this.days,
    required this.hideLessonTimes,
    required this.hideTeacher,
    this.onSignatureTap,
  }) : super(key: key);

  /// Die Tage der Woche in Anzeigereihenfolge (Mo–Sa). Tage ohne Plan werden
  /// vom Aufruher weggelassen.
  final List<WeekDayColumn> days;

  final bool hideLessonTimes;
  final bool hideTeacher;

  /// Wird beim Tippen auf das Stiftsymbol aufgerufen.
  final void Function(String course, DateTime day)? onSignatureTap;

  /// Die Stundennummern ("count") der ganzen Woche, aufsteigend sortiert und
  /// ohne Doppelungen. Sie ergeben die Zeilen des Rasters: Eine Stunde, die nur
  /// an einem einzigen Tag stattfindet, bekommt trotzdem ihre eigene Zeile –
  /// sonst stünde sie quer unter den anderen Tagen.
  List<int> _periods() {
    final Set<int> periods = <int>{};
    for (final WeekDayColumn day in days) {
      for (final dynamic lesson in day.lessons) {
        final int? count = int.tryParse('${lesson['count'] ?? ''}'.trim());
        if (count != null) periods.add(count);
      }
    }
    final List<int> sorted = periods.toList()..sort();
    return sorted;
  }

  /// Pro Tag die Stunde zu einer Stundennummer. Kommt eine Nummer an einem Tag
  /// mehrfach vor (z.B. zwei Parallelstunden im selben Slot), gewinnt die
  /// erste – so wie in der Tagesansicht, wo die Stunden nach Nummer sortiert
  /// und einfach untereinander angezeigt werden.
  static Map<int, dynamic> _byPeriod(List<dynamic> lessons) {
    final Map<int, dynamic> result = <int, dynamic>{};
    for (final dynamic lesson in lessons) {
      final int? count = int.tryParse('${lesson['count'] ?? ''}'.trim());
      if (count == null || result.containsKey(count)) continue;
      result[count] = lesson;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<int> periods = _periods();
    if (days.isEmpty || periods.isEmpty) return const SizedBox.shrink();

    final DateTime today = AppClock.now();

    // Welche Kurse bekommen an welchem Tag das Stiftsymbol? Wird hier – vor
    // dem Aufbau – einmal je Tag berechnet und nicht beim Zellenaufbau
    // mitgezählt: Das Widget ist zustandslos, ein Zähler darin würde über
    // Rebuilds hinweg falsche Werte zeigen (unten erklärt).
    final Map<String, Set<String>> signatureCourses = <String, Set<String>>{
      for (final WeekDayColumn day in days)
        _dayId(day.date): _signatureCoursesOf(day),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth = constraints.maxWidth / days.length;
        const double headerHeight = 36;
        // Die Zeilen teilen sich den Rest der Höhe. Sie werden dadurch alle
        // gleich hoch – das ist der Grund, warum hier kein Scrollen nötig ist.
        final double rowHeight =
            (constraints.maxHeight - headerHeight) / periods.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: days
                    .map(
                      (WeekDayColumn day) => _dayHeader(
                        context,
                        l10n,
                        day.date,
                        cellWidth,
                        isToday: _sameDay(day.date, today),
                      ),
                    )
                    .toList(),
              ),
            ),
            for (final int period in periods)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: days.map((WeekDayColumn day) {
                    final Map<int, dynamic> byPeriod = _byPeriod(day.lessons);
                    final Widget cell = _lessonCell(
                      context,
                      lesson: byPeriod[period],
                      period: period,
                      day: day,
                      showSignature: signatureCourses[_dayId(day.date)]
                          ?.contains(_courseOfSafe(byPeriod[period])) ??
                          false,
                    );
                    // Eine dünne Trennlinie zwischen den Tagen: Ohne sie
                    // verschwimmen die Spalten, weil die Zellen sehr schmal
                    // sind und direkt aneinandergrenzen.
                    return _withDivider(context, cell, cellWidth,
                        isLast: day == days.last);
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _withDivider(
    BuildContext context,
    Widget child,
    double width, {
    required bool isLast,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.only(right: isLast ? 0 : 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
        ),
        child: child,
      ),
    );
  }

  /// Spaltenkopf: Wochentagskürzel und Tageszahl. Der heutige Tag wird
  /// hervorgehoben, damit in einer Woche mit vielen Tagen klar ist, wo „jetzt“
  /// gerade ist.
  Widget _dayHeader(
    BuildContext context,
    AppLocalizations l10n,
    DateTime date,
    double width, {
    required bool isToday,
  }) {
    final Color color = isToday
        ? Theme.of(context).primaryColor
        : Theme.of(context).focusColor.withValues(alpha: 0.8);
    return Container(
      width: width,
      alignment: Alignment.center,
      // `scaleDown` wie in den Zellen: Die Zeilenhöhe wird aufgeteilt und ist
      // deshalb nicht garantiert groß genug für zwei Textzeilen – ohne das
      // lief der Kopf bei gedrängten Ansichten über.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayShort(l10n, date),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              DateFormat('dd.MM').format(date),
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Eine Rasterzelle: die Stunde dieses Tages in der Stundennummer [period].
  ///
  /// Hat der Tag in dieser Nummer keine Stunde, bleibt die Zelle leer – sie
  /// gehört aber zum Raster, damit die anderen Tage auf der Höhe stehen.
  Widget _lessonCell(
    BuildContext context, {
    required dynamic lesson,
    required int period,
    required WeekDayColumn day,
    required bool showSignature,
  }) {
    final double cellWidth = MediaQuery.of(context).size.width / days.length;

    if (lesson is! Map) {
      return Container(
        width: cellWidth,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
        ),
      );
    }

    final String course = _courseOf(lesson);

    // Dieselbe Einfärbung wie in der Tagesansicht: Ausfälle und Hinweise
    // bekommen ihre Fläche, eine Raum-/Lehreränderung zusätzlich den roten
    // Aktionston.
    final HinweisTon ton =
        AppColors.hinweisTonVon(Map<String, dynamic>.from(lesson));
    final bool hinweis = ton != HinweisTon.keiner;
    final Color raumAenderungsFarbe = AppColors.aktionston(context);

    final bool placeChanged = lesson['placeChanged'] == true;
    final bool teacherChanged = lesson['teacherChanged'] == true;

    final Color baseColor = hinweis
        ? AppColors.hinweisText(context)
        : Theme.of(context).colorScheme.onSurface;

    final Widget content = SizedBox(
      width: cellWidth - 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$period',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: baseColor.withValues(alpha: 0.7),
                ),
              ),
              if (showSignature) ...[
                const SizedBox(width: 3),
                InkWell(
                  onTap: () => onSignatureTap?.call(course, day.date),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '${day.missedCourses[course]?['count']}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 1),
          Text(
            lesson['lesson']?.toString() ?? '---',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          if (!hideLessonTimes)
            Text(
              '${lesson['begin'] ?? '---'}–${lesson['end'] ?? '---'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: baseColor.withValues(alpha: 0.8),
              ),
            ),
          _smallLine(
            Icons.location_on_rounded,
            lesson['place']?.toString() ?? '---',
            baseColor,
            placeChanged ? raumAenderungsFarbe : null,
          ),
          if (!hideTeacher)
            _smallLine(
              Icons.person_rounded,
              lesson['teacher']?.toString() ?? '---',
              baseColor,
              teacherChanged ? raumAenderungsFarbe : null,
            ),
          if (lesson['info'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${lesson['info']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: baseColor,
                ),
              ),
            ),
        ],
      ),
    );

    return Container(
      width: cellWidth,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.hinweisFlaecheVon(context, ton) ??
            Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        // `scaleDown`: Passt der Inhalt nicht in die Zeilenhöhe, wird er
        // kleiner gesetzt, statt abgeschnitten. So bleibt die Woche immer
        // vollständig sichtbar – auch bei sehr vielen Stunden.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: content,
        ),
      ),
    );
  }

  /// Eine Zeile „Symbol + Text" in der Zelle (Ort, Lehrer).
  Widget _smallLine(
    IconData icon,
    String text,
    Color baseColor,
    Color? highlightColor,
  ) {
    final Color color = highlightColor ?? baseColor.withValues(alpha: 0.85);
    return Row(
      children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: highlightColor == null
                  ? FontWeight.normal
                  : FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  static String _courseOf(dynamic lesson) {
    if (lesson is! Map) return '';
    return _courseOfSafe(lesson);
  }

  /// Wie [_courseOf], aber ohne Absturz bei einer leeren Zelle (`lesson` ist
  /// dann `null`).
  static String _courseOfSafe(dynamic lesson) {
    if (lesson is! Map) return '';
    final String course = lesson['course']?.toString() ?? '';
    if (course.isEmpty || course == '---') {
      return lesson['lesson']?.toString() ?? '';
    }
    return course;
  }

  /// Die Kurse, die an diesem Tag das Stiftsymbol bekommen.
  ///
  /// Es ist immer nur die **erste** Stunde eines Kurses, die es trägt – sonst
  /// stünde es bei mehreren Stunden desselben Kurses mehrfach in der Spalte.
  /// Die Stunden kommen bereits sortiert aus [WeekDayColumn.lessons], deshalb
  /// genügt der erste Treffer.
  static Set<String> _signatureCoursesOf(WeekDayColumn day) {
    final Set<String> result = <String>{};
    for (final dynamic lesson in day.lessons) {
      if ((day.missedCourses[_courseOfSafe(lesson)]?['count'] ?? 0) <= 0) {
        continue;
      }
      result.add(_courseOfSafe(lesson));
    }
    return result;
  }

  static String _dayId(DateTime date) => '${date.year}-${date.month}-${date.day}';
}