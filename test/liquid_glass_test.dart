import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/models/LiquidGlass.dart';

void main() {
  testWidgets('renders its child through a clipped backdrop glass surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: LiquidGlass(
                height: 72,
                radius: 32,
                tint: Color(0x4dffffff),
                child: Text('Glass navigation'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glass navigation'), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('updates its lens parameters and child after a rebuild', (
    WidgetTester tester,
  ) async {
    Widget buildGlass({
      required double radius,
      required double blur,
      required String label,
    }) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: LiquidGlass(
              height: 72,
              radius: radius,
              blur: blur,
              refraction: 18,
              bezel: 22,
              dispersion: 3,
              highlight: 1.1,
              tint: const Color(0x4dffffff),
              child: Text(label),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildGlass(radius: 32, blur: 12, label: 'Before'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildGlass(radius: 26, blur: 20, label: 'After'));
    await tester.pumpAndSettle();

    expect(find.text('Before'), findsNothing);
    expect(find.text('After'), findsOneWidget);
  });
}
