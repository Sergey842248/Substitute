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
    test('returns courses for matching date and class', () async {
      await VPlanAPI().addSickTrackEntry({
        'id': '1',
        'classId': '10A',
        'courses': ['M-1', 'E-2'],
        'days': ['2026-08-15'],
      });
      final courses =
          await VPlanAPI().getMissedCoursesForDate('10A', DateTime(2026, 8, 15));
      expect(courses, containsAll(['M-1', 'E-2']));
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
  });

  group('isoDate', () {
    test('formats date with zero-padded month and day', () {
      expect(VPlanAPI().isoDate(DateTime(2026, 8, 5)), '2026-08-05');
    });

    test('formats date with two-digit month', () {
      expect(VPlanAPI().isoDate(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });
}
