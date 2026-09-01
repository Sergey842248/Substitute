import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String fridayDate = 'Freitag, 14. August 2026';
  final String saturdayDate = 'Samstag, 15. August 2026';

  // Fake plan matching the Indiware xml2json Parker format.
  Map<String, dynamic> planFor(String date) => {
        'date': date,
        'week': 'A',
        'data': {
          'Kopf': {'DatumPlan': date},
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
      };

  Future<dynamic> loadFriday() => VPlanAPI().getVPlanJSON(
        Uri.parse(
            'https://www.stundenplan24.de/123456/mobil/mobdaten/PlanKl20260814.xml'),
        DateTime(2026, 8, 14),
      );

  group('TTL plan cache respects the plan date', () {
    test('uses the cache when the cached plan belongs to the requested day',
        () async {
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': <String>[],
        'vplan_cache_2026-08-14': jsonEncode(planFor(fridayDate)),
        'vplan_cache_2026-08-14_time':
            DateTime.now().millisecondsSinceEpoch - 1000,
      });

      final result = await loadFriday();

      expect(result, isA<Map>());
      expect(result['date'], fridayDate);
      expect(result['error'], isNull);
    });

    test('ignores a cached plan that belongs to another day (new plan case)',
        () async {
      // Die Schule hat den Plan für Samstag bereits veröffentlicht und die
      // 'Klassen.xml' liefert ihn schon – dadurch lag der Samstags-Plan
      // fälschlich unter dem Cache-Schlüssel von Freitag. Die Navigation
      // zurück auf Freitag darf diesen Eintrag NICHT verwenden, sonst bliebe
      // der Plan auf dem neuen Tag „hängen" (Button reagiert nicht).
      SharedPreferences.setMockInitialValues({
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': <String>[],
        'vplan_cache_2026-08-14': jsonEncode(planFor(saturdayDate)),
        'vplan_cache_2026-08-14_time':
            DateTime.now().millisecondsSinceEpoch - 1000,
      });

      final result = await loadFriday();

      // Der falsch datierte Cache-Eintrag darf nicht zurückkommen.
      expect(result['date'], isNot(saturdayDate));
    });
  });
}
