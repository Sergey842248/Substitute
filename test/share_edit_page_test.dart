import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/share/ShareEditPage.dart';
import 'package:substitute/services/sync/SyncApiClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditPage(
    WidgetTester tester, {
    SharedPreferences? prefs,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ShareEditPage(
          client: SyncApiClient(baseUrl: Uri.parse('https://example.invalid')),
          prefs: prefs ?? await SharedPreferences.getInstance(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('creating a share opens without an inherited-widget error',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'vplanSchoolnumber': '123456'});

    // Der Fehler kam schon beim Anlegen der Seite: `initState` griff auf
    // `AppLocalizations.of(context)` zu, also auf ein InheritedWidget, das
    // dort noch gar nicht verfügbar ist. Flutter meldete das als Ausnahme und
    // die Seite erschien gar nicht.
    await pumpEditPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ShareEditPage), findsOneWidget);
  });

  testWidgets('a new share gets a suggested name from the translations',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'vplanSchoolnumber': '123456'});
    // Großes Fenster: Die Liste baut ihre Kinder erst beim Scrollen auf, das
    // Namensfeld liegt weit unten.
    await pumpEditPage(tester, size: const Size(400, 3000));

    // Der Vorschlag wird nachgetragen, weil er die Übersetzungen braucht –
    // er darf deshalb nicht leer bleiben.
    final Iterable<TextFormField> fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField));
    final Iterable<String> texts =
        fields.map((TextFormField f) => f.controller?.text ?? '');
    expect(texts.where((String t) => t.trim().isNotEmpty), isNotEmpty,
        reason: 'the suggested share name must be filled in');
  });
}