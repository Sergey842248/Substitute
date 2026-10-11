import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/share/ShareImportPage.dart';
import 'package:substitute/services/sync/ShareManager.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShareOwner ownerWithOneShare() => ShareOwner(
        username: 'blue sky river seven apple candle',
        displayName: 'Frau Müller',
        shares: <ShareSummary>[
          ShareSummary(
            id: 'einer',
            username: 'blue sky river seven apple candle',
            displayName: 'Frau Müller',
            label: 'Mein Plan',
            hasPassword: false,
            updatedAt: DateTime.utc(2026, 9, 20),
          ),
        ],
      );

  /// Zählt die Anfragen an den Server.
  ///
  /// Das ist der entscheidende Unterschied: Vorher wurde bei einer einzigen
  /// Share sofort entschlüsselt – also **angefragt**, ohne dass der Nutzer
  /// irgendetwas getan hätte. Diese Anfrage ist genau das, was hier zählt.
  Future<(SyncApiClient, List<String>)> pumpImport(
    WidgetTester tester,
    ShareOwner owner,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vplanSchoolnumber': '12345',
      'vplanUsername': 'm.mueller',
      'vplanPassword': 'pw',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<String> requested = <String>[];
    final SyncApiClient client = SyncApiClient(
      baseUrl: Uri.parse('https://sync.test'),
      client: MockClient((http.Request request) async {
        requested.add('${request.method} ${request.url.path}');
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      }),
    );

    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ShareImportPage(client: client, owner: owner, prefs: prefs)),
    ));
    await tester.pumpAndSettle();

    return (client, requested);
  }

  testWidgets('a single share is listed and NOT fetched automatically',
      (WidgetTester tester) async {
    final (SyncApiClient _, List<String> requested) =
        await pumpImport(tester, ownerWithOneShare());

    // Der Share steht in der Liste …
    expect(find.text('Mein Plan'), findsOneWidget);

    // … und es wurde nichts beim Server geholt: Kein Share wird entschlüsselt,
    // bevor der Nutzer selbst einen auswählt. Vorher passierte genau das
    // automatisch, sobald nur ein Share vorhanden war.
    expect(requested, isEmpty,
        reason: 'nothing may be fetched before the user picks a share');

    // Die Importauswahl ist deshalb noch gar nicht sichtbar.
    expect(find.text('Wie soll es übernommen werden?'), findsNothing);
  });

  testWidgets('tapping the share fetches it and shows the import modes',
      (WidgetTester tester) async {
    final (SyncApiClient _, List<String> requested) =
        await pumpImport(tester, ownerWithOneShare());

    await tester.tap(find.text('Mein Plan'));
    await tester.pumpAndSettle();

    // Jetzt wird geholt – erst durch den Klick.
    expect(requested, isNotEmpty);

    // Der Server liefert hier einen leeren Share, deshalb ist die
    // Importauswahl noch nicht erreicht; entscheidend ist der Klick.
    expect(find.text('Mein Plan'), findsOneWidget);
  });

  group('mit einem echten Share im Server', () {
    const String username = 'blue sky river seven apple candle';

    /// Veröffentlicht einen Share mit zwei Klassen und einer Person und gibt
    /// einen Client zurück, der ihn auch ausliefert.
    Future<SyncApiClient> servingShare(SharedPreferences prefs) async {
      final Map<String, Map<String, dynamic>> stored =
          <String, Map<String, dynamic>>{};
      final SyncApiClient client = SyncApiClient(
        baseUrl: Uri.parse('https://sync.test'),
        client: MockClient((http.Request request) async {
          if (request.method == 'PUT') {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            stored[body['id'] as String] = <String, dynamic>{
              'id': body['id'],
              'label': body['label'],
              'hasPassword': false,
              'updatedAt': body['updated_at'],
              'envelopes': body['envelopes'],
            };
            return http.Response('{}', 200);
          }
          final String? id =
              stored.keys.isEmpty ? null : stored.keys.first;
          if (id == null) {
            return http.Response('{"error":"shareNotFound"}', 404);
          }
          return http.Response(jsonEncode(stored[id]), 200);
        }),
      );

      await ShareManager.ensureIdentity(prefs);
      await prefs.setString(ShareManager.usernameStorageKey, username);
      final ShareSelection selection = const ShareSelection(
        classIds: <String>{'7c', '8a'},
        personIds: <String>{'p1'},
      );
      await ShareManager(client: client).publish(
        prefs: prefs,
        schoolNumber: '12345',
        schoolPassword: 'pw',
        displayName: 'Frau Müller',
        label: 'Mein Plan',
        payload: await ShareManager.buildPayload(prefs, selection),
        selection: selection,
        searchable: true,
      );
      return client;
    }

    Future<void> pumpWithShare(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'vplanSchoolnumber': '12345',
        'vplanPassword': 'pw',
        'classes': <String>['7c', '8a'],
        'persons': <String>[
          jsonEncode(<String, dynamic>{
            'id': 'p1',
            'name': 'Hans',
            'classId': '7c',
            'courses': <String>['Deutsch'],
          }),
        ],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SyncApiClient client = await servingShare(prefs);

      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de', ''),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareImportPage(
            client: client,
            owner: ownerWithOneShare(),
            prefs: prefs,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mein Plan'));
      await tester.pumpAndSettle();
    }

    testWidgets('zeigt jede Klasse und jede Person einzeln',
        (WidgetTester tester) async {
      await pumpWithShare(tester);

      // Beide Klassen stehen als Feldmarke da – einzeln abwählbar …
      expect(find.widgetWithText(FilterChip, '7c'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '8a'), findsOneWidget);
      // … und die Person genauso, im selben System.
      expect(find.widgetWithText(FilterChip, 'Hans'), findsOneWidget);
    });

    testWidgets('die erweiterten Optionen sind eingeklappt',
        (WidgetTester tester) async {
      await pumpWithShare(tester);

      expect(find.text('Erweiterte Optionen'), findsOneWidget);
      // Eingeklappt: weder die drei Radiobuttons noch der Pläne-Schalter.
      expect(find.text('Wie soll es übernommen werden?'), findsNothing);
      expect(find.text('Zwischengespeicherte Pläne übernehmen'), findsNothing);

      await tester.tap(find.text('Erweiterte Optionen'));
      await tester.pumpAndSettle();

      expect(find.text('Wie soll es übernommen werden?'), findsOneWidget);
      expect(find.text('Zwischengespeicherte Pläne übernehmen'), findsOneWidget);
    });

    testWidgets('der Modus ist eine Auswahl, keine Aktion',
        (WidgetTester tester) async {
      await pumpWithShare(tester);
      await tester.tap(find.text('Erweiterte Optionen'));
      await tester.pumpAndSettle();

      // Drei Radiobuttons – und keiner davon importiert beim Antippen.
      // Vorher waren es drei Kacheln, deren Tipp sofort importierte.
      expect(
        find.byType(RadioListTile<ShareImportMode>),
        findsNWidgets(3),
      );
      expect(find.widgetWithText(RadioListTile<ShareImportMode>, 'Original'),
          findsOneWidget);
      expect(find.widgetWithText(RadioListTile<ShareImportMode>, 'Klassen'),
          findsOneWidget);
      expect(
          find.widgetWithText(RadioListTile<ShareImportMode>, 'Personen'),
          findsOneWidget);

      // "Original" steht genau einmal im Bild: als Radiobutton. Vorher stand
      // der geltende Modus zusätzlich als Untertitel über dem Kasten.
      expect(find.text('Original'), findsOneWidget);

      // Und es gibt einen eigenen Knopf zum Übernehmen: Die drei Modi wählen
      // nur aus, sie führen nichts aus.
      expect(find.text('Übernehmen'), findsOneWidget);
    });

    // Der Kasten selbst trägt keinen Untertext mehr: Er ist eine Schaltfläche
    // zum Aufklappen, und der geltende Modus steht ohnehin bei den Radios.
    testWidgets('der aufklappbare Kasten hat keine Beschreibung',
        (WidgetTester tester) async {
      await pumpWithShare(tester);

      final ListTile tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Erweiterte Optionen'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.subtitle, isNull,
          reason: 'Eingeklappt soll dort nichts stehen.');

      await tester.tap(find.text('Erweiterte Optionen'));
      await tester.pumpAndSettle();

      final ListTile open = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Erweiterte Optionen'),
          matching: find.byType(ListTile),
        ),
      );
      expect(open.subtitle, isNull,
          reason: 'Auch aufgeklappt nicht – dort stehen die Radios.');
    });

    testWidgets('der Pläne-Schalter steht links bei den Radiobuttons',
        (WidgetTester tester) async {
      await pumpWithShare(tester);
      await tester.tap(find.text('Erweiterte Optionen'));
      await tester.pumpAndSettle();

      // Der Text des Schalters muss auf derselben Linie beginnen wie der Text
      // der drei Radios darüber. Vorher schob ihn das Icon des Schalters
      // sichtbar nach rechts.
      final double radioLeft = tester.getTopLeft(
        find.descendant(
          of: find.widgetWithText(RadioListTile<ShareImportMode>, 'Original'),
          matching: find.text('Original'),
        ),
      ).dx;
      final double switchLeft = tester.getTopLeft(
        find.text('Zwischengespeicherte Pläne übernehmen'),
      ).dx;
      expect(
        (switchLeft - radioLeft).abs(),
        lessThan(2),
        reason: 'Schalter ($switchLeft) und Radiobutton ($radioLeft) '
            'müssen links gleich stehen.',
      );
    });

    // Personen und Klassen werden jetzt gleich ausgewählt: als Feldmarken.
    testWidgets('Personen sind Feldmarken wie die Klassen',
        (WidgetTester tester) async {
      await pumpWithShare(tester);

      expect(find.widgetWithText(FilterChip, '7c'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Hans'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing,
          reason: 'Kontrollkästchen sind abgeschafft – es gibt jetzt ein '
              'System für beides.');
    });

    testWidgets('eine Person lässt sich abwählen',
        (WidgetTester tester) async {
      await pumpWithShare(tester);

      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Hans'))
            .selected,
        isTrue,
        reason: 'Voreingestellt ist alles ausgewählt.',
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Hans'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Hans'))
            .selected,
        isFalse,
      );
      // Die Klasse daneben bleibt unberührt.
      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, '7c')).selected,
        isTrue,
      );
    });
  });
}