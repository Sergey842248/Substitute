import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/AppLanguage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Die Einstellungen mit einer bestimmten Wahl – oder ohne jede, wie bei
  /// einer frischen Installation.
  Future<SharedPreferences> prefsWith(String? choice) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (choice != null) AppLanguage.storageKey: choice,
    });
    return SharedPreferences.getInstance();
  }

  group('Nach einem Update', () {
    // Der Fehler, der hier behoben wurde: Die alte App hat `languageCode`
    // **nie geschrieben**, sondern nur `?? 'de'` angezeigt. Wer Deutsch
    // eingestellt hatte, hatte deshalb keinen Eintrag im Speicher – und der
    // erste Wurf mit "kein Eintrag heißt Neuinstallation, also Systemsprache"
    // hat alle beim Update auf die Systemsprache umgestellt.
    //
    // `firstTime` ist hier das ganze Wissen, das ein Update über sich selbst
    // hinterlässt: `false` heißt, die Einführung wurde durch. So sieht das
    // Gerät aus, das die App schon benutzt hat.

    /// Die Einstellungen einer bestehenden Installation: eingeführt, und **kein**
    /// Sprachcode – genau wie bei jeder Installation, die die alte App hatte.
    Future<SharedPreferences> bestehendeInstallation() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppLanguage.firstTimeStorageKey: false,
      });
      return SharedPreferences.getInstance();
    }

    /// Die Einstellungen einer frischen Installation.
    Future<SharedPreferences> neueInstallation() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance();
    }

    test('behält die bisherige Sprache bei, statt der Systemsprache zu folgen',
        () async {
      final SharedPreferences prefs = await bestehendeInstallation();
      await AppLanguage.migrate(prefs);

      expect(prefs.getString(AppLanguage.storageKey), 'de',
          reason: 'Das Gerät sah vor dem Update Deutsch und muss es danach '
              'weiterhin sehen.');
      // Und es steht jetzt auch wirklich da, statt nur angezeigt zu werden.
      expect(AppLanguage.forMaterialApp(prefs), const Locale('de', ''));
    });

    test('eine Neuinstallation bekommt die Systemsprache', () async {
      final SharedPreferences prefs = await neueInstallation();
      await AppLanguage.migrate(prefs);

      expect(prefs.getString(AppLanguage.storageKey), AppLanguage.system);
      expect(AppLanguage.forMaterialApp(prefs), isNull);
    });

    test(' überschreibt eine selbst gewählte Sprache nicht', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppLanguage.firstTimeStorageKey: false,
        AppLanguage.storageKey: 'en',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await AppLanguage.migrate(prefs);

      expect(prefs.getString(AppLanguage.storageKey), 'en');
    });

    test('läuft nur einmal und schreibt danach nichts mehr', () async {
      final SharedPreferences prefs = await bestehendeInstallation();
      await AppLanguage.migrate(prefs);
      expect(prefs.getBool(AppLanguage.migratedKey), isTrue);

      // Wer danach bewusst auf „Systemsprache" stellt, muss dabei bleiben –
      // der zweite Durchgang darf das nicht zurücksetzen.
      await prefs.setString(AppLanguage.storageKey, AppLanguage.system);
      await AppLanguage.migrate(prefs);
      expect(prefs.getString(AppLanguage.storageKey), AppLanguage.system);
    });

    test('läuft bei jedem Start, ohne Schaden anzurichten', () async {
      final SharedPreferences prefs = await bestehendeInstallation();
      await AppLanguage.migrate(prefs);
      await AppLanguage.migrate(prefs);
      await AppLanguage.migrate(prefs);
      expect(prefs.getString(AppLanguage.storageKey), 'de');
    });

    test('eine halbfertige Einführung gilt als neu', () async {
      // Wer die Einführung nie durchhatte, hat auch nie eine Sprache gewählt.
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppLanguage.firstTimeStorageKey: true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await AppLanguage.migrate(prefs);
      expect(prefs.getString(AppLanguage.storageKey), AppLanguage.system);
    });
  });

  group('Die eingestellte Wahl', () {
    test('ist ohne jede Einstellung die Systemsprache', () async {
      // Vorher stand hier fest 'de'. Ein frisches Gerät in Französisch hätte
      // Deutsch gezeigt, bis jemand das Menü findet.
      //
      // Wichtig: Das gilt **nach** `migrate`. Vorher entscheidet die
      // Migration, ob ein fehlender Eintrag eine Neuinstallation ist oder eine
      // bestehende – siehe die Gruppe darüber.
      expect(AppLanguage.read(await prefsWith(null)), AppLanguage.system);
      expect(AppLanguage.defaultChoice, AppLanguage.system);
    });

    test('bleibt, was gewählt wurde', () async {
      expect(AppLanguage.read(await prefsWith('de')), 'de');
      expect(AppLanguage.read(await prefsWith('en')), 'en');
      expect(AppLanguage.read(await prefsWith(AppLanguage.system)),
          AppLanguage.system);
    });

    test('fällt bei einem unbekannten Wert auf die Systemsprache zurück',
        () async {
      // Lieber Englisch aus einem kaputten Wert als eine Sprache, die es gar
      // nicht gibt.
      expect(AppLanguage.read(await prefsWith('fr')), AppLanguage.system);
      expect(AppLanguage.read(await prefsWith('')), AppLanguage.system);
    });
  });

  group('Die Sprache, die daraus folgt', () {
    test('nimmt die Systemsprache, wenn Deutsch oder Englisch', () {
      expect(
        AppLanguage.resolve(AppLanguage.system, const Locale('de', 'DE')),
        const Locale('de', ''),
      );
      expect(
        AppLanguage.resolve(AppLanguage.system, const Locale('en', 'US')),
        const Locale('en', ''),
      );
      // Auch das Land ist egal – `de_AT` ist Deutsch.
      expect(
        AppLanguage.resolve(AppLanguage.system, const Locale('de', 'AT')),
        const Locale('de', ''),
      );
    });

    test('nimmt Deutsch, wenn die Systemsprache keine ist', () {
      for (final Locale systemisch in <Locale>[
        const Locale('fr', 'FR'),
        const Locale('it', 'IT'),
        const Locale('tr', 'TR'),
      ]) {
        expect(
          AppLanguage.resolve(AppLanguage.system, systemisch),
          const Locale('de', ''),
          reason: '$systemisch kann die App nicht – dann Deutsch.',
        );
      }
    });

    test('nimmt Deutsch, wenn es keine Systemsprache gibt', () {
      expect(AppLanguage.resolve(AppLanguage.system, null),
          const Locale('de', ''));
    });

    test('eine fest gewählte Sprache schlägt die Systemsprache', () {
      // Wer Deutsch gewählt hat, bekommt Deutsch – auch auf einem englischen
      // Telefon.
      expect(
        AppLanguage.resolve('de', const Locale('en', 'US')),
        const Locale('de', ''),
      );
      expect(
        AppLanguage.resolve('en', const Locale('de', 'DE')),
        const Locale('en', ''),
      );
    });
  });

  group('Was MaterialApp bekommt', () {
    test('bei "Systemsprache" bekommt es null', () async {
      // `null` heißt für MaterialApp: nimm die Systemsprache. Damit folgt die
      // App auch einem Wechsel der Systemsprache zur Laufzeit.
      expect(
        AppLanguage.forMaterialApp(await prefsWith(AppLanguage.system)),
        isNull,
      );
    });

    test('bei einer festen Wahl bekommt es genau diese Sprache', () async {
      expect(AppLanguage.forMaterialApp(await prefsWith('de')),
          const Locale('de', ''));
      expect(AppLanguage.forMaterialApp(await prefsWith('en')),
          const Locale('en', ''));
    });

    test('ohne jede Einstellung folgt es dem System', () async {
      expect(AppLanguage.forMaterialApp(await prefsWith(null)), isNull);
    });
  });
}