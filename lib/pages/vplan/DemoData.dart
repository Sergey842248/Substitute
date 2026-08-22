import 'dart:math';

/// Generates consistent mock data for the demo mode.
/// When credentials (123456 / user / password) are used, all network calls
/// are replaced by this deterministic fake data so every submenu works
/// without hitting the real API.
class DemoData {
  // ── Teachers ──────────────────────────────────────────────────────────
  static const Map<String, String> _teacherNames = {
    'MUE': 'Herr Müller',
    'SCH': 'Frau Schmidt',
    'KRU': 'Herr Krause',
    'WEB': 'Frau Weber',
    'FIS': 'Herr Fischer',
    'BEC': 'Herr Becker',
    'HOF': 'Frau Hoffmann',
    'LAN': 'Herr Lange',
    'KOE': 'Frau König',
    'BAU': 'Herr Bauer',
    'SCU': 'Frau Schulz',
    'RIC': 'Herr Richter',
  };

  static List<String> get teacherShorts => _teacherNames.keys.toList();

  static String? teacherName(String short) => _teacherNames[short];

  // ── Rooms ─────────────────────────────────────────────────────────────
  static const List<String> rooms = [
    '101', '102', '103',
    '201', '202', '203',
    '301', '302', '303',
    '401', '402',
    'SH1',
  ];

  // ── Classes ───────────────────────────────────────────────────────────
  static const List<String> classes = ['5a', '7b', '9c', '10a', '12m'];

  // ── Courses per class (subject → teacher short) ───────────────────────
  static const Map<String, Map<String, String>> _classCourses = {
    '5a': {
      'M': 'MUE',
      'D': 'SCH',
      'E': 'KRU',
      'BIO': 'WEB',
      'SP': 'BAU',
      'MU': 'KOE',
    },
    '7b': {
      'D': 'SCH',
      'M': 'MUE',
      'E': 'KRU',
      'BIO': 'WEB',
      'GE': 'HOF',
      'SP': 'BAU',
    },
    '9c': {
      'M': 'MUE',
      'E': 'KRU',
      'D': 'SCH',
      'BIO': 'WEB',
      'PH': 'BEC',
      'SP': 'BAU',
    },
    '10a': {
      'BIO': 'WEB',
      'E': 'KRU',
      'D': 'SCH',
      'M': 'MUE',
      'KU': 'LAN',
      'CH': 'FIS',
    },
    '12m': {
      'CH': 'FIS',
      'PH': 'BEC',
      'GE': 'HOF',
      'MU': 'KOE',
      'IF': 'RIC',
      'KU': 'LAN',
    },
  };

  /// Period start/end times (6 periods per day).
  static const List<Map<String, String>> _periods = [
    {'St': '1', 'Beginn': '08:00', 'Ende': '08:45'},
    {'St': '2', 'Beginn': '08:50', 'Ende': '09:35'},
    {'St': '3', 'Beginn': '09:55', 'Ende': '10:40'},
    {'St': '4', 'Beginn': '10:45', 'Ende': '11:30'},
    {'St': '5', 'Beginn': '11:50', 'Ende': '12:35'},
    {'St': '6', 'Beginn': '12:40', 'Ende': '13:25'},
  ];

  // ── Weekly schedule ───────────────────────────────────────────────────
  // For each class, a list of (subject, teacherShort, room) per period
  // index (0-5) for each day (Monday=0 … Friday=4). Built so the same
  // teacher never appears twice in the same period across different classes.

  static final Map<String, List<List<Map<String, String>>>> _schedule =
      _buildSchedule();

