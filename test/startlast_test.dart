import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/AppClock.dart';

/// Der Start der App war langsam, weil **dieselbe Arbeit viele Male** gemacht
/// wurde. Diese Tests halten die drei Stellen fest, an denen sie jetzt
/// einmal stattfindet.
///
/// Der Hintergrund ist der gleiche immer wieder: Die `Klassen.xml` ist **ein**
/// Dokument für die **ganze Schule**, und die Startseite fragt es für jede
/// Klasse, jede Person und zusätzlich für die Hintergrunderneuerung an. Jede
/// dieser Anfragen war ein eigener Download, ein eigenes XML-Parsen und ein
/// eigenes Zurückschreiben desselben Plans in `SharedPreferences`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Ein Plan im Format, das die App selbst ablegt (`offlineVPData`).
  String offlinePlan(String datum) => jsonEncode(<String, dynamic>{
        'date': datum,
        'week': 'A',
        'data': {
          'Kopf': {'DatumPlan': datum},
          'Klassen': {
            'Kl': [
              {
                'Kurz': '8a',
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
                  ],
                },
              },
            ],
          },
        },
        'info': <String>[],
        'courses': <dynamic>[],
        'roomChanges': <String, dynamic>{},
      });

  group('Gleiche Plan-Anfragen', () {
    test('teilen sich eine einzige Ladung', () async {
      // Ohne Bündelung wären das zwei Downloads derselben URL gewesen – und
      // so, wie es vorher war, N Downloads bei N Klassen.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': <String>[offlinePlan('Freitag, 15. August 2026')],
      });
      await AppClock.setOverriddenNow(DateTime(2026, 8, 15, 8, 0));

      final Uri url =
          Uri.parse('https://www.stundenplan24.de/123456/mobil/mobdaten/'
              'Klassen.xml');
      final DateTime tag = DateTime(2026, 8, 15);

      final dynamic erster = await VPlanAPI().getVPlanJSON(url, tag);
      final dynamic zweiter = await VPlanAPI().getVPlanJSON(url, tag);

      expect(zweiter['date'], erster['date']);
      // **Und** der Eintrag ist nach der Ladung wieder weg: Ein stiller
      // Plan-Cache über die Ladung hinaus würde `forceRefresh` aushebeln –
      // ein erzwungener Neuladevorgang muss wirklich neu laden dürfen.
      expect(identical(zweiter, erster), isFalse,
          reason: 'jede Ladung liefert ihre eigene, frische Antwort');
    });

    test('zwei gleichzeitige Aufrufe ergeben eine einzige Ladung', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanSchoolnumber': '123456',
        'vplanUsername': 'user',
        'vplanPassword': 'pass',
        'offlineVPData': <String>[offlinePlan('Freitag, 15. August 2026')],
      });
      await AppClock.setOverriddenNow(DateTime(2026, 8, 15, 8, 0));

      final Uri url =
          Uri.parse('https://www.stundenplan24.de/123456/mobil/mobdaten/'
              'Klassen.xml');
      final DateTime tag = DateTime(2026, 8, 15);

      // Ohne `await` dazwischen: So starten beide wirklich gleichzeitig –
      // das ist der Fall, den die Startseite auslöst.
      final Future<dynamic> a = VPlanAPI().getVPlanJSON(url, tag);
      final Future<dynamic> b = VPlanAPI().getVPlanJSON(url, tag);

      expect(identical(await a, await b), isTrue,
          reason: 'zwei gleichzeitige Aufrufer, eine Ladung');
    });
  });

  group('Die Plan-Displays werden nicht mehr beim Start dekodiert', () {
    test('stehen danach trotzdem sofort zur Verfügung', () async {
      // Siehe `loadDisplayCache`: Beim Start wandert nur der **Rohtext** in
      // den Speicher. `cachedPlanDisplay` macht daraus beim ersten Zugriff
      // den Eintrag – deshalb darf hier nichts fehlen.
      final String plan = jsonEncode(<String, dynamic>{
        'date': 'Freitag, 15. August 2026',
        'week': 'A',
        'data': <String, dynamic>{'Kopf': <String, dynamic>{}},
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['8a', '8b'],
        'planDisplay_8a': plan,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await loadDisplayCache(prefs);

      final Map<String, dynamic>? geladen = cachedPlanDisplay('8a');
      expect(geladen, isNotNull);
      expect(geladen!['date'], 'Freitag, 15. August 2026');
      expect(cachedPlanDisplay('8b'), isNull,
          reason: 'für eine Klasse ohne Plan bleibt es null');

      // Und ein zweiter Zugriff ändert nichts daran.
      expect(identical(cachedPlanDisplay('8a'), geladen), isTrue);
    });
  });

  group('Die Meldung über den Hintergrund-Refresh', () {
    test('fasst mehrere Meldungen zu einer zusammen', () async {
      final int vorher = vplanBackgroundRefresh.value;

      notifyVPlanBackgroundRefresh();
      notifyVPlanBackgroundRefresh();
      notifyVPlanBackgroundRefresh();

      expect(vplanBackgroundRefresh.value, vorher,
          reason: 'das Fenster ist noch nicht abgelaufen');

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(vplanBackgroundRefresh.value, vorher + 1,
          reason: 'drei Meldungen, eine Benachrichtigung');
    });
  });
}