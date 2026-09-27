import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/Plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vplanSchoolnumber': '123456',
      'vplanUsername': 'user',
      'vplanPassword': 'password',
    });
  });

  Future<void> pumpPersonCourses(WidgetTester tester, {required bool isNew}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PersonCourses(
          classId: '5a',
          person: {
            'id': '1700000000000',
            'name': 'Anna',
            'classId': '5a',
            'courses': <String>[],
          },
          isNew: isNew,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('person settings offer the preview option',
      (WidgetTester tester) async {
    await pumpPersonCourses(tester, isNew: false);

    expect(find.byKey(const ValueKey<String>('previewVisibilityToggle')),
        findsOneWidget);
  });

  testWidgets('a person being created also offers the preview option',
      (WidgetTester tester) async {
    // Die Person hat beim Anlegen bereits eine ID – die Option muss also auch
    // im Erstell-Dialog vorhanden sein.
    await pumpPersonCourses(tester, isNew: true);

    expect(find.byKey(const ValueKey<String>('previewVisibilityToggle')),
        findsOneWidget);
  });

  testWidgets('the preview option uses a note icon, not an eye',
      (WidgetTester tester) async {
    await pumpPersonCourses(tester, isNew: false);

    final Finder toggle =
        find.byKey(const ValueKey<String>('previewVisibilityToggle'));
    final Icon icon = tester.widget<Icon>(find.descendant(
      of: toggle,
      matching: find.byType(Icon),
    ));
    expect(icon.icon, Icons.sticky_note_2_outlined);
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
  });

  testWidgets('the preview option is centered in the header',
      (WidgetTester tester) async {
    await pumpPersonCourses(tester, isNew: false);

    final Rect header = tester.getRect(find.byType(Scaffold).first);
    final Rect toggle = tester.getRect(
      find.byKey(const ValueKey<String>('previewVisibilityToggle')),
    );

    // Die Option sitzt mittig in der Kopfzeile – nicht mehr rechts am Rand.
    // (Die Kopfzeile hat links 10 px Innenabstand, daher liegt die Mitte
    // der Kopfzeile noch ein paar Pixel neben der Bildschirmmitte.)
    final double offset = (toggle.center.dx - header.center.dx).abs();
    expect(offset, lessThan(header.width * 0.05));
  });
}