  static Map<String, List<List<Map<String, String>>>> _buildSchedule() {
    const nDays = 5;
    const nPer = 6;

    // Build Random per day for reproducibility
    final rngs = <int, Random>{};
    for (int d = 0; d < nDays; d++) {
      rngs[d] = Random(d * 7 + 13);
    }

    final result = <String, List<List<Map<String, String>>>>{};

    for (final c in classes) {
      final subj = _classCourses[c]!.keys.toList();
      final classPlan = <List<Map<String, String>>>[];

      for (int d = 0; d < nDays; d++) {
        final rng = rngs[d]!;

        // Shuffle subject indices deterministically
        final perm = List<int>.generate(nPer, (i) => i % subj.length);
        _deterministicShuffle(perm, rng.nextDouble());

        // Shuffle room pool
        final roomPool = List<String>.from(rooms);
        _deterministicShuffle(roomPool, rng.nextDouble());

        final dayPlan = <Map<String, String>>[];
        final usedRooms = <String>{};

        for (int p = 0; p < nPer; p++) {
          final subject = subj[perm[p]];
          final teacher = _classCourses[c]![subject]!;
          String room = roomPool[p % roomPool.length];
          while (usedRooms.contains(room)) {
            room = roomPool[(p + usedRooms.length) % roomPool.length];
          }
          usedRooms.add(room);

          dayPlan.add({
            'subject': subject,
            'teacherShort': teacher,
            'room': room,
          });
        }
        classPlan.add(dayPlan);
      }
      result[c] = classPlan;
    }

    // ── Resolve teacher collisions ──────────────────────────────────────
    for (int d = 0; d < nDays; d++) {
      for (int p = 0; p < nPer; p++) {
        final usedTeachers = <String, String>{}; // teacher → class
        final conflicts = <String>{};

        for (final c in classes) {
          final t = result[c]![d][p]['teacherShort']!;
          if (usedTeachers.containsKey(t)) {
            conflicts.add(c);
            conflicts.add(usedTeachers[t]!);
          } else {
            usedTeachers[t] = c;
          }
        }

        for (final c in conflicts) {
          for (int p2 = 0; p2 < nPer; p2++) {
            if (p2 == p) continue;
            final t2 = result[c]![d][p2]['teacherShort']!;
            if (!usedTeachers.containsKey(t2) ||
                usedTeachers[t2] == c) {
              final tmp = result[c]![d][p];
              result[c]![d][p] = result[c]![d][p2];
              result[c]![d][p2] = tmp;
              usedTeachers.remove(tmp['teacherShort']);
              usedTeachers[result[c]![d][p]['teacherShort']!] = c;
              break;
            }
          }
        }
      }
    }

    return result;
  }

