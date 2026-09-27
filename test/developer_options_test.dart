import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/dashboard/settings/DeveloperOptions.dart';
import 'package:substitute/services/AppClock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('developer options override date AND time',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppClock.setOverriddenNow(null);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en', ''),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DeveloperOptions(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No override'), findsOneWidget);

    // Open the date picker (first "Set" button is the custom date one).
    await tester.tap(find.text('Set').first);
    await tester.pumpAndSettle();

    // Confirm the date, then the time picker appears.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // The time picker must be shown; confirm it too.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final DateTime? overridden = await AppClock.getOverriddenNow();
    expect(overridden, isNotNull);
    // The stored value is a full timestamp, not midnight.
    expect(find.text('No override'), findsNothing);

    await AppClock.setOverriddenNow(null);
  });
}
