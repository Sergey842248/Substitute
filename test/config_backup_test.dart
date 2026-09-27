import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/services/ConfigBackup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// prefs, so wie sie nach dem Einrichten der App aussehen.
  void seedPrefs({Map<String, Object>? extra}) {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'super-secret',
      'classes': <String>['5a', '5b'],
      'persons': '[{"id":"1","name":"Anna","classId":"5a"}]',
      'hideLessonTimes': true,
      'defaultPlanModePreview': 'latest',
      'languageCode': 'de',
      'teacherShorts': '{"Weber":"W"}',
      'vplanCacheTTL': 300,
      'offlineVPData': <String>['{"date":"x"}'],
      'vplan_cache_2026-09-23': '{"date":"x"}',
      'vplan_cache_2026-09-23_time': 1234,
      'overriddenNow': '2026-09-23T10:00:00',
      ...?extra,
    });
  }

  group('export', () {
    test('contains the configuration keys', () async {
      seedPrefs();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> export =
          await ConfigBackup.buildExport(prefs);
      final Map<String, dynamic> settings =
          export['settings'] as Map<String, dynamic>;

      expect(settings['classes'], <String>['5a', '5b']);
      expect(settings['persons'], contains('Anna'));
      expect(settings['hideLessonTimes'], isTrue);
      expect(settings['defaultPlanModePreview'], 'latest');
      expect(settings['languageCode'], 'de');
      expect(settings['teacherShorts'], '{"Weber":"W"}');
      expect(settings['vplanCacheTTL'], 300);
    });

    test('contains the credentials so a restore works on a new device',
        () async {
      seedPrefs();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> export =
          await ConfigBackup.buildExport(prefs);
      final Map<String, dynamic> settings =
          export['settings'] as Map<String, dynamic>;

      // Zugangsdaten gehören zur Konfiguration – ohne sie wäre eine
      // Wiederherstellung auf einem neuen Gerät nutzlos.
      expect(settings['vplanSchoolnumber'], '123456');
      expect(settings['vplanUsername'], 'user');
      expect(settings['vplanPassword'], 'super-secret');
      expect(ConfigBackup.containsCredentials(settings), isTrue);
    });

    test('reports no credentials when none are stored', () {
      expect(
        ConfigBackup.containsCredentials(<String, dynamic>{'classes': <String>[]}),
        isFalse,
      );
      expect(
        ConfigBackup.containsCredentials(
            <String, dynamic>{'schools.x.vplanPassword': 'p'}),
        isTrue,
      );
    });

    test('can export without credentials', () async {
      seedPrefs();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> export =
          await ConfigBackup.buildExport(prefs, includeCredentials: false);
      final Map<String, dynamic> settings =
          export['settings'] as Map<String, dynamic>;
      final String encoded = jsonEncode(export);

      // Zugangsdaten sind raus, der Rest bleibt vollständig.
      expect(settings, isNot(contains('vplanPassword')));
      expect(settings, isNot(contains('vplanUsername')));
      expect(settings, isNot(contains('vplanSchoolnumber')));
      expect(encoded, isNot(contains('super-secret')));
      expect(ConfigBackup.containsCredentials(settings), isFalse);

      expect(settings['classes'], <String>['5a', '5b']);
      expect(settings['persons'], contains('Anna'));
      expect(settings['hideLessonTimes'], isTrue);
      expect(settings['teacherShorts'], '{"Weber":"W"}');
    });

    test('a credential-free export can still be imported', () async {
      seedPrefs();
      final SharedPreferences source = await SharedPreferences.getInstance();
      final String text = ConfigBackup.encodeExport(
        await ConfigBackup.buildExport(source, includeCredentials: false),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences target = await SharedPreferences.getInstance();
      await ConfigBackup.applyImport(target, ConfigBackup.parseExport(text),
          replace: true);

      // Konfiguration vollständig, Zugangsdaten bleiben leer…
      expect(target.getStringList('classes'), <String>['5a', '5b']);
      expect(target.getString('persons'), contains('Anna'));
      // …und werden beim Ersetzen auch nicht erfunden.
      expect(target.getString('vplanPassword'), isNull);
    });

    test('also strips school-scoped credentials', () async {
      seedPrefs(extra: {
        'schools.abc123.vplanPassword': 'schul-passwort',
        'schools.abc123.vplanUsername': 'lehrer',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> settings =
          (await ConfigBackup.buildExport(prefs, includeCredentials: false))[
              'settings'] as Map<String, dynamic>;

      expect(jsonEncode(settings), isNot(contains('schul-passwort')));
      expect(jsonEncode(settings), isNot(contains('lehrer')));
    });

    test('skips cached plans and developer overrides', () async {
      seedPrefs();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> export =
          await ConfigBackup.buildExport(prefs);
      final Map<String, dynamic> settings =
          export['settings'] as Map<String, dynamic>;

      expect(settings, isNot(contains('offlineVPData')));
      expect(settings.keys.where((String k) => k.startsWith('vplan_cache_')),
          isEmpty);
      expect(settings, isNot(contains('overriddenNow')));
    });

    test('the encoded file is valid JSON with app metadata', () async {
      seedPrefs();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String text = ConfigBackup.encodeExport(
        await ConfigBackup.buildExport(prefs),
        exportedAt: DateTime(2026, 9, 27, 12, 30),
        appVersion: '3.9.0',
      );
      final Map<String, dynamic> decoded =
          (jsonDecode(text) as Map).cast<String, dynamic>();

      expect(decoded['app'], 'substitute');
      expect(decoded['schema'], ConfigBackup.schemaVersion);
      expect(decoded['appVersion'], '3.9.0');
      expect(decoded['exportedAt'], '2026-09-27T12:30:00.000');
    });
  });

  group('import', () {
    test('rejects files that are not valid JSON', () {
      expect(() => ConfigBackup.parseExport('kein json'),
          throwsA(isA<FormatException>()));
    });

    test('rejects a file from a different app', () {
      final String text = jsonEncode({'app': 'anderes', 'schema': 1, 'settings': {}});
      expect(() => ConfigBackup.parseExport(text),
          throwsA(predicate((Object e) =>
              e is FormatException && e.message == 'foreignApp')));
    });

    test('rejects a file from a newer app version', () {
      final String text = jsonEncode({
        'app': 'substitute',
        'schema': ConfigBackup.schemaVersion + 1,
        'settings': <String, dynamic>{},
      });
      expect(() => ConfigBackup.parseExport(text),
          throwsA(predicate((Object e) =>
              e is FormatException && e.message == 'futureSchema')));
    });

    test('restores the configuration (merge)', () async {
      seedPrefs();
      final String text = ConfigBackup.encodeExport(<String, dynamic>{
        'app': 'substitute',
        'schema': ConfigBackup.schemaVersion,
        'settings': <String, dynamic>{
          'hideTeacher': true,
          'persons': '[{"id":"2","name":"Ben","classId":"5b"}]',
          'classes': <String>['9z'],
        },
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ConfigImportResult result = await ConfigBackup.applyImport(
          prefs, ConfigBackup.parseExport(text));

      expect(prefs.getBool('hideTeacher'), isTrue);
      expect(prefs.getString('persons'), contains('Ben'));
      expect(prefs.getStringList('classes'), <String>['9z']);
      // Nicht in der Datei enthalten -> bleibt beim Zusammenführen erhalten.
      expect(prefs.getString('teacherShorts'), '{"Weber":"W"}');
      expect(result.appliedKeys, containsAll(<String>['hideTeacher']));
    });

    test('replace removes settings that are not in the file', () async {
      seedPrefs();
      final String text = ConfigBackup.encodeExport(<String, dynamic>{
        'app': 'substitute',
        'schema': ConfigBackup.schemaVersion,
        'settings': <String, dynamic>{'hideTeacher': true},
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ConfigImportResult result = await ConfigBackup.applyImport(
          prefs, ConfigBackup.parseExport(text),
          replace: true);

      expect(prefs.getBool('hideTeacher'), isTrue);
      expect(prefs.getStringList('classes'), isNull);
      expect(prefs.getString('teacherShorts'), isNull);
      // Der Plan-Cache wird beim Ersetzen nicht angerührt.
      expect(prefs.getStringList('offlineVPData'), <String>['{"date":"x"}']);
      expect(result.removedKeys, contains('classes'));
    });

    test('credentials from the file are written', () async {
      seedPrefs(extra: {'vplanPassword': 'old'});
      final String text = ConfigBackup.encodeExport(<String, dynamic>{
        'app': 'substitute',
        'schema': ConfigBackup.schemaVersion,
        'settings': <String, dynamic>{
          'vplanPassword': 'neu',
          'vplanUsername': 'neuer-user',
          'vplanSchoolnumber': '999',
          'hideTeacher': true,
        },
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ConfigImportResult result = await ConfigBackup.applyImport(
          prefs, ConfigBackup.parseExport(text),
          replace: true);

      expect(prefs.getString('vplanPassword'), 'neu');
      expect(prefs.getString('vplanUsername'), 'neuer-user');
      expect(prefs.getString('vplanSchoolnumber'), '999');
      expect(prefs.getBool('hideTeacher'), isTrue);
      expect(result.appliedKeys, contains('vplanPassword'));
    });

    test('cached plans are never imported from a file', () async {
      seedPrefs(extra: {'offlineVPData': <String>['alt']});
      final String text = ConfigBackup.encodeExport(<String, dynamic>{
        'app': 'substitute',
        'schema': ConfigBackup.schemaVersion,
        'settings': <String, dynamic>{
          'offlineVPData': <String>['neu'],
          'vplan_cache_2026-09-23': '{"date":"x"}',
          'overriddenNow': '2026-01-01T00:00:00',
          'hideTeacher': true,
        },
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ConfigImportResult result = await ConfigBackup.applyImport(
          prefs, ConfigBackup.parseExport(text),
          replace: true);

      expect(prefs.getStringList('offlineVPData'), <String>['alt']);
      expect(prefs.getString('vplan_cache_2026-09-23'), '{"date":"x"}');
      expect(prefs.getString('overriddenNow'), '2026-09-23T10:00:00');
      expect(result.skippedKeys, contains('offlineVPData'));
    });

    test('a full export/import round trip restores everything', () async {
      seedPrefs();
      final SharedPreferences source = await SharedPreferences.getInstance();
      final String text =
          ConfigBackup.encodeExport(await ConfigBackup.buildExport(source));

      // Zweite, frische Installation ohne Einstellungen.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences target = await SharedPreferences.getInstance();
      await ConfigBackup.applyImport(target, ConfigBackup.parseExport(text),
          replace: true);

      expect(target.getStringList('classes'), <String>['5a', '5b']);
      expect(target.getString('persons'), contains('Anna'));
      expect(target.getBool('hideLessonTimes'), isTrue);
      expect(target.getString('defaultPlanModePreview'), 'latest');
      expect(target.getString('languageCode'), 'de');
      expect(target.getString('teacherShorts'), '{"Weber":"W"}');
      expect(target.getInt('vplanCacheTTL'), 300);
      // Auch die Zugangsdaten – die App ist danach direkt nutzbar.
      expect(target.getString('vplanSchoolnumber'), '123456');
      expect(target.getString('vplanUsername'), 'user');
      expect(target.getString('vplanPassword'), 'super-secret');
    });
  });
}
