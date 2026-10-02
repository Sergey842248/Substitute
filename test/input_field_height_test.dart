import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/models/InputField.dart';

/// Das Eingabefeld darf seinen Dialog **nicht** aufblähen.
///
/// Der Container hatte ein `alignment` und darin ein `Center`. Beides macht aus
/// ihm ein `Align`, und ein `Align` füllt den ihm gegebenen Raum aus – im
/// `AlertDialog` also den ganzen verfügbaren Dialoginhalt. Beim Sync-Code war
/// der Rahmen dadurch fast so hoch wie das Telefon, mit dem Text in der Mitte
/// und nichts sonst.
void main() {
  Future<void> dialogBauen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', ''),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(context)!.syncJoin,
                    ),
                    content: InputField(
                      controller: TextEditingController(),
                      labelText:
                          AppLocalizations.of(context)!.syncPassphrase,
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('der Dialog mit einem Eingabefeld bleibt klein',
      (WidgetTester tester) async {
    await dialogBauen(tester);

    expect(find.byType(AlertDialog), findsOneWidget);

    final Size bildschirm = tester.view.physicalSize / tester.view.devicePixelRatio;
    // Nicht der `AlertDialog` selbst: Der füllt als `Align` über `Dialog` den
    // ganzen Bildschirm. Gemessen wird die Fläche, die man tatsächlich sieht –
    // die `Material`-Box des Dialogs.
    final Size dialog = tester.getSize(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );

    // Weit unter der halben Bildschirmhöhe. Vorher war der Dialog fast so
    // hoch wie das Gerät, weil das Feld den ganzen Platz beanspruchte.
    expect(
      dialog.height,
      lessThan(bildschirm.height / 2),
      reason: 'das Eingabefeld lässt den Dialog auf ${dialog.height} von '
          '${bildschirm.height} anwachsen',
    );

    // Und es steht links wie in jedem anderen Eingabefeld der App – nicht
    // in der Mitte eines riesigen Rahmens.
    final double breite = tester.getSize(find.byType(TextField)).width;
    final double rahmen = tester.getSize(find.byType(InputField)).width;
    expect(breite, lessThan(rahmen));

    await tester.pumpWidget(const SizedBox());
  });
}