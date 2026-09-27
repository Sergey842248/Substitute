import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';

void main() {
  group('uniquePersonName', () {
    test('keeps the base name when it is still free', () {
      expect(VPlanAPI.uniquePersonName('5a', <String>[]), '5a');
      expect(VPlanAPI.uniquePersonName('5a', <String>['Anna', 'Ben']), '5a');
    });

    test('appends " (1)" when the name is already taken', () {
      expect(VPlanAPI.uniquePersonName('5a', <String>['5a']), '5a (1)');
    });

    test('appends " (2)", " (3)", … for further duplicates', () {
      expect(
        VPlanAPI.uniquePersonName('5a', <String>['5a', '5a (1)']),
        '5a (2)',
      );
      expect(
        VPlanAPI.uniquePersonName('5a', <String>['5a', '5a (1)', '5a (2)']),
        '5a (3)',
      );
    });

    test('finds the first free number even when the list is unordered', () {
      expect(
        VPlanAPI.uniquePersonName('5a', <String>['5a (2)', '5a', '5a (1)']),
        '5a (3)',
      );
    });

    test('ignores empty and blank names', () {
      expect(
        VPlanAPI.uniquePersonName('5a', <String>['', '   ']),
        '5a',
      );
    });

    test('does not treat a different name as a duplicate', () {
      // "5a (1)" ist belegt, "5a" aber nicht – daher bleibt "5a" unverändert.
      expect(VPlanAPI.uniquePersonName('5a', <String>['5a (1)']), '5a');
    });

    test('uses plain ASCII parentheses, not symbols', () {
      final String name = VPlanAPI.uniquePersonName('5a', <String>['5a']);
      expect(name, '5a (1)');

      // Keine typografischen Klammern, Kreise oder andere Sonderzeichen:
      // '(' = U+0028, ')' = U+0029, alles andere muss ASCII sein.
      expect(name.codeUnitAt(3), 0x28, reason: "'(' statt eines Symbols");
      expect(name.codeUnitAt(5), 0x29, reason: "')' statt eines Symbols");
      expect(
        name.codeUnits.every((int unit) => unit < 0x80),
        isTrue,
        reason: 'der Name darf keine Nicht-ASCII-Zeichen enthalten: $name',
      );
    });

    test('the suffix constants are the plain ASCII parentheses', () {
      expect(VPlanAPI.openBracket, '(');
      expect(VPlanAPI.closeBracket, ')');
      expect(VPlanAPI.openBracket.codeUnitAt(0), 0x28);
      expect(VPlanAPI.closeBracket.codeUnitAt(0), 0x29);
    });
  });
}