  static void _deterministicShuffle(List list, double seed) {
    final r = Random((seed * 1000000).toInt());
    for (int i = list.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Returns the day-of-week index (0=Monday … 6=Sunday).
  static int _dowIndex(DateTime date) => date.weekday - 1;

  /// Returns true if `date` is a Saturday or Sunday.
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  // ── Course list for a class ───────────────────────────────────────────
  static List<Map<String, dynamic>> getCourses(String classId) {
    final courses = _classCourses[classId];
    if (courses == null) return [];
    return courses.entries.map((e) => {
      'classId': classId,
      'course': e.key,
      'teacher': e.value,
    }).toList();
  }

  // ── German weekday name ───────────────────────────────────────────────
  static String _germanWeekday(int dow) {
    const days = [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag',
      'Samstag', 'Sonntag',
    ];
    return days[dow];
  }

  static const List<String> _months = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  /// German-formatted date string matching the real API format:
  /// "Montag, 22. August 2025" (spelled-out month, separated by spaces).
  /// This is required so VPlanAPI.parseStringDatatoDateTime can parse it.
  static String germanDate(DateTime date) {
    final d = date.day.toString();
    final m = _months[date.month - 1];
    final y = date.year.toString();
    return '${_germanWeekday(date.weekday - 1)}, $d. $m $y';
  }

  // ── Full VPlan for a day (used by getVPlanJSON / getRawPlanByDate) ───
  static Map<String, dynamic> buildDayPlan(DateTime date) {
    final dow = _dowIndex(date);
    final dayIdx = dow; // Monday=0 … Friday=4
    final dateStr = germanDate(date);

    final klassenList = <Map<String, dynamic>>[];
    final allCourses = <Map<String, dynamic>>[];
    final roomChanges = <String, Map<String, bool>>{};

    for (final cls in classes) {
      final classPlan = _schedule[cls]![dayIdx % 5];
      final stdList = <Map<String, dynamic>>[];
      final coursesForClass = <Map<String, dynamic>>[];

      for (int p = 0; p < classPlan.length; p++) {
        final entry = classPlan[p];
        final period = _periods[p];
        final info = _randomInfo(date, cls, p);

        stdList.add({
          'St': period['St'],
          'Fa': entry['subject'],
          'Le': entry['teacherShort'],
          'Ra': entry['room'],
          'Beginn': period['Beginn'],
          'Ende': period['Ende'],
          'If': info,
          'Ku2': entry['subject'],
        });

        coursesForClass.add({
          'KKz': entry['subject'],
          '\$': entry['teacherShort'],
        });
      }

      final rc = <String, bool>{};
      for (int p = 0; p < classPlan.length; p++) {
        rc[_periods[p]['St']!] = false;
      }
      roomChanges[cls] = rc;

      klassenList.add({
        'Kurz': cls,
        'Kurse': {'Ku': coursesForClass},
        'Pl': {'Std': stdList},
      });

      for (final c in coursesForClass) {
        allCourses.add({
          'classId': cls,
          'course': c['KKz'],
          'teacher': c['\$'],
        });
      }
    }

    return {
      'date': dateStr,
      'week': _weekNumber(date).toString(),
      'data': {
        'Kopf': {
          'DatumPlan': dateStr,
          'Woche': _weekNumber(date).toString(),
        },
        'Klassen': {'Kl': klassenList},
        'ZusatzInfo': {
          'ZiZeile': [
            {'#text': 'Demo-Modus – Keine realen Daten.'},
            {'#text': 'Schulnummer: 123456 | Benutzer: user'},
          ],
        },
      },
      'info': [
        'Demo-Modus – Keine realen Daten.',
        'Schulnummer: 123456 | Benutzer: user',
      ],
      'courses': allCourses,
      'roomChanges': roomChanges,
    };
  }

  /// Structured, empty plan for days without lessons (e.g. weekends).
  /// Keeps the same shape as [buildDayPlan] so consumers that rely on the
  /// 'data'/'Klassen'/'Kl' structure never crash on an empty map.
  static Map<String, dynamic> buildEmptyDayPlan(DateTime date) {
    final dateStr = germanDate(date);
    final week = _weekNumber(date).toString();
    return {
      'date': dateStr,
      'week': week,
      'data': {
        'Kopf': {
          'DatumPlan': dateStr,
          'Woche': week,
        },
        'Klassen': {'Kl': []},
        'ZusatzInfo': {
          'ZiZeile': [
            {'#text': 'Demo-Modus – Keine realen Daten.'},
            {'#text': 'Wochenende – kein Vertretungsplan.'},
          ],
        },
      },
      'info': [
        'Demo-Modus – Keine realen Daten.',
        'Wochenende – kein Vertretungsplan.',
      ],
      'courses': [],
      'roomChanges': {},
    };
  }

  static String? _randomInfo(DateTime date, String cls, int period) {
    final seed = (date.day + cls.hashCode + period * 3).abs();
    if (seed % 7 == 0) {
      const msgs = [
        'Vertretung',
        'Raumänderung',
        'Aufgaben siehe Moodle',
        'Filmvorführung',
      ];
      return msgs[seed % msgs.length];
    }
    return null;
  }

  /// ISO week number (simplified)
  static int _weekNumber(DateTime date) {
    // Simplified: day of year / 7, rounded up
    final start = DateTime(date.year, 1, 1);
    final diff = date.difference(start).inDays;
    return ((diff + start.weekday) / 7).floor() + 1;
  }

  /// Builds parsed lessons for a specific class + date (used by
  /// getLessonsForToday / getLessonsByDate).
  static Map<String, dynamic> buildClassLessons(
      String classId, DateTime date) {
    final plan = buildDayPlan(date);
    final dow = _dowIndex(date);

    final lessons = <Map<String, dynamic>>[];
    if (!_schedule.containsKey(classId)) {
      return {
        'date': plan['date'],
        'week': plan['week'],
        'data': lessons,
        'info': plan['info'],
      };
    }

    final classPlan = _schedule[classId]![dow % 5];
    for (int p = 0; p < classPlan.length; p++) {
      final entry = classPlan[p];
      final period = _periods[p];
      final info = _randomInfo(date, classId, p);

      lessons.add({
        'count': period['St'],
        'lesson': entry['subject'],
        'teacher': _teacherNames[entry['teacherShort']] ?? entry['teacherShort'],
        'place': entry['room'],
        'placeChanged': false,
        'begin': period['Beginn'],
        'end': period['Ende'],
        'info': info,
        'course': entry['subject'],
      });
    }

    return {
      'date': plan['date'],
      'week': plan['week'],
      'data': lessons,
      'info': plan['info'],
    };
  }
}