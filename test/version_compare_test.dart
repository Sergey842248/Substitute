import 'package:flutter_test/flutter_test.dart';

import 'package:expandiware/main.dart';

void main() {
  group('compareVersions', () {
    test('detects newer multi-digit versions (3.7.9 -> 3.7.10)', () {
      expect(compareVersions('3.7.10', '3.7.9'), greaterThan(0));
      expect(compareVersions('3.7.9', '3.7.10'), lessThan(0));
    });

    test('detects newer minor and major versions', () {
      expect(compareVersions('3.8.0', '3.7.99'), greaterThan(0));
      expect(compareVersions('4.0.0', '3.7.10'), greaterThan(0));
      expect(compareVersions('3.7.9', '3.8.0'), lessThan(0));
    });

    test('equal versions compare as zero', () {
      expect(compareVersions('3.7.10', '3.7.10'), 0);
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('versions with different segment counts', () {
      expect(compareVersions('3.7.10', '3.7'), greaterThan(0));
      expect(compareVersions('3.7', '3.7.10'), lessThan(0));
      expect(compareVersions('3.7', '3.7'), 0);
    });

    test('non-numeric segments are treated as 0', () {
      // '10-dev' fails to parse, counts as 0; still deterministic and safe
      expect(compareVersions('3.7.10-dev', '3.7.10'), lessThan(0));
      expect(compareVersions('3.7.10', '3.7.10-dev'), greaterThan(0));
    });
  });
}
