import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/share/ShareEditPage.dart';
import 'package:substitute/pages/dashboard/settings/SyncSettings.dart';
import 'package:substitute/pages/share/ShareListPage.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Klassen und Personen, wie die App sie ablegt: Klassen als reine Kürzel,
  /// Personen als JSON-Zeichenkette.
  void seedWithData() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
      'classes': <String>['5a', '6b', '7c'],
      'persons': <String>[jsonEncode({'id': 'p1', 'name': 'Frau Weber'})],
    });
  }

  /// Der Bildschirm ist länger als ein Telefon – großes Fenster, damit alle
  /// Abschnitte ohne Scrollen gebaut werden.
  Future<void> pumpEdit(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ShareEditPage(
          client: SyncApiClient(baseUrl: Uri.parse('https://example.invalid')),
          prefs: await SharedPreferences.getInstance(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('classes are offered for sharing', () {
    // Die Klassen wurden mit jsonDecode gelesen. Sie liegen aber als reine
    // Kürzel ("5a") in den Einstellungen – die Dekodierung schlug bei jedem
    // Eintrag fehl, alle wurden übersprungen, und es erschien keine Klasse zur
    // Auswahl, obwohl welche vorhanden waren.
    test('plain class shorts are read', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['5a', '6b'],
      });
      expect(readClassShorts(await prefs()), <String>['5a', '6b']);
    });

    test('a purely numeric short is kept', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>['123'],
      });
      // `123` ist gültiges JSON (eine Zahl) und darf deshalb nicht verloren
      // gehen.
      expect(readClassShorts(await prefs()), <String>['123']);
    });

    test('an object entry is still tolerated', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'classes': <String>[jsonEncode({'name': '5a'})],
      });
      expect(readClassShorts(await prefs()), <String>['5a']);
    });

    testWidgets('the chips appear when classes exist', (WidgetTester tester) async {
      seedWithData();
      await pumpEdit(tester);

      expect(find.text('5a'), findsOneWidget);
      expect(find.text('6b'), findsOneWidget);
      expect(find.text('7c'), findsOneWidget);
    });

    testWidgets('the class section uses its own empty text',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanSchoolnumber': '123456',
        'classes': <String>[],
      });
      await pumpEdit(tester);

      // Vorher stand hier der Personentext – auch unter „Klassen".
      expect(find.textContaining('Noch keine Klassen'), findsOneWidget);
      // Der Personentext gehört zur Personen-Sektion und steht weiter unten
      // weiterhin – nur nicht mehr beim Klassen-Abschnitt.
      expect(
        find.textContaining('Noch keine Personen'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a new share is called "Mein Plan" by default',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    final String label = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((TextFormField f) => f.controller?.text ?? '')
        .firstWhere((String t) => t.trim().isNotEmpty);
    expect(label.trim(), 'Mein Plan');
  });

  testWidgets('the label hint suggests a neutral example',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    expect(find.text('z.B. Freunde'), findsWidgets);
    expect(find.textContaining('Herbst'), findsNothing);
  });

  testWidgets('the history option explains both states',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    // Der Schalter liegt in den erweiterten Funktionen und ist deshalb erst
    // einmal eingeklappt – vor dem Aufklappen darf davon nichts zu sehen sein.
    expect(find.textContaining('Aus: nur die Pläne der letzten'), findsNothing);

    await tester.tap(find.text('Erweiterte Optionen'));
    await tester.pumpAndSettle();

    // Vorher stand dort nur, was beim Ausschalten passiert – was genau dazu
    // verführte, das Gegenteil anzunehmen.
    expect(find.textContaining('Aus: nur die Pläne der letzten'), findsOneWidget);
    expect(find.textContaining('Sonst werden nur'), findsNothing);
  });

  // Die Option "Gespeicherte Pläne teilen" ist entfernt: Die Pläne gehören zu
  // den geteilten Klassen und werden immer mitgenommen. Übrig bleibt nur die
  // Frage nach ihrem Alter.
  // Klassen und Personen werden gleich ausgewählt: als Feldmarken. Vorher stand
  // bei den Personen eine Liste mit Kontrollkästchen – zwei Systeme für
  // dieselbe Frage auf derselben Seite.
  testWidgets('persons are chips like the classes', (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    expect(find.widgetWithText(FilterChip, '5a'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Frau Weber'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing,
        reason: 'Kontrollkästchen sind abgeschafft – es gibt ein System für '
            'beides.');
  });

  testWidgets('a person can be selected and deselected',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Frau Weber'))
          .selected,
      isFalse,
      reason: 'Nichts ist vorausgewählt – geteilt wird, was man anfasst.',
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Frau Weber'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Frau Weber'))
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Frau Weber'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Frau Weber'))
          .selected,
      isFalse,
    );
  });

  testWidgets('the plans switch is gone; only history and settings remain',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);
    await tester.tap(find.text('Erweiterte Optionen'));
    await tester.pumpAndSettle();

    expect(find.text('Gespeicherte Pläne teilen'), findsNothing);
    expect(find.text('Pläne aus der Vergangenheit teilen'), findsOneWidget);
    expect(find.text('Einstellungen teilen'), findsOneWidget);
  });

  // "Globaler Share" ist entfernt: Ein Share hängt am Nutzernamen und ist von
  // jeder Schule aus zu öffnen. Nur das Suchmenü ist auf die eigene Schule
  // beschränkt – und dafür gibt es den Schalter "Im Suchmenü anzeigen".
  testWidgets('the global switch is gone', (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    expect(find.text('Globaler Share'), findsNothing);
    // Der Titel erscheint zweimal – einmal als Überschrift der Sektion, einmal
    // als Zeile des Schalters. Beide gehören zum Suchmenü.
    expect(find.text('Im Suchmenü anzeigen'), findsNWidgets(2));
  });

  testWidgets('an offensive share name is refused with a warning',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    // Erst eine Auswahl treffen, damit es an der Namensprüfung scheitert und
    // nicht vorher an "nichts ausgewählt".
    await tester.tap(find.text('5a'));
    await tester.pumpAndSettle();

    final TextFormField labelField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    // Deutsches Schimpfwort als Kompositum – das prüft die Normalisierung
    // (`ß` -> `ss`) und die Komposita-Regel (`scheiss` am Wortanfang).
    labelField.controller!.text = 'Scheisskopf';
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    // Warnung sichtbar …
    expect(
      find.text('Dieser Name ist nicht erlaubt. Bitte wähle einen anderen.'),
      findsOneWidget,
    );
    // … und nichts übernommen: Die Seite ist noch offen.
    expect(find.byType(ShareEditPage), findsOneWidget);
  });

  testWidgets('a harmless share name passes the check',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    await tester.tap(find.text('5a'));
    await tester.pumpAndSettle();
    final TextFormField labelField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    labelField.controller!.text = 'Freunde';
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    // Keine Namenswarnung.
    expect(
      find.text('Dieser Name ist nicht erlaubt. Bitte wähle einen anderen.'),
      findsNothing,
    );
  });

  testWidgets('a rejected share never shows a function or raw text',
      (WidgetTester tester) async {
    seedWithData();
    await pumpEdit(tester);

    await tester.tap(find.text('5a'));
    await tester.pumpAndSettle();
    final TextFormField labelField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    labelField.controller!.text = 'Freunde';
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erstellen'));
    await tester.pump(const Duration(milliseconds: 200));

    // `l10n.syncFailed` ist eine Funktion und wurde als String interpoliert –
    // die Meldung begann deshalb mit „Closure: (Object) => String …" samt
    // englischem Originaltext des Servers.
    expect(find.textContaining('Closure:'), findsNothing);
    expect(find.textContaining('This share is not allowed'), findsNothing);
  });

  testWidgets('the server code invalidShare has its own translation',
      (WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (BuildContext context) {
        l10n = AppLocalizations.of(context)!;
        return const SizedBox();
      }),
    ));

    // Vorher fiel der Code durch bis zur generischen Servermeldung, obwohl es
    // eine eigene Übersetzung dafür gab.
    expect(syncErrorMessage(l10n, 'invalidShare'), 'Dieser Share ist nicht erlaubt');
    expect(syncErrorMessage(l10n, 'invalidShare'),
        isNot(syncErrorMessage(l10n, 'somethingElse')));
  });

  testWidgets('a single character share name is accepted',
      (WidgetTester tester) async {
    // Es gibt keine Mindestlänge – auch nicht beim Share-Namen.
    seedWithData();
    await pumpEdit(tester);

    await tester.tap(find.text('5a'));
    await tester.pumpAndSettle();
    final TextFormField labelField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    labelField.controller!.text = 'A';
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mindestens zwei Zeichen'), findsNothing);
  });

}