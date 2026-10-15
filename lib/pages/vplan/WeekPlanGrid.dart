import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:substitute/services/NativeShell.dart';
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
    this.info = const <dynamic>[],
    this.missedCourses = const <String, Map<String, dynamic>>{},
  });

  final DateTime date;
  final List<dynamic> lessons;

  /// Die „Zusatzinformationen" des Tages – dieselben Zeilen, die in der
  /// normalen Tagesansicht unter den Stunden stehen. Sie erscheinen beim
  /// Tippen auf den Tageskopf.
  final List<dynamic> info;

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

  //// So viele Zeilen passen ohne Scrollen auf den Bildschirm.
  ///
  /// Früher wurde hier entschieden, **ab** wie vielen Zeilen gescrollt wird.
  /// Jetzt wird **immer** gescrollt, und diese Zahl hält nur noch fest, wie
  /// viele Zeilen bequem nebeneinander stehen.
  ///
  /// ## Warum immer
  ///
  /// Die native iOS-Leiste liegt über dem Inhalt. Damit die letzte Stunde
  /// **unter** die Leiste geschoben werden kann, muss es etwas geben, das man
  /// verschieben kann – also eine Scrollansicht. Ohne sie musste der Platz
  /// **immer** unten freigehalten werden, und genau dieser feste Streifen sah
  /// aus wie eine Schicht zwischen Raster und Leiste.
  ///
  /// Scrollt die Ansicht, gehört der Platz ans **Ende** der Scrollstrecke – dort
  /// erscheint er nur, wenn man ganz unten ist, und beim Scrollen bleibt das
  /// Raster hinter der Leiste sichtbar. Das ist dasselbe Verhalten wie auf
  /// allen anderen Bildschirmen.
  ///
  /// Scrollen, obwohl wenig da ist, ist trotzdem unschön; es bewegt sich aber
  /// nur um die Höhe der Leiste, und dafür ist die letzte Stunde erreichbar.
  ///
  /// ## Zweite Bedeutung: Obergrenze der Zeilenhöhe
  ///
  /// Dieselbe Zahl sagt zugleich, wie hoch **eine** Stunde höchstens wird.
  /// Ohne diese Grenze teilte ein Tag mit drei Stunden die verfügbare Höhe
  /// durch drei, und jede Zelle wäre ein mehrere hundert Pixel hohes Feld,
  /// in dem der Inhalt oben klebt – ein sehr gestreckt wirkendes Raster.
  static const int rowsWithoutScrolling = 8;

  /// Wie viele Zeilen über [rowsWithoutScrolling] hinaus bequem sichtbar sind
  /// – hier eine halbe.
  ///
  /// Ohne diesen Rest würde die neunte Stunde exakt unterhalb der Kante liegen
  /// und man sähe nicht, dass es weitergeht. Der halbe Rest ist der Hinweis.
  static const double scrollPeekRows = 0.5;

  /// Zeilenhöhe **jeder** Angabe im Raster, als Vielfaches der Schriftgröße.
  ///
  /// ## Warum nicht kleiner – und warum überhaupt eine Zahl
  ///
  /// `TextStyle.height` ist kein „Abstand zwischen den Zeilen", sondern die
  /// **gesamte** Zeilenhöhe. Sie muss mindestens so groß sein wie der Zeilenabstand,
  /// den die Schrift von sich aus hat – bei den Systemschriften sind das rund
  /// **1.15 bis 1.2** Schriftgrößen (Oberlänge + Unterlänge plus etwas Luft).
  ///
  /// Mit dem Wert 1.02, den die Zellen früher hatten, war die Zeilenhöhe **kleiner**
  /// als der Buchstabe selbst: Ober- und Unterlänge der einen Zeile ragten in die
  /// nächste hinein, und im Raster – wo fünf solcher Zeilen untereinanderstehen –
  /// liefen Fach und Raum, Raum und Lehrer ineinander. Das war keine Rundung,
  /// das war eine um rund zwei Pixel zu kleine Zeilenhöhe je Zeile.
  ///
  /// [BoxFit.scaleDown] verkleinert den ganzen Block dabei gleichmäßig, also auch
  /// diesen Abstand: Eine größere Zeilenhöhe macht die Schrift nicht größer, sie
  /// verhindert nur das Überlappen.
  static const double zeilenHoehe = 1.18;

  /// Die Zeilen des Rasters: so viele, wie der Tag mit den meisten Stunden hat.
  ///
  /// Die Stunden werden **einfach untereinander** gereiht und nicht nach
  /// Stundennummer ausgerichtet. Grund: Eine Stundennummer kann mehrfach
  /// vorkommen (z.B. zwei Kurse in der 1. Stunde oder eine geteilte
  /// Doppelstunde) – im Raster nach Nummer ausgerichtet ginge einer dieser
  /// Kurse verloren. So bekommt jeder Kurs seine eigene Zeile, in der
  /// Reihenfolge, in der der Vertretungsplan sie für diesen Tag ausgibt.
  int get _rowCount {
    int max = 0;
    for (final WeekDayColumn day in days) {
      if (day.lessons.length > max) max = day.lessons.length;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int rows = _rowCount;
    if (days.isEmpty || rows == 0) return const SizedBox.shrink();

    // Welche Kurse bekommen an welchem Tag das Stiftsymbol? Wird hier – vor
    // dem Aufbau – einmal je Tag berechnet und nicht beim Zellenaufbau
    // mitgezählt: Das Widget ist zustandslos, ein Zähler darin würde über
    // Rebuilds hinweg falsche Werte zeigen.
    final Map<String, Set<String>> signatureCourses = <String, Set<String>>{
      for (final WeekDayColumn day in days)
        _dayId(day.date): _signatureCoursesOf(day),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth = constraints.maxWidth / days.length;
        // Genug Platz fuer die beiden Zeilen des Tageskopfs **ohne**
        // Herunterskalieren: Bei 26 Pixeln fasste das [FittedBox] beide
        // Zeilen nur, indem es sie auf rund 80 % verkleinerte – die Schrift
        // sah dadurch deutlich kleiner aus, als sie eingestellt war.
        const double headerHeight = 42;
        // Die Höhe, die den Stundenzeilen überhaupt zur Verfügung steht.
        final double rowsArea = constraints.maxHeight - headerHeight;

        // Die Zeilen teilen sich den Rest der Höhe – aber **nie mehr, als**
        // eine Zeile braucht, um gut auszusehen.
        //
        // ## Der Fall, um den es hier geht
        //
        // Gäbe es einen Tag mit drei Stunden, teilte man die Höhe durch drei:
        // Jede Zelle wäre gut 200 Pixel hoch – gut viermal so hoch wie eine
        // normale. Der Inhalt ([FittedBox], oben ausgerichtet) füllt davon aber
        // nur ein Dritel, sodass unten in jeder Zelle ein leeres Stück Fläche
        // klebt und das Raster **gestreckt** aussieht: Die Stunden schweben als
        // schmale Streifen in einem viel zu hohen Feld, statt dicht
        // untereinander zu stehen.
        //
        // Deshalb ist [rowsWithoutScrolling] eine Obergrenze für die
        // Zeilenhöhe: Acht Zeilen füllen den Bereich, jede einzelne wird
        // höchstens so hoch. Hat ein Tag weniger Stunden, bleiben die Zellen
        // Normalgröße, und der Rest ist ein leeres Band **unter** dem Raster –
        // dort, wo ohnehin die Navigationsleiste liegt, und nicht als
        // Leerraum in jeder Zelle.
        //
        // Ab der neunten Zeile wird durch `8 + scrollPeekRows` geteilt: Acht
        // volle Zeilen plus ein halber Rest der neunten, der sichtbar bleibt und
        // damit verrät, dass noch etwas kommt. Diese Kappung greift dann nicht,
        // weil acht Zeilen neun gar nicht erreichen.
        final double rowHeight = math.min(
          rowsArea /
              (rows < rowsWithoutScrolling
                  ? rows
                  : rowsWithoutScrolling + scrollPeekRows),
          rowsArea / rowsWithoutScrolling,
        );

        final Widget rowsWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int row = 0; row < rows; row++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: days.map((WeekDayColumn day) {
                    final dynamic lesson =
                        row < day.lessons.length ? day.lessons[row] : null;
                    final Widget cell = _lessonCell(
                      context,
                      lesson: lesson,
                      day: day,
                      row: row,
                      showSignature: lesson != null &&
                          (signatureCourses[_dayId(day.date)]
                                  ?.contains(_courseOfSafe(lesson)) ??
                              false),
                    );
                    // Eine dünne Trennlinie zwischen den Tagen: Ohne sie
                    // verschwimmen die Spalten, weil die Zellen sehr schmal
                    // sind und direkt aneinandergrenzen.
                    return _withDivider(context, cell, cellWidth,
                        isLast: day == days.last);
                  }).toList(),
                ),
              ),
            // Der Rest der Höhe, den die (nach unten hin gekappten) Zeilen nicht
            // mehr brauchen.
            //
            // Er gehört **hier**her und nicht in die Zellen: Nur so bleibt der
            // Platz für die Navigationsleiste – weiter unten – am Ende der
            // Scrollstrecke, auch wenn das Raster den Bereich nicht füllt.
            // Ohne ihn stünde der Platz mitten im leeren Band, statt unter den
            // Stunden zu warten, wo man ihn zum Hochschieben der letzten
            // Stunde braucht.
            if (rows * rowHeight < rowsArea)
              SizedBox(height: rowsArea - rows * rowHeight),
            // Der Platz für die native Tab-Leiste, **am Ende der
            // Scrollstrecke** und nicht als fester Rand um das Raster.
            //
            // Als fester Rand wäre er immer sichtbar – eine Schicht zwischen
            // Raster und Leiste, die man nicht wegscrollen kann. Hier erscheint
            // er erst ganz unten, und beim Scrollen bleibt das Raster hinter
            // der Leiste sichtbar: dasselbe wie auf allen anderen
            // Bildschirmen.
            const NativeShellScrollEndInset(),
          ],
        );

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
                        day,
                        cellWidth,
                      ),
                    )
                    .toList(),
              ),
            ),
            // **Immer** scrollbar, nicht erst ab der neunten Zeile.
            //
            // Der Grund ist nicht die Menge der Zeilen, sondern die Leiste:
            // Sie liegt über dem Inhalt, und nur eine Scrollansicht erlaubt,
            // die letzte Stunde unter ihr hervorzuholen. Ohne Scrollen
            // müsste der Platz dauerhaft unten freigehalten werden – und
            // genau dieser feste Streifen sah aus wie eine Schicht.
            //
            // Die schlichte Physik: Es wird gescrollt, wenn etwas über den Rand
            // hinausreicht – und das ist hier immer der Fall, weil der
            // Absende-Platz die Ansicht genau um seine Höhe überstehen lässt.
            // Kein `AlwaysScrollable`, das auch ohne Inhalt wippen würde.
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: rowsWidget,
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
      padding: EdgeInsets.only(right: isLast ? 0 : 1.5),
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

  /// Spaltenkopf: Wochentagskürzel und Tageszahl, mittig und antippenbar.
  ///
  /// Der heutige Tag wird hervorgehoben, damit in einer Woche mit vielen Tagen
  /// klar ist, wo „jetzt“ gerade ist. Tippen auf den Kopf zeigt die
  /// Zusatzinformationen des Tages – dieselben, die in der Tagesansicht unter
  /// den Stunden stehen.
  Widget _dayHeader(
    BuildContext context,
    AppLocalizations l10n,
    WeekDayColumn day,
    double width,
  ) {
    final bool isToday = _sameDay(day.date, AppClock.now());
    final Color color = isToday
        ? Theme.of(context).primaryColor
        : Theme.of(context).focusColor.withValues(alpha: 0.8);
    return Container(
      width: width,
      alignment: Alignment.center,
      child: InkWell(
        onTap: () => _showDayInfo(context, day),
        child: FittedBox(
          // `scaleDown` wie in den Zellen: Die Kopfhöhe ist fest, die
          // Wochentagsangaben aber so breit, wie der Tag es hergibt.
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayShort(l10n, day.date),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: zeilenHoehe,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                // Nur die Tageszahl, nicht das ganze Datum: Bei sechs Spalten
                // ist eine Spalte gut 60 Pixel breit – „21.9." passt dort bei
                // 14 Pixeln Schrift nicht hinein und würde ständig
                // herunterskaliert. Der Monat steht ohnehin in der Zeile
                // darüber („21.09. - 26.09.").
                DateFormat('d').format(day.date),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: zeilenHoehe,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Die Zusatzinformationen eines Tages – dieselben Zeilen, die in der
  /// Tagesansicht unter den Stunden stehen („ZusatzInfo" des
  /// Vertretungsplans, z.B. „Morgen Sport in der Halle").
  void _showDayInfo(BuildContext context, WeekDayColumn day) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<String> lines = day.info
        .map((dynamic e) => '$e'.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Center(
          child: Text(
            '${weekdayShort(l10n, day.date)}, '
            '${DateFormat('dd.MM.yyyy').format(day.date)}',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        contentPadding: const EdgeInsets.all(15),
        actionsPadding: const EdgeInsets.all(0),
        content: lines.isEmpty
            ? Text(
                l10n.noAdditionalInformation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map(
                      (String line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line, style: const TextStyle(fontSize: 16)),
                      ),
                    )
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
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
    required WeekDayColumn day,
    required int row,
    required bool showSignature,
  }) {
    final double cellWidth = MediaQuery.of(context).size.width / days.length;

    if (lesson is! Map) {
      return Container(
        width: cellWidth,
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 0.5),
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

    // **Schriftgrößen-Hierarchie der Zelle** (bewusst so gewählt):
    //   1. Fach     – die wichtigste Angabe, deshalb am größten
    //   2. Raum     – wo die Stunde stattfindet
    //   3. Lehrer   – wer sie hält
    //   4. Uhrzeit  – die nachgeordnete Angabe, deshalb ganz unten und am
    //                 kleinsten (nur wenn nicht ausgeblendet)
    //
    // Alle vier bekommen **dieselbe** Zeilenhöhe ([zeilenHoehe]), nicht eine
    // eigene, engere: Eine engere Zeilenhöhe sieht bei einer einzelnen Zeile
    // kompakter aus, lässt aber Ober- und Unterlänge ineinanderragen – und hier
    // stehen vier solcher Zeilen direkt untereinander. Siehe dort, warum 1.02 zu
    // wenig war.
    //
    // Eine Änderung an Raum oder Lehrer wird **ausschließlich über die Farbe**
    // angezeigt (rot, `aktionston`). Bewusst kein Fettdruck und kein
    // zusätzliches Symbol: In der schmalen Zelle konkurrieren diese Angaben
    // mit dem Fach um den Platz, und der Text soll dadurch nicht zusätzlich
    // aus der Reihe fallen. Wer wissen will, ob etwas geändert wurde, tippt auf
    // die Stunde – dort steht der Hinweis ausgeschrieben.
    final Widget content = SizedBox(
      width: cellWidth - 6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Mittig: Die Zelle ist schmal, und linksbündiger Text würde bei
        // unterschiedlich langen Angaben (Fach, Raum, Lehrer) immer an derselben
        // Kante kleben statt mittig in der Spalte zu sitzen.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${lesson['count'] ?? ''}',
                // Punkt 4: die Stundennummer war zu klein.
                style: TextStyle(
                  fontSize: 11,
                  height: zeilenHoehe,
                  fontWeight: FontWeight.bold,
                  color: baseColor.withValues(alpha: 0.55),
                ),
              ),
              if (showSignature) ...[
                const SizedBox(width: 2),
                // Das Stiftsymbol ist die einzige Stelle in der Zelle mit
                // eigener Tap-Fläche: Es öffnet die Unterschriften-Abfrage und
                // darf das Antippen der Zelle (Zusatzinfos) nicht auslösen.
                InkWell(
                  onTap: () => onSignatureTap?.call(course, day.date),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  '${day.missedCourses[course]?['count']}',
                  style: TextStyle(
                    fontSize: 9,
                    height: zeilenHoehe,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ],
          ),
          Text(
            lesson['lesson']?.toString() ?? '---',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: zeilenHoehe,
              color: baseColor,
            ),
          ),
          Text(
            lesson['place']?.toString() ?? '---',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: zeilenHoehe,
              fontWeight: FontWeight.w600,
              color: placeChanged
                  ? raumAenderungsFarbe
                  : baseColor.withValues(alpha: 0.85),
            ),
          ),
          if (!hideTeacher)
            Text(
              lesson['teacher']?.toString() ?? '---',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: zeilenHoehe,
                fontWeight: FontWeight.w500,
                color: teacherChanged
                    ? raumAenderungsFarbe
                    : baseColor.withValues(alpha: 0.75),
              ),
            ),
          if (!hideLessonTimes)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${lesson['begin'] ?? '---'}–${lesson['end'] ?? '---'}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: zeilenHoehe,
                  color: baseColor.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );

    return Container(
      width: cellWidth,
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 0.5),
      // Eindeutiger Schlüssel: Die Zellen sind von außen nicht unterscheidbar,
      // und ein Test muss genau eine Stundenzelle treffen können – der
      // gleichnamige Tageskopf ist ebenfalls eine [InkWell].
      key: ValueKey<String>('lessonCell_${_dayId(day.date)}_$row'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.hinweisFlaecheVon(context, ton) ??
            Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      // Tippen auf die Stunde zeigt die Zusatzinformationen (Hinweistext des
      // Vertretungsplans, Kurs, vollständige Zeiten). Im Raster selbst ist
      // dafür bewusst kein Platz – der Hinweistext würde das Grid sprengen.
      child: InkWell(
        onTap: () => _showLessonDetails(context, lesson, day.date),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
          // `scaleDown`: Passt der Inhalt nicht in die Zeilenhöhe, wird er
          // kleiner gesetzt, statt abgeschnitten. So bleibt die Woche immer
          // vollständig sichtbar – auch bei sehr vielen Stunden.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: content,
          ),
        ),
      ),
    );
  }

  /// Zeigt die Zusatzinformationen zu einer Stunde: den Hinweistext des
  /// Vertretungsplans („Entfall", „Raumänderung", „Vertretung" …), den Kurs
  /// und – falls nicht ausgeblendet – die vollständigen Zeiten.
  void _showLessonDetails(
    BuildContext context,
    dynamic lesson,
    DateTime day,
  ) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(lesson as Map);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String info = data['info']?.toString().trim() ?? '';
    final String course = _courseOf(data);
    final String place = data['place']?.toString() ?? '';
    final String teacher = data['teacher']?.toString() ?? '';
    final String time = '${data['begin'] ?? '---'} – ${data['end'] ?? '---'}';
    final String subject = data['lesson']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Center(
          child: Text(
            '${weekdayShort(l10n, day)}, ${DateFormat('dd.MM.yyyy').format(day)}'
            ' – $subject',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        contentPadding: const EdgeInsets.all(15),
        actionsPadding: const EdgeInsets.all(0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.isNotEmpty)
              Text(
                info,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            if (course.isNotEmpty && course != subject)
              _detailLine(context, Icons.bookmark_rounded, course),
            if (place.isNotEmpty)
              _detailLine(
                context,
                Icons.location_on_rounded,
                place,
                color: data['placeChanged'] == true
                    ? AppColors.aktionston(context)
                    : null,
              ),
            if (teacher.isNotEmpty)
              _detailLine(
                context,
                Icons.person_rounded,
                teacher,
                color: data['teacherChanged'] == true
                    ? AppColors.aktionston(context)
                    : null,
              ),
            _detailLine(context, Icons.access_time_rounded, time),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  /// Eine Zeile im Detail-Dialog: Symbol + Angabe.
  Widget _detailLine(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: color == null ? FontWeight.normal : FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
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

  static String _dayId(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}
