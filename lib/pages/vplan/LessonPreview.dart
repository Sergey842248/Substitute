import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/services/AppClock.dart';

import 'VPlanAPI.dart';

/// Zustand einer Vorschau, die noch nicht geladen wurde. Solange dieser Wert
/// gesetzt ist, wird nichts angezeigt (siehe [LessonPreviewCard]).
const Map<String, dynamic> previewLoading = {'': 'loading'};

/// Zustand, in dem für den Plan keine (weitere) Stunde gefunden wurde.
const Map<String, dynamic> previewEmpty = {};

/// True, wenn [nextLesson] den Ladezustand beschreibt.
bool isPreviewLoading(Map<String, dynamic> nextLesson) =>
    nextLesson[''] == 'loading';

/// Parst eine Zeitangabe ("08:45") in eine [TimeOfDay]. Liefert `null`, wenn
/// die Angabe fehlt oder nicht auswertbar ist.
TimeOfDay? safeToTimeOfDay(dynamic value) {
  final String time = value?.toString() ?? '';
  if (time.isEmpty || !time.contains(':')) return null;
  try {
    final List<String> parts = time.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  } catch (_) {
    return null;
  }
}

/// Formatiert eine [TimeOfDay] als "hh:mm".
String formatTimeOfDay(TimeOfDay time) {
  final String hour = time.hour < 10 ? '0${time.hour}' : '${time.hour}';
  final String minute = time.minute < 10 ? '0${time.minute}' : '${time.minute}';
  return '$hour:$minute';
}

/// Formatiert einen Zeitraum ("08:45 - 09:30"). Liefert einen leeren String,
/// wenn Anfang oder Ende nicht auswertbar ist.
String formatLessonTimeRange(dynamic begin, dynamic end) {
  final TimeOfDay? beginTime = safeToTimeOfDay(begin);
  final TimeOfDay? endTime = safeToTimeOfDay(end);
  if (beginTime == null || endTime == null) return '';
  return '${formatTimeOfDay(beginTime)} - ${formatTimeOfDay(endTime)}';
}

/// Ein Eintrag darf nur als „nächste Stunde“ angezeigt werden, wenn er
/// wirklich eine Stunde beschreibt – reine Info-Zeilen (Kurs "---" oder ohne
/// Stundenbezeichnung) werden übersprungen.
bool isRealLesson(dynamic lesson) =>
    lesson is Map && lesson['course'] != '---' && lesson['lesson'] != null;


/// Berechnet aus dem (heutigen) Plan [plan] die nächste anzuzeigende Stunde.
///
/// [mode] ist der unter 'defaultPlanModePreview' gespeicherte Vorschau-Modus:
/// 'today' verlässt den heutigen Plan nie, 'latest' wechselt auch nach
/// Schulschluss auf den nächsten Schultag, 'auto' nur, wenn der heutige
/// Schultag vorbei ist.
///
/// [isHidden] filtert Einträge heraus, die nicht angezeigt werden sollen
/// (ausgeblendete Kurse einer Klasse bzw. die von einer Person nicht gewählten
/// Kurse). [allowNextDay] == false (sofortiger Cache-Pfad) löst keine weitere
/// Netzwerkanfrage für den Folgetag aus – das übernimmt der Hintergrund-Refresh.
Future<Map<String, dynamic>> computeNextLesson({
  required dynamic plan,
  required String mode,
  required String classId,
  required bool Function(dynamic lesson) isHidden,
  bool allowNextDay = true,
  VPlanAPI? vplanAPI,
}) async {
  if (plan is! Map || plan['data'] is! List) return previewEmpty;
  final VPlanAPI api = vplanAPI ?? VPlanAPI();

  final List<dynamic> lessons = [];
  for (final dynamic lesson in plan['data']) {
    if (isRealLesson(lesson) && !isHidden(lesson)) lessons.add(lesson);
  }

  // Zeit, ab der die nächste Stunde gesucht wird. Liegt der Plan selbst in
  // der Zukunft (z.B. bereits der Plan des Folgetags), wird ab Mitternacht
  // gesucht.
  final DateTime now = AppClock.now();
  TimeOfDay currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
  try {
    if (plan['date'] != null &&
        api.parseStringDatatoDateTime(plan['date'].toString()).isAfter(now)) {
      currentTime = const TimeOfDay(hour: 0, minute: 0);
    }
  } catch (_) {
    // Datum nicht auswertbar – mit der aktuellen Zeit weiterarbeiten.
  }

  // GET NEXT LESSON
  double lowestDifference = 50;
  int lessonIndex = 0;
  bool foundNextLesson = false;
  for (var i = 0; i < lessons.length; i++) {
    final TimeOfDay? beginTime = safeToTimeOfDay(lessons[i]['begin']);
    if (beginTime == null) continue;
    double difference = (beginTime.hour + (beginTime.minute / 60)) -
        (currentTime.hour + (currentTime.minute / 60));
    if (difference < lowestDifference && difference >= 0) {
      lowestDifference = difference;
      lessonIndex = i;
      foundNextLesson = true;
    }
  }

  if (foundNextLesson) {
    return Map<String, dynamic>.from(lessons[lessonIndex] as Map);
  }

  // Keine Stunde mehr heute: Wochenende oder nach Schulschluss.
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
    return {'weekend': true};
  }

  bool afterSchool = false;
  if (lessons.isNotEmpty) {
    final TimeOfDay? endTime = safeToTimeOfDay(lessons.last['end']);
    if (endTime != null) {
      double lastLessonEndTime = (endTime.hour + (endTime.minute / 60));
      afterSchool =
          (currentTime.hour + (currentTime.minute / 60)) > lastLessonEndTime;
    }
  } else {
    afterSchool = true;
  }

  if (!afterSchool && mode != 'latest') return previewEmpty;
  if (mode == 'today') return previewEmpty;
  if (!allowNextDay) return previewEmpty;

  // Determine the next school day
  DateTime nextDay = now.add(const Duration(days: 1));
  while (nextDay.weekday == DateTime.saturday ||
      nextDay.weekday == DateTime.sunday) {
    nextDay = nextDay.add(const Duration(days: 1));
  }

  try {
    final dynamic nextDayPlan =
        await api.getLessonsByDate(date: nextDay, classId: classId);

    if (nextDayPlan is Map &&
        nextDayPlan['data'] != null &&
        nextDayPlan['data'] is List &&
        (nextDayPlan['data'] as List).isNotEmpty) {
      final List<dynamic> nextDayLessons = [];
      for (final dynamic lesson in nextDayPlan['data']) {
        if (isRealLesson(lesson) && !isHidden(lesson)) {
          nextDayLessons.add(lesson);
        }
      }
      if (nextDayLessons.isNotEmpty) {
        return Map<String, dynamic>.from(nextDayLessons.first as Map);
      }
    }
  } catch (_) {
    // Ohne (frische) Daten des Folgetags bleibt es beim Wochenend-Hinweis.
  }
  return {'weekend': true};
}

