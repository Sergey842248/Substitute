import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Formatiert ein Datum als deutschen Datumsstring, wie ihn der
/// stundenplan24-Vertretungsplan liefert (z.B. "Dienstag, 18. August 2026").
String germanDate(DateTime date) {
  const weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  const months = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]} ${date.year}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String todayString = germanDate(DateTime.now());

  // Fake plan matching the Indiware xml2json Parker format
  final String fakePlanJson = jsonEncode({
    'date': todayString,
    'week': 'A',
    'data': {
      'Kopf': {'DatumPlan': todayString},
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
                  'Ra': 'H1 102',
                  'Beginn': '08:35',
                  'Ende': '09:20',
                  'Ku2': 'E-2',
                },
              ]
            }
          },
          {
            'Kurz': '10B',
            'Pl': {
              'Std': [
                {
                  'St': '3',
                  'Fa': 'PH',
                  'Le': 'EF',
                  'Ra': '101',
                  'Beginn': '09:25',
                  'Ende': '10:10',
                  'Ku2': 'PH-2',
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

  group('getRawPlanByDate', () {
    test('returns today plan from offline data without network', () async {
      final plan = await VPlanAPI().getRawPlanByDate(DateTime.now());
      expect(plan, isNotNull);
      expect(plan['error'], isNull);
      expect(plan['date'], todayString);
      expect(plan['data']['Klassen']['Kl'], isNotEmpty);
    });

    test('plan exposes lessons per class with room, subject and time',
        () async {
      final plan = await VPlanAPI().getRawPlanByDate(DateTime.now());
      final classes = plan['data']['Klassen']['Kl'] as List;

      // Raum 101: 1. Stunde M (10A) und 3. Stunde PH (10B)
      final Map<String, List<Map<String, String>>> rooms = {};
      for (var klasse in classes) {
        for (var lesson in klasse['Pl']['Std']) {
          final room = (lesson['Ra'] as String)
              .replaceAll('H1', '')
              .replaceAll('H2', '')
              .replaceAll('H3', '')
              .replaceAll('E', '')
              .trim();
          rooms.putIfAbsent(room, () => []).add({
            'count': lesson['St'].toString(),
            'lesson': lesson['Fa'].toString(),
            'class': klasse['Kurz'].toString(),
            'begin': lesson['Beginn'].toString(),
            'end': lesson['Ende'].toString(),
          });
        }
      }

      expect(rooms.keys, containsAll(['101', '102']));
      expect(rooms['101'], hasLength(2));
      expect(rooms['101']![0]['class'], '10A');
      expect(rooms['101']![0]['lesson'], 'M');
      expect(rooms['101']![0]['begin'], '07:45');
      expect(rooms['101']![1]['class'], '10B');
      expect(rooms['102']![0]['lesson'], 'E');
    });
  });

  group('date helpers', () {
    test('parseStringDatatoDateTime parses today German date', () {
      final parsed = VPlanAPI().parseStringDatatoDateTime(todayString);
      expect(parsed.year, DateTime.now().year);
      expect(parsed.month, DateTime.now().month);
      expect(parsed.day, DateTime.now().day);
    });

    test('compareDate matches same day', () {
      expect(VPlanAPI().compareDate(DateTime.now(), todayString), isTrue);
    });

    test('compareDate rejects a different day', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(VPlanAPI().compareDate(tomorrow, todayString), isFalse);
    });
  });
}
