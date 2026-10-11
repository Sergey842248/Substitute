import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/ModalBottomSheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(WidgetTester tester, Widget content) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ModalBottomSheet(
          title: 'App Info',
          bigTitle: true,
          submitButtonText: 'Close',
          content: content,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Der Inhalt des App-Info-Dialogs: eine Liste von Links und die Version.
  Widget appInfoContent() => Column(
        // Die App übergibt ihren Inhalt bereits zentriert …
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (final String name in <String>['Report an issue', 'GitHub'])
            Padding(
              padding: const EdgeInsets.all(8),
              child: InkWell(
                onTap: () {},
                child: Text(name, textAlign: TextAlign.center),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Version 1.2.3', textAlign: TextAlign.center),
          ),
        ],
      );

  testWidgets('the sheet content is centred, not left aligned',
      (WidgetTester tester) async {
    await pumpSheet(tester, appInfoContent());

    final double centre =
        tester.getRect(find.byType(ModalBottomSheet)).center.dx;

    for (final String label in <String>[
      'Report an issue',
      'GitHub',
      'Version 1.2.3',
    ]) {
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo(centre, 1),
        reason: '"$label" must sit in the middle of the sheet',
      );
    }
  });

  testWidgets('the title and the close button stay centred',
      (WidgetTester tester) async {
    await pumpSheet(tester, appInfoContent());

    final double centre =
        tester.getRect(find.byType(ModalBottomSheet)).center.dx;

    expect(tester.getCenter(find.text('App Info')).dx, closeTo(centre, 1));
    expect(tester.getCenter(find.text('Close')).dx, closeTo(centre, 1));
  });
}