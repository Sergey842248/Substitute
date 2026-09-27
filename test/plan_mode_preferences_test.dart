import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:substitute/services/PlanModePreferences.dart';
import 'package:substitute/services/SchoolStorage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading plan modes', () {
    test('defaults to auto when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await PlanModePreferences.readClass(prefs), 'auto');
      expect(await PlanModePreferences.readPerson(prefs), 'auto');
      expect(await PlanModePreferences.readPreviewClass(prefs), 'auto');
      expect(await PlanModePreferences.readPreviewPerson(prefs), 'auto');
    });

    test('class and person modes are independent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PlanModePreferences.writeClass(prefs, 'latest');
      await PlanModePreferences.writePerson(prefs, 'today');

      expect(await PlanModePreferences.readClass(prefs), 'latest');
      expect(await PlanModePreferences.readPerson(prefs), 'today');
    });

    test('the two preview modes are independent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PlanModePreferences.writePreviewClass(prefs, 'latest');
      await PlanModePreferences.writePreviewPerson(prefs, 'today');

      expect(await PlanModePreferences.readPreviewClass(prefs), 'latest');
      expect(await PlanModePreferences.readPreviewPerson(prefs), 'today');

      // Der Planmodus einer Klasse bzw. Person bleibt davon unberührt.
      expect(await PlanModePreferences.readClass(prefs), 'auto');
      expect(await PlanModePreferences.readPerson(prefs), 'auto');
    });

    test('a preview mode does not change the full plan modes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PlanModePreferences.writeClass(prefs, 'today');
      await PlanModePreferences.writePerson(prefs, 'today');
      await PlanModePreferences.writePreviewClass(prefs, 'latest');

      expect(await PlanModePreferences.readClass(prefs), 'today');
      expect(await PlanModePreferences.readPerson(prefs), 'today');
    });

    test('an old shared preview value is used for both previews', () async {
      // Vor der Trennung gab es nur einen gemeinsamen Wert.
      SharedPreferences.setMockInitialValues({'defaultPlanModePreview': 'latest'});
      final prefs = await SharedPreferences.getInstance();

      expect(await PlanModePreferences.readPreviewClass(prefs), 'latest');
      expect(await PlanModePreferences.readPreviewPerson(prefs), 'latest');
    });

    test('a specific preview value wins over the old shared one', () async {
      SharedPreferences.setMockInitialValues({
        'defaultPlanModePreview': 'latest',
        'defaultPlanModePreviewPerson': 'today',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await PlanModePreferences.readPreviewClass(prefs), 'latest');
      expect(await PlanModePreferences.readPreviewPerson(prefs), 'today');
    });

    test('an unknown mode falls back to auto', () async {
      SharedPreferences.setMockInitialValues({
        'defaultPlanModePreviewPerson': 'nonsense',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await PlanModePreferences.readPreviewPerson(prefs), 'auto');
    });

    test('an unknown mode is not persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PlanModePreferences.writePreviewClass(prefs, 'nonsense');

      expect(await PlanModePreferences.readPreviewClass(prefs), 'auto');
    });

    test('modes are scoped per school', () async {
      // Die Vorschau einer anderen Schule lässt sich getrennt einstellen.
      SharedPreferences.setMockInitialValues({
        'defaultPlanModePreviewClass': 'latest',
        'schools.123.defaultPlanModePreviewClass': 'today',
      });
      await SchoolStorage.setActiveSchool('123');
      final prefs = await SharedPreferences.getInstance();

      expect(await PlanModePreferences.readPreviewClass(prefs), 'today');
    });
  });
}
