import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:expandiware/pages/vplan/VPlanAPI.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fake plan data matching the Indiware xml2json Parker format for class 10A
  final String fakePlanJson = jsonEncode({
    'date': 'Freitag, 15. August 2026',
    'week': 'A',
    'data': {
      'Kopf': {'DatumPlan': 'Freitag, 15. August 2026'},
      'Klassen': {
        'Kl': [
          {
            'Kurz': '10A',
            'Pl': {
              'Std': [
                {
                  'St': '1',
                  'Fa': 'M',
                  'Le': 'AB',
                  'Ra': '101',
                  'Beginn': '07:45',
                  'Ende': '08:30',
                  'Ku2': 'M-1',
                },
                {
                  'St': '2',
                  'Fa': 'E',
                  'Le': 'CD',
                  'Ra': '102',
                  'Beginn': '08:35',
                  'Ende': '09:20',
                  'Ku2': 'E-2',
                },
                {
                  'St': '4',
                  'Fa': 'M',
                  'Le': 'EF',
                  'Ra': '104',
                  'Beginn': '10:30',
                  'Ende': '11:15',
                  'Ku2': 'M-2',
                },
              ]
            }
          }
        ]
      }
    },
    'info': [],
    'courses': [],
    'roomChanges': {},
  });

  // Fake plan for the next school day (Monday 17.08.2026) with only M-1,
  // used to test that the signature icon appears at the *next* lesson after
  // the sick period.
  final String fakePlanMondayJson = jsonEncode({
    'date': 'Montag, 17. August 2026',
    'week': 'A',
    'data': {
      'Kopf': {'DatumPlan': 'Montag, 17. August 2026'},
      'Klassen': {
        'Kl': [
          {
            'Kurz': '10A',
            'Pl': {
              'Std': [
                {
                  'St': '1',
                  'Fa': 'M',
                  'Le': 'AB',
                  'Ra': '101',
                  'Beginn': '07:45',
                  'Ende': '08:30',
                  'Ku2': 'M-1',
                },
              ]
            }
          }
        ]
      }
    },
    'info': [],
    'courses': [],
    'roomChanges': {},
  });

  // Fake plan for Tuesday 18.08.2026 (again with M-1), used to test that a
  // later occurrence does NOT get the signature icon again.
  final String fakePlanTuesdayJson = jsonEncode({
    'date': 'Dienstag, 18. August 2026',
    'week': 'A',
    'data': {
      'Kopf': {'DatumPlan': 'Dienstag, 18. August 2026'},
      'Klassen': {
        'Kl': [
          {
            'Kurz': '10A',
            'Pl': {
              'Std': [
                {
                  'St': '2',
                  'Fa': 'M',
                  'Le': 'AB',
                  'Ra': '101',
                  'Beginn': '08:35',
                  'Ende': '09:20',
                  'Ku2': 'M-1',
                },
              ]
            }
          }
        ]
      }
    },
    'info': [],
    'courses': [],
    'roomChanges': {},
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'pass',
      'offlineVPData': [fakePlanJson],
    });
  });

  group('SickTrack storage', () {
    test('getSickTrackEntries returns empty when nothing stored', () async {
      final entries = await VPlanAPI().getSickTrackEntries();
      expect(entries, isEmpty);
    });

    test('add and retrieve sick track entry', () async {
      final entry = {
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      };
      await VPlanAPI().addSickTrackEntry(entry);
      final entries = await VPlanAPI().getSickTrackEntries();
      expect(entries.length, 1);
      expect(entries[0]['classId'], '10A');
      expect(entries[0]['days'], ['2026-08-15']);
    });

    test('delete sick track entry', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': 'del',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().deleteSickTrackEntry('del');
      expect(await VPlanAPI().getSickTrackEntries(), isEmpty);
    });
  });

  group('getMissedLessons', () {
    test('returns missed lessons for matching course', () async {
      final missed = await VPlanAPI().getMissedLessons({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      expect(missed.length, 1);
      expect(missed[0]['course'], 'M-1');
      expect(missed[0]['count'], '1');
      expect(missed[0]['date'], '2026-08-15');
    });

    test('returns multiple missed lessons sorted by period count', () async {
      final missed = await VPlanAPI().getMissedLessons({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1', 'M-2'],
        'days': ['2026-08-15'],
      });
      expect(missed.length, 2);
      expect(missed[0]['count'], '1');
      expect(missed[1]['count'], '4');
    });

    test('returns empty when no courses match', () async {
      final missed = await VPlanAPI().getMissedLessons({
        'id': '1',
        'classId': '10A',
        'courses': ['X'],
        'days': ['2026-08-15'],
      });
      expect(missed, isEmpty);
    });

    test('returns empty when class is not in the stored plan', () async {
      final missed = await VPlanAPI().getMissedLessons({
        'id': '1',
        'classId': '10B',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      expect(missed, isEmpty);
    });
  });

  group('getMissedCoursesForDate', () {
    test('returns courses with signature count for matching date and class',
        () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1', 'E-2'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 15));
      expect(courses.keys, containsAll(['M-1', 'E-2']));
      // Jede dieser Stunden kommt im Fake-Plan genau einmal vor.
      expect(courses['M-1'], 1);
      expect(courses['E-2'], 1);
    });

    test('counts multiple missed lessons of the same course', () async {
      // M-1 kommt am Krankheitstag zweimal vor (1. und 4. Stunde) → 2
      // Unterschriften nötig.
      final String doubleM1 = jsonEncode({
        'date': 'Freitag, 15. August 2026',
        'week': 'A',
        'data': {
          'Kopf': {'DatumPlan': 'Freitag, 15. August 2026'},
          'Klassen': {
            'Kl': [
              {
                'Kurz': '10A',
                'Pl': {
                  'Std': [
                    {
                      'St': '1',
                      'Fa': 'M',
                      'Le': 'AB',
                      'Ra': '101',
                      'Beginn': '07:45',
                      'Ende': '08:30',
                      'Ku2': 'M-1',
                    },
                    {
                      'St': '4',
                      'Fa': 'M',
                      'Le': 'AB',
                      'Ra': '104',
                      'Beginn': '10:30',
                      'Ende': '11:15',
                      'Ku2': 'M-1',
                    },
                  ]
                }
              }
            ]
          }
        },
        'info': [],
        'courses': [],
        'roomChanges': {},
      });
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': [doubleM1],
      });
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 15));
      expect(courses['M-1'], 2);
    });

    test('returns empty set for a different date', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 16));
      expect(courses, isEmpty);
    });

    test('returns empty set for a different class', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10B', DateTime(2026, 8, 15));
      expect(courses, isEmpty);
    });

    test('returns course at the next lesson after the sick period', () async {
      // Sick day is Saturday 15.08.2026 → next lesson is Monday 17.08.2026.
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': [fakePlanJson, fakePlanMondayJson],
      });
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 17));
      expect(courses.keys, contains('M-1'));
      expect(courses['M-1'], 1);
    });

    test('does not return a course again at a later occurrence', () async {
      // M-1 occurs on Monday 17.08.2026 and Tuesday 18.08.2026. The signature
      // icon must only appear at the *next* lesson (Monday), not on Tuesday.
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': [fakePlanJson, fakePlanMondayJson, fakePlanTuesdayJson],
      });
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 18));
      expect(courses, isEmpty);
    });
  });

  group('mark signature done', () {
    test('marks a course as done and hides its signature', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1', 'E-2'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().markSignatureDone('1', 'M-1');
      final courses = await VPlanAPI()
          .getMissedCoursesForDate('10A', DateTime(2026, 8, 15));
      expect(courses.keys, ['E-2']);
    });

    test('marking done only removes the signature of that entry', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().addSickTrackEntry({
        'id': '2',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().markSignatureDone('1', 'M-1');
      final courses = await VPlanAPI()
          .getMissedCoursesForDate('10A', DateTime(2026, 8, 15));
      // Der zweite Eintrag braucht weiterhin eine Unterschrift.
      expect(courses['M-1'], 1);
    });

    test('marking done removes the signature at the next lesson too',
        () async {
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': [fakePlanJson, fakePlanMondayJson],
      });
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().markSignatureDone('1', 'M-1');
      final courses = await VPlanAPI()
          .getMissedCoursesForDate('10A', DateTime(2026, 8, 17));
      expect(courses, isEmpty);
    });

    test('details contain entry ids for marking', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '7',
        'classId': '10A',
        'courses': ['M-1', 'E-2'],
        'days': ['2026-08-15'],
      });
      final details = await VPlanAPI()
          .getMissedCourseDetailsForDate('10A', DateTime(2026, 8, 15));
      expect(details.keys, containsAll(['M-1', 'E-2']));
      expect(details['M-1']!['count'], 1);
      expect(details['M-1']!['entryIds'], ['7']);
    });

    test('done signatures are stored per entry', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1'],
        'days': ['2026-08-15'],
      });
      await VPlanAPI().markSignatureDone('1', 'M-1');
      expect(await VPlanAPI().getDoneSignatures('1'), contains('M-1'));
      expect(await VPlanAPI().getDoneSignatures('2'), isEmpty);
    });
  });

  group('isoDate', () {
    test('formats date with zero-padded month and day', () {
      expect(VPlanAPI().isoDate(DateTime(2026, 8, 5)), '2026-08-05');
    });

    test('formats date with two-digit month', () {
      expect(VPlanAPI().isoDate(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });

  group('hidden courses per class', () {
    test('hiding a course only affects that class', () async {
      final api = VPlanAPI();
      await api.addHiddenCourse('11', 'M-2');
      expect(await api.getHiddenCourses('11'), ['M-2']);
      // Neu angelegte Klasse 12 startet ohne ausgeblendete Kurse
      expect(await api.getHiddenCourses('12'), isEmpty);
    });

    test('removing a hidden course works per class', () async {
      final api = VPlanAPI();
      await api.addHiddenCourse('11', 'M-2');
      await api.addHiddenCourse('12', 'E-1');
      await api.removeHiddenCourse('11', 'M-2');
      expect(await api.getHiddenCourses('11'), isEmpty);
      expect(await api.getHiddenCourses('12'), ['E-1']);
    });

    test('deleting a class resets its hidden courses', () async {
      final api = VPlanAPI();
      await api.addHiddenCourse('11', 'M-2');
      await api.addHiddenCourse('12', 'E-1');
      await api.removeHiddenCoursesForClass('11');
      expect(await api.getHiddenCourses('11'), isEmpty);
      // Andere Klassen bleiben unberührt
      expect(await api.getHiddenCourses('12'), ['E-1']);
    });

    test('migrates old global hidden list to existing classes once',
        () async {
      SharedPreferences.setMockInitialValues({
        'classes': ['11', '12'],
        'hiddenSubjects': ['M-2', 'E-1'],
      });
      final api = VPlanAPI();
      expect(await api.getHiddenCourses('11'), ['M-2', 'E-1']);
      expect(await api.getHiddenCourses('12'), ['M-2', 'E-1']);
      // Neue Klasse nach der Migration startet leer
      expect(await api.getHiddenCourses('13'), isEmpty);
      // Migration läuft nicht erneut: Abwählen in 13 bleibt pro Klasse
      await api.addHiddenCourse('13', 'D');
      expect(await api.getHiddenCourses('11'), ['M-2', 'E-1']);
    });
  });

  group('offline plan retention', () {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];

    // Builds a German date string (weekday is ignored by the parser).
    String germanDate(DateTime date) =>
        'Montag, ${date.day}. ${months[date.month - 1]} ${date.year}';

    String planForDate(DateTime date) => jsonEncode({
          'data': {
            'Kopf': {'DatumPlan': germanDate(date)},
          },
        });

    test('keeps plans from the last 14 days and prunes older ones', () async {
      final today = DateTime.now();
      final oldPlan = planForDate(today.subtract(const Duration(days: 15)));
      final recentPlan = planForDate(today.subtract(const Duration(days: 7)));
      final todayPlan = planForDate(today);
      SharedPreferences.setMockInitialValues({
        'offlineVPData': [oldPlan, recentPlan, todayPlan],
      });

      await VPlanAPI().cleanVplanOfflineData();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('offlineVPData')!;
      expect(stored.length, 2);
      final storedDates = stored
          .map((e) => jsonDecode(e)['data']['Kopf']['DatumPlan'])
          .toList();
      expect(storedDates, contains(germanDate(today.subtract(const Duration(days: 7)))));
      expect(storedDates, contains(germanDate(today)));
      expect(storedDates, isNot(contains(germanDate(today.subtract(const Duration(days: 15))))));
    });

    test('keeps plans exactly 14 days old and future plans', () async {
      final today = DateTime.now();
      final boundaryPlan = planForDate(today.subtract(const Duration(days: 14)));
      final futurePlan = planForDate(today.add(const Duration(days: 2)));
      SharedPreferences.setMockInitialValues({
        'offlineVPData': [boundaryPlan, futurePlan],
      });

      await VPlanAPI().cleanVplanOfflineData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('offlineVPData')!.length, 2);
    });

    test('still deduplicates plans by date during cleanup', () async {
      final today = DateTime.now();
      final plan = planForDate(today);
      SharedPreferences.setMockInitialValues({
        'offlineVPData': [plan, plan],
      });

      await VPlanAPI().cleanVplanOfflineData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('offlineVPData')!.length, 1);
    });
  });
}
