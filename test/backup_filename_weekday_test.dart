import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'package:substitute/pages/vplan/Plan.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/services/ConfigBackupFlow.dart';
import 'package:substitute/services/Weekday.dart';

import 'package:substitute/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppLocalizations de() => lookupAppLocalizations(const Locale('de'));
  AppLocalizations en() => lookupAppLocalizations(const Locale('en'));

  group('export file name', () {
    test('is the date and time as YYYY-MM-DD___HH-MM-SS', () {
      expect(
        ConfigBackupFlow.exportFileName(at: DateTime(2026, 9, 27, 14, 35, 2)),
        '2026-09-27___14-35-02.json',
      );
    });

    test('pads single digits', () {
      expect(
        ConfigBackupFlow.exportFileName(at: DateTime(2026, 1, 2, 3, 4, 5)),
        '2026-01-02___03-04-05.json',
      );
    });

    test('has no random or uuid part', () {
      final String name =
          ConfigBackupFlow.exportFileName(at: DateTime(2026, 9, 27, 14, 35, 2));
      // Genau ein Trenner mit drei Unterstrichen zwischen Datum und Uhrzeit.
      expect(name, matches(RegExp(r'^\d{4}-\d{2}-\d{2}___\d{2}-\d{2}-\d{2}\.json$')));
    });

    test('is actually used as the shared file name', () {
      // Ohne fileNameOverrides vergibt cross_file bei XFile.fromData auf
      // allen Plattformen außer Web eine zufällige ID – die Datei käme dann
      // nicht unter dem gewünschten Namen an.
      final ShareParams params = ConfigBackupFlow.buildShareParams(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: ConfigBackupFlow.exportFileName(
            at: DateTime(2026, 9, 27, 14, 35, 2)),
        subject: 'Betreff',
        text: 'Text',
      );

      expect(params.fileNameOverrides,
          <String>['2026-09-27___14-35-02.json']);
      expect(params.fileNameOverrides!.length, params.files!.length,
          reason: 'die Liste muss zur Anzahl der Dateien passen');
      // Der Name am XFile selbst ist auf Nicht-Web-Plattformen leer – deshalb
      // darf der Ablauf sich nicht darauf verlassen (das war der ursprüngliche
      // Fehler: Die Datei kam als zufällige ID an).
      expect(params.files!.single.name, isNot('2026-09-27___14-35-02.json'),
          reason: 'cross_file verwirft den Namen; nur der Override zählt');
    });
  });

  group('weekday abbreviation', () {
    test('is German in the German locale', () {
      expect(weekdayShort(de(), DateTime(2026, 9, 27)), 'So'); // Sonntag
      expect(weekdayShort(de(), DateTime(2026, 9, 28)), 'Mo');
      expect(weekdayShort(de(), DateTime(2026, 10, 2)), 'Fr');
    });

    test('is English in the English locale', () {
      expect(weekdayShort(en(), DateTime(2026, 9, 27)), 'Sun');
      expect(weekdayShort(en(), DateTime(2026, 9, 28)), 'Mon');
      expect(weekdayShort(en(), DateTime(2026, 10, 2)), 'Fri');
    });

    test('dateWithWeekday puts the weekday in front of the date', () {
      expect(dateWithWeekday(de(), DateTime(2026, 9, 27), '27.09.2026'),
          'So, 27.09.2026');
      expect(dateWithWeekday(en(), DateTime(2026, 9, 27), '27.09.2026'),
          'Sun, 27.09.2026');
    });
  });


  testWidgets('the plan header shows the weekday next to the date',
      (WidgetTester tester) async {
    // Der Plan-Header zeigt "Wochentag, Datum" – hier im Deutschen.
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': ['5a'],
    });
    await AppClock.setOverriddenNow(DateTime(2026, 9, 27, 8, 0));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Plan(classId: '5a')),
    ));
    await tester.pumpAndSettle();

    // 27.09.2026 ist ein Sonntag -> "So".
    expect(find.textContaining('So, 27.09.2026'), findsWidgets);

    await AppClock.setOverriddenNow(null);
  });
}
