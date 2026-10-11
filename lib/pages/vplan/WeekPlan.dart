import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/models/LoadingIndicator.dart';
import 'package:substitute/models/swipe_page_transition.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/PlanWeek.dart';
import 'package:substitute/services/SchoolStorage.dart';

import 'Plan.dart';
import 'VPlanAPI.dart';
import 'WeekPlanGrid.dart';

/// Die noch einzuholenden Unterschriften eines Tages: Kurs → { 'count': …,
/// 'entryIds': […] }. Als eigener Typ, weil die Verschachtelung sonst
/// unaussprechlich würde.
typedef _DayMissedCourses = Map<String, Map<String, dynamic>>;

/// Der Plan einer ganzen Woche (Mo–Sa) für eine Klasse oder eine Person.
///
/// Wird statt der Tagesansicht [Plan] geöffnet, wenn in den
/// Plan-Einstellungen „Ganze Woche anzeigen“ aktiviert ist.
///
/// Die Stunden werden mit [PlanLessons] gebaut – also mit derselben
/// Formatierung, Ausblendung und denselben Hinweisen wie in der
/// Tagesansicht. Die Kopfzeile zeigt zusätzlich den Zeitraum der Woche und
/// den Wochentyp (A/B), der aus dem Plan des Servers kommt.
class WeekPlan extends StatefulWidget {
  const WeekPlan({
    Key? key,
    required this.classId,
    this.person,
  }) : super(key: key);

  final String classId;
  final Map<String, dynamic>? person;

  @override
  State<WeekPlan> createState() => _WeekPlanState();
}

class _WeekPlanState extends State<WeekPlan> {
  final VPlanAPI _vplanAPI = VPlanAPI();

  /// Montag der aktuell angezeigten Woche.
  /// Der Montag der angezeigten Woche.
  ///
  /// [_startOfWeek] wird **bei jedem Setzen** angewandt – auch beim Blättern zur
  /// Vor- und Nachbarwoche. So kann der Bereich der angezeigten Woche nicht
  /// daran scheitern, dass hier einmal ein Nicht-Montag landet: Ein Start am
  /// Sonntag ergäbe ein Ende in der Woche davor, also eine Datumsrange wie
  /// „25.10. - 24.10.“.
  late DateTime _weekStart = _startOfWeek(AppClock.now());

  static DateTime _startOfWeek(DateTime date) => startOfSchoolWeek(date);

  /// Je Kalendertag (als `yyyy-mm-dd`) der geladene Tagesplan bzw. `null`,
  /// wenn für diesen Tag kein Plan vorliegt.
  Map<String, dynamic> _days = <String, dynamic>{};

  /// Fehler, die beim Laden aufgetreten sind – je Tag derselbe Schlüssel wie
  /// in [_days]. Nur wenn **alle** Tage fehlgeschlagen sind, wird eine
  /// Fehlerseite statt einer leeren Woche gezeigt.
  Map<String, dynamic> _errors = <String, dynamic>{};

  bool _loading = true;
  bool _refreshing = false;

  /// Zählt die Ladevorgänge. Nur der jeweils letzte darf das Ergebnis
  /// übernehmen – siehe [_loadWeek].
  int _loadGeneration = 0;

  bool hideLessonTimes = true;
  bool hideTeacher = false;
  List<String> hiddenSubjects = <String>[];

  /// Kurs → { 'count': …, 'entryIds': […] } je Tag, für das Stiftsymbol.
  Map<String, _DayMissedCourses> _missedCourses = <String, _DayMissedCourses>{};