/// Kompakte „Nächste Stunde“-Vorschau, die direkt unter einem Klassen- bzw.
/// Personeneintrag angezeigt wird.
class LessonPreviewCard extends StatelessWidget {
  const LessonPreviewCard({
    Key? key,
    required this.nextLesson,
    this.onTap,
    this.hideLessonTimes = true,
    this.showCourse = false,
  }) : super(key: key);

  final Map<String, dynamic> nextLesson;
  final VoidCallback? onTap;

  /// Wenn true, wird die Zeitspanne der Stunde nicht angezeigt.
  final bool hideLessonTimes;

  /// Bei einer Person ist der Kurs (z.B. "M-1") die zentrale Angabe, bei
  /// einer Klasse das Fach. Wenn true, steht der Kurs fett in der Vorschau.
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    if (isPreviewLoading(nextLesson)) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          child: child,
        ),
        child: Container(
          key: ValueKey(nextLesson),
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (nextLesson['weekend'] == true) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.weekend_rounded,
            size: 24,
            color: Theme.of(context).focusColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.weekend,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    if (nextLesson.isEmpty) {
      return Text(
        AppLocalizations.of(context)!.noNextLessonFound,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final String course = nextLesson['course']?.toString() ?? '';
    final String lesson = nextLesson['lesson']?.toString() ?? '';
    final String title = showCourse && course.isNotEmpty ? course : lesson;
    final String timeRange =
        formatLessonTimeRange(nextLesson['begin'], nextLesson['end']);

    // Anordnung bewusst unverändert lassen: beide Blöcke sitzen am
    // ursprünglichen Abstand auseinander (30 % der Bildschirmbreite) und
    // werden oben bündig ausgerichtet. Nur die Abstände/Fonts sind kompakter
    // geworden – die Position der Elemente bleibt so, wie sie war.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextLesson['teacher']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!
                  .room(nextLesson['place']?.toString() ?? ''),
              style: TextStyle(
                fontSize: 17,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (!hideLessonTimes && timeRange.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeRange,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Option für die Kopfzeile eines Plans, mit der die Vorschau (Klasse oder
/// Person) ein- und ausgeblendet werden kann. Das Symbol zeigt den aktuellen
/// Zustand: ausgefüllter Notiz-Zettel = Vorschau sichtbar, nur umrandeter
/// Zettel = ausgeblendet.
class PreviewVisibilityToggle extends StatelessWidget {
  const PreviewVisibilityToggle({
    Key? key,
    required this.hidden,
    required this.onPressed,
  }) : super(key: key);

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: const ValueKey<String>('previewVisibilityToggle'),
      onPressed: onPressed,
      tooltip: hidden ? l10n.showPreview : l10n.hidePreview,
      icon: Icon(
        hidden ? Icons.sticky_note_2_outlined : Icons.sticky_note_2_rounded,
      ),
    );
  }
}