  String? className;

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Die fünf Schultage der angezeigten Woche (Mo–Fr, siehe
  /// [startOfSchoolWeek]).
  ///
  /// Der Samstag gehört nicht dazu: An den allermeisten Schulen findet samstags
  /// kein Unterricht statt. Eine leere sechste Spalte wäre nur stehengebliebene
  /// Breite – auf dem Telefon kostet die eine ganze Spalte Schriftgröße, also
  /// genau die, die die fünf Unterrichtstage brauchen.
  List<DateTime> get _weekDays => <DateTime>[
        // Ebenfalls Kalendertage – siehe [_shiftWeek].
        for (int i = 0; i < 5; i++) addSchoolDays(_weekStart, i),
      ];

  /// Das Ende der Schulwoche: der Freitag.
  ///
  /// **Nur** [_weekStart] + 4 Tage, kein zweites Nachrechnen aus dem Datum.
  /// [_weekStart] ist bereits der Montag (siehe [_startOfWeek]); ein erneutes
  /// Nachrechnen war überflüssig und war die Fehlerquelle hinter einer
  /// Datumsrange wie „25.10. - 24.10.“, bei der das Ende vor dem Anfang lag.
  DateTime get _weekEnd => addSchoolDays(_weekStart, 4);

  bool get _isPerson => widget.person != null;

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) => _loadWeek());
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? customName = await _vplanAPI.getClassName(widget.classId);
    if (!mounted) return;
    setState(() {
      hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
      hideTeacher =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideTeacher')) ?? false;
      className = customName;
    });
    try {
      hiddenSubjects = await _vplanAPI.getHiddenCourses(widget.classId);
    } catch (_) {
      hiddenSubjects = <String>[];
    }
  }

  /// Lädt alle Tage der angezeigten Woche. Die Tage werden nebeneinander
  /// geholt – fünf einzelne Abfragen hintereinander würden spürbar dauern.
  ///
  /// **Der Ladezustand wird in jedem Fall wieder freigegeben** (`finally`),
  /// und zwar auch dann, wenn etwas schiefgeht. Vorher stand am Anfang
  /// `if (_refreshing) return;`, und ein Fehler irgendwo in der Ladeliste ließ
  /// `_refreshing` für immer auf `true` stehen: Jedes weitere [_shiftWeek] – und
  /// damit jeder Klick auf die Pfeile – wurde dann stillschweigend verworfen,
  /// die Seite blieb in der alten Woche stehen und wirkte wie eine klemmende
  /// Taste.
  ///
  /// [_loadGeneration] entscheidet bei überlappenden Ladevorgängen, wer gewinnt:
  /// Wer zuletzt navigiert hat. Ohne das könnte eine langsame Antwort der
  /// vorherigen Woche das Ergebnis der neuen überschreiben.
  Future<void> _loadWeek({bool forceRefresh = false}) async {
    final int generation = ++_loadGeneration;
    setState(() => _refreshing = true);

    try {
      final List<DateTime> days = _weekDays;
      final List<dynamic> plans = await Future.wait(
        days.map(
          (DateTime d) => _vplanAPI.getLessonsByDate(
            date: d,
            classId: widget.classId,
            forceRefresh: forceRefresh,
            // `strictDate`: Für einen Tag, für den die Schule nichts
            // veröffentlicht hat, darf nicht der neueste Plan eines anderen
            // Tages eingesetzt werden – sonst stünde derselbe Tag fünfmal in
            // der Woche.
            strictDate: true,
          ),
        ),
      );

      final Map<String, dynamic> byDay = <String, dynamic>{};
      final Map<String, dynamic> errors = <String, dynamic>{};
      for (int i = 0; i < days.length; i++) {
        final dynamic plan = plans[i];
        if (plan is Map && plan['error'] != null) {
          errors[_key(days[i])] = plan['error'];
        } else if (plan is Map && plan['data'] is List) {
          if ((plan['data'] as List).isNotEmpty) byDay[_key(days[i])] = plan;
        }
      }

      final Map<String, _DayMissedCourses> missed =
          await _loadMissedCourses(days);

      // Zwischenzeitlich wurde weiternavigiert: dieses Ergebnis ist veraltet.
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _days = byDay;
        _errors = errors;
        _missedCourses = missed;
        _loading = false;
      });
    } catch (_) {
      // Ladefehler: Die Seite darf nicht hängen bleiben. Die Woche wechselt
      // trotzdem, sie zeigt dann eben keine Pläne.
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _refreshing = false);
      }
    }
  }

  /// Lädt die noch einzuholenden Unterschriften für jeden Tag der Woche. Ein
  /// Fehler darf die Wochenansicht nicht verhindern – dann fehlen nur die
  /// Stiftsymbole.
  Future<Map<String, _DayMissedCourses>> _loadMissedCourses(
    List<DateTime> days,
  ) async {
    final Map<String, _DayMissedCourses> result = <String, _DayMissedCourses>{};
    for (final DateTime day in days) {
      try {
        final _DayMissedCourses details =
            await _vplanAPI.getMissedCourseDetailsForDate(
          widget.classId,
          day,
        );
        if (details.isNotEmpty) result[_key(day)] = details;
      } catch (_) {
        // Tag ohne Unterschriften anzeigen.
      }
    }
    return result;
  }

  /// Springt zur **nächsten Woche mit einem Plan** – vorwärts oder rückwärts.
  ///
  /// Statt einfach sieben Tage weiterzugehen, wird wie in der Tagesansicht
  /// ([Plan.newVP]) nach dem nächsten Tag mit einem Vertretungsplan gesucht und
  /// dann dessen Woche angezeigt. Ohne das müsste man Ferien- und leere Wochen
  /// einzeln überspringen, um überhaupt wieder eine Woche mit Unterricht zu
  /// sehen.
  ///
  /// `direction` ist +1 für vorwärts und −1 für rückwärts.
  Future<void> _shiftWeek(int direction) async {
    final bool forward = direction > 0;
    setState(() => _loading = true);

    // **Suchbeginn ist der Sonntag vor dem Montag der Zielwoche.**
    // [VPlanAPI.getNearestAvailablePlan] beginnt seine Suche bei
    // `from ± 1 Tag` – ohne diesen Sonntag würde der Montag der Zielwoche
    // übersprungen und gegebenenfalls eine ganze Woche mit Plan verpasst.
    final DateTime searchFrom =
        addSchoolDays(_weekStart, forward ? 6 : -6);

    DateTime? target;
    try {
      final dynamic plan = await _vplanAPI.getNearestAvailablePlan(
        from: searchFrom,
        classId: widget.classId,
        forward: forward,
      );
      if (plan is Map && plan['date'] != null) {
        target = _startOfWeek(
          _vplanAPI.parseStringDatatoDateTime(plan['date'].toString()),
        );
      }
    } catch (_) {
      // Suche fehlgeschlagen: Es wird schlicht eine Woche weitergesprungen.
    }

    // Nichts gefunden (kein Netz, oder im Suchfenster ist nichts): eine Woche
    // weitergehen, damit der Nutzer nicht auf einem Klick hängen bleibt.
    if (target == null) {
      // **Kalendertage, keine Dauer:** `add(Duration(days: 7))` addiert
      // absolute Stunden und landet über eine Zeitumstellung hinweg eine Stunde
      // zu früh – aus dem Montag wurde der Sonntag derselben Woche, und
      // [_startOfWeek] rechnete daraus wieder den Montag derselben Woche
      // zurück. Die Woche bewegte sich dann nicht mehr.
      target = _startOfWeek(addSchoolDays(_weekStart, 7 * direction));
    }

    // Die gefundene Woche ist dieselbe, in der man schon ist (z.B. weil die
    // Suche nichts Besseres fand): dann trotzdem weiterspringen.
    if (target == _weekStart) {
      target = _startOfWeek(addSchoolDays(_weekStart, 7 * direction));
    }

    // `target` ist oben in beiden Zweigen gefüllt.
    setState(() => _weekStart = target!);
    await _loadWeek();
  }

  Future<void> _refresh() => _loadWeek(forceRefresh: true);

  /// Der Wochentyp (A/B) – **immer** aus einem der Tagespläne des Servers.
  /// Er wird nie aus dem Datum berechnet.
  String get _weekType {
    for (final DateTime day in _weekDays) {
      final dynamic plan = _days[_key(day)];
      if (plan is Map) {
        final String week = plan['week']?.toString().trim() ?? '';
        if (week.isNotEmpty) return planWeekLabel(week);
      }
    }
    return '---';
  }

  /// „A-Woche"/„B-Woche", bzw. der Rohwert des Servers (z.B. eine
  /// Kalenderwochen-Zahl), wenn er sich keiner der beiden zuordnen lässt.
  String _weekTypeLabel(AppLocalizations l10n) {
    switch (_weekType) {
      case 'A':
        return l10n.weekTypeA;
      case 'B':
        return l10n.weekTypeB;
      default:
        return _weekType;
    }
  }

  bool _isLessonVisible(dynamic lesson) {
    if (_isPerson) {
      final List<dynamic>? shown = widget.person!['courses'] as List<dynamic>?;
      // Solange eine Person keine Kurse ausgewählt hat, gilt dasselbe wie
      // bei einer Klasse: Es werden alle nicht ausgeblendeten Kurse gezeigt.
      final List<String> personCourses =
          shown?.map((c) => c.toString()).toList() ?? <String>[];
      return _vplanAPI.isLessonVisibleForPerson(
        lesson,
        personCourses,
        hiddenSubjects,
      );
    }
    return !_vplanAPI.isLessonHidden(lesson, hiddenSubjects);
  }

  /// Fragt nach, ob die Unterschrift(en) für einen Kurs als erledigt markiert
  /// werden sollen – wie in der Tagesansicht.
  Future<void> _askMarkSignatureDone(String course, DateTime day) async {
    final details = _missedCourses[_key(day)]?[course];
    if (details == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Center(child: Text(l10n.markSignatureDone)),
        titlePadding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        contentPadding: const EdgeInsets.all(15),
        actionsPadding: const EdgeInsets.all(0),
        content: Text(
          l10n.signatureDoneQuestion(course),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final entryId in (details['entryIds'] as List)) {
      await _vplanAPI.markSignatureDone(entryId.toString(), course);
    }
    final _DayMissedCourses updated =
        await _vplanAPI.getMissedCourseDetailsForDate(widget.classId, day);
    if (!mounted) return;
    setState(() => _missedCourses[_key(day)] = updated);
  }

  /// Der Zeitraum der angezeigten Woche: „01.01. - 07.01.“.
///
/// **Ohne Jahreszahl** – die Woche steht ohnehin im Kopf der Seite, und die
/// Jahreszahl wäre bei sechs Spalten der teuerste Text der ganzen Ansicht. Nur
/// wenn die Woche über den Jahreswechsel liegt (30.12. - 05.01.), steht die
/// Jahreszahl doch dabei – sonst wäre nicht erkennbar, welches Jahr gemeint
/// ist.
String _rangeLabel() {
  final bool sameYear = _weekStart.year == _weekEnd.year;
  final String pattern = sameYear ? 'dd.MM.' : 'dd.MM.yyyy';
  return '${DateFormat(pattern).format(_weekStart)} - '
      '${DateFormat(pattern).format(_weekEnd)}';
}

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String headerTitle =
        widget.person?['name']?.toString() ?? (className ?? widget.classId);

    return ListPage(
      // Nur der Name in der Kopfzeile: Der Zeitraum steht in der schmalen Zeile
      // darüber beim Raster. So bleibt eine ganze Zeile für die Stunden frei –
      // bei sechs Spalten ist vertikaler Platz genauso knapp wie horizontaler.
      title: headerTitle,
      smallTitle: true,
      // Kein Scrollen (bis zur neunten Zeile): Das Grid soll die ganze Woche auf
      // einmal zeigen. Die Kopfzeile wird deshalb auch nicht eingeklappt – es
      // gibt nichts, was eingeklappt werden könnte.
      fillHeight: true,
      collapseHeaderOnScroll: false,
      // Knappere Kopfzeile: Der Vorgabe sind 10 % der Bildschirmhöhe, die der
      // Name und die drei Knöpfe gar nicht brauchen. Der Leerraum kommt
      // stattdessen dem Raster zugute – bzw. der angedeuteten neunten Stunde.
      headerHeightFactor: 0.085,
      // Der Vorgabe (20 Pixel links und rechts) nimmt dem Raster eine halbe
      // Spalte weg. Hier zählt jedes Pixel, also möglichst wenig Rand.
      contentPadding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      actions: [
        // Die Kurse, die angezeigt werden, lassen sich auch in der
        // Wochenansicht auswählen – derselbe Knopf wie in der Tagesansicht.
        IconButton(
          onPressed: () => Navigator.push(
            context,
            SwipePageTransition(
              type: PageTransitionType.rightToLeft,
              child: _isPerson
                  ? PersonCourses(
                      classId: widget.classId,
                      person: widget.person!,
                      isNew: false,
                      onSaved: (List<String> courses) {
                        setState(() => widget.person!['courses'] = courses);
                        _loadWeek();
                      },
                    )
                  : Courses(
                      classId: widget.classId,
                      updateCourses: () => _loadWeek(),
                    ),
            ),
          ),
          icon: Icon(Icons.settings_rounded, size: 20),
        ),
        IconButton(
          onPressed: _refreshing ? null : _refresh,
          icon: Icon(Icons.refresh, size: 20),
        ),
        IconButton(
          onPressed: () => _shiftWeek(-1),
          icon: Icon(Icons.arrow_back),
        ),
        IconButton(
          onPressed: () => _shiftWeek(1),
          icon: Icon(Icons.arrow_forward),
        ),
      ],
      children: [
        // **Ein** Ladesymbol für alles: Vorher standen hier zwei (eines über
        // dem Inhalt für [_refreshing], eines mittig für [_loading]), und beim
        // Laden standen beide gleichzeitig nebeneinander.
        ..._loadingWidget(),
        _weekTypeTile(l10n),
        // Beim Laden wird nichts weiter angezeigt – das Symbol ist die Meldung.
        if (_loading)
          const SizedBox.shrink()
        else if (_days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Text(
                _hasConnectionError()
                    ? l10n.noInternetConnection
                    : l10n.noPlanForThisWeek,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).focusColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          )
        else
          Expanded(child: _buildGrid()),
      ],
    );
  }

  /// Die „Zusatzinformationen" eines Tages als Liste von Textzeilen.
  ///
  /// Die API liefert sie je nach Anbieter mal als Liste, mal als leeren String
  /// – beides wird hier zu einer sauberen Liste normalisiert, damit im Dialog
  /// nichts Unlesbares steht.
  static List<dynamic> _infoOfDay(dynamic plan) {
    final dynamic info = plan is Map ? plan['info'] : null;
    if (info is List) return info;
    final String text = info?.toString().trim() ?? '';
    if (text.isEmpty || text == '[]') return const <dynamic>[];
    return <dynamic>[text];
  }

  /// Das Wochenraster. Die Tage stehen nebeneinander, die Stundenzeilen
  /// darunter – ohne Scrollen, die Höhe wird auf den Bildschirm aufgeteilt.
  Widget _buildGrid() {
    // **Jeder Tag der Woche bekommt eine Spalte** – auch Tage, für die die
    // Schule noch keinen Plan veröffentlicht hat. Früher wurden solche Tage
    // weggelassen, und wenn an einem einzigen Tag ein Plan vorlag, stand
    // da plötzlich eine einzige Spalte statt der Woche: Man konnte nicht mehr
    // erkennen, wo in der Woche man sich befindet. Der leere Tag ist die
    // Information „hier ist noch nichts".
    final List<WeekDayColumn> columns = <WeekDayColumn>[
      for (final DateTime day in _weekDays)
        WeekDayColumn(
          date: day,
          // Kein Plan für diesen Tag: Die Spalte bleibt leer.
          lessons: (_days[_key(day)]?['data'] as List<dynamic>? ?? const [])
              .where(_isLessonVisible)
              .toList(),
          missedCourses: _missedCourses[_key(day)] ?? const {},
          // Die „Zusatzinformationen" des Tages: In der Tagesansicht stehen
          // sie unter den Stunden, hier öffnet der Tageskopf sie.
          info: _infoOfDay(_days[_key(day)]),
        ),
    ];

    return WeekPlanGrid(
      days: columns,
      hideLessonTimes: hideLessonTimes,
      hideTeacher: hideTeacher,
      onSignatureTap: _askMarkSignatureDone,
    );
  }

  /// Eine schmale Zeile über dem Raster: der Zeitraum der Woche und – wenn
  /// geladen – der Wochentyp (A/B), der sich im Laufe der Woche nicht ändert.
  ///
  /// Bewusst eine Zeile und keine Karte: Das Grid soll die volle
  /// Bildschirmhöhe bekommen, und jedes zusätzliche Element nähme davon Platz
  /// weg, den die Stunden brauchen.
  Widget _weekTypeTile(AppLocalizations l10n) {
    final bool showType = !_loading && _days.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      // Mittig: Die Zeile gehört zum Raster darunter, dessen Spalten mittig
      // ausgerichtet sind – linksbündig würde sie quer dazu wirken.
      child: Align(
        alignment: Alignment.center,
        // `scaleDown`: Auf einem schmalen Telefon ist die Zeile (Zeitraum plus
        // Wochentyp) breiter als der Bildschirm. Ohne das lief sie über – und
        // die Kopfzeile ist die einzige Zeile, die nicht skalieren darf, weil
        // sie sonst nicht mehr lesbar wäre.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 15,
                color: Theme.of(context).focusColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text(
                _rangeLabel(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).focusColor.withValues(alpha: 0.85),
                ),
              ),
              if (showType) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.repeat_rounded,
                  size: 15,
                  color: Theme.of(context).focusColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  _weekTypeLabel(l10n),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Das Lade-Symbol der Woche – **ein einziges**, und es erscheint bei jedem
  /// Laden: beim Öffnen, beim Wechsel der Woche und beim Aktualisieren.
  ///
  /// [_loading] und [_refreshing] werden hier bewusst zusammengefasst. Vorher
  /// standen zwei Symbole nebeneinander, weil je ein Zustand sein eigenes
  /// zeigte und beide während des Ladens aktiv waren.
  List<Widget> _loadingWidget() {
    if (!_loading && !_refreshing) return const <Widget>[];
    return const <Widget>[LoadingIndicatorBlock()];
  }

  /// True, wenn mindestens ein Tag der Woche an einem Verbindungsfehler
  /// scheiterte – dann ist „kein Plan vorhanden“ die falsche Meldung.
  bool _hasConnectionError() =>
      _errors.values.any((dynamic e) => _vplanAPI.isConnectionError(e));
}