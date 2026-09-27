import 'package:flutter_test/flutter_test.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Die Vorschau-Sichtbarkeit wird über das Kürzel der Schule (Scope) isoliert,
  // daher genügt hier ein beliebiger, aber für jeden Test gleicher Kontext.
  final Map<String, Object> basePrefs = {
    'vplanSchoolnumber': '123456',
    'vplanUsername': 'user',
    'vplanPassword': 'pass',
  };

  group('preview visibility: global default', () {
    test('classes show the preview by default, persons do not', () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();

      // Klassen: Vorschau aktiv. Personen: Vorschau standardmäßig aus.
      expect(await api.isPreviewHiddenForClass('10A'), isFalse);
      expect(await api.isPreviewHiddenForPerson('p1'), isTrue);
    });

    test('the global setting shows the preview for every person', () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForPersonsGlobally(false);

      expect(await api.isPreviewHiddenForPerson('p1'), isFalse);
      expect(await api.isPreviewHiddenForPerson('p2'), isFalse);
      // Die Personeneinstellung berührt die Klassen nicht.
      expect(await api.isPreviewHiddenForClass('10A'), isFalse);
    });

    test('the global setting hides the preview for every class/person',
        () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForClassesGlobally(true);
      await api.setPreviewHiddenForPersonsGlobally(true);

      expect(await api.isPreviewHiddenForClass('10A'), isTrue);
      expect(await api.isPreviewHiddenForClass('10B'), isTrue);
      expect(await api.isPreviewHiddenForPerson('p1'), isTrue);
      expect(await api.isPreviewHiddenForPerson('p2'), isTrue);
    });

    test('the global setting for classes does not affect persons', () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForClassesGlobally(true);
      // Personeneinstellung explizit auf "anzeigen" stellen, damit der
      // Unterschied zur (per Default ausgeblendeten) Person sichtbar wird.
      await api.setPreviewHiddenForPersonsGlobally(false);

      expect(await api.isPreviewHiddenForClass('10A'), isTrue);
      expect(await api.isPreviewHiddenForPerson('p1'), isFalse);
    });
  });

  group('preview visibility: per class/person override', () {
    test('a class can hide its preview even when the global setting is off',        () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForClass('10A', true);

      expect(await api.isPreviewHiddenForClass('10A'), isTrue);
      expect(await api.isPreviewHiddenForClass('10B'), isFalse);
    });

    test('a class can show its preview even when the global setting is on',
        () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForClassesGlobally(true);
      await api.setPreviewHiddenForClass('10A', false);

      expect(await api.isPreviewHiddenForClass('10A'), isFalse);
      expect(await api.isPreviewHiddenForClass('10B'), isTrue);
    });

    test('a single person can show its preview while the others stay hidden',
        () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      // Standard ist ausgeblendet -> nur diese eine Person wird eingeblendet.
      await api.setPreviewHiddenForPerson('p1', false);

      expect(await api.isPreviewHiddenForPerson('p1'), isFalse);
      expect(await api.isPreviewHiddenForPerson('p2'), isTrue);
      // Die Einstellung einer Person berührt die Klassen nicht.
      expect(await api.isPreviewHiddenForClass('10A'), isFalse);
    });

    test('a single person can hide its preview while the others stay shown',
        () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForPersonsGlobally(false);
      await api.setPreviewHiddenForPerson('p1', true);

      expect(await api.isPreviewHiddenForPerson('p1'), isTrue);
      expect(await api.isPreviewHiddenForPerson('p2'), isFalse);
    });

    test('overriding back to the global value drops the override', () async {
      SharedPreferences.setMockInitialValues(basePrefs);
      final VPlanAPI api = VPlanAPI();
      await api.setPreviewHiddenForClass('10A', true);
      await api.setPreviewHiddenForClass('10A', false);

      // Ohne gespeicherten Override folgt der Plan wieder der globalen
      // Einstellung – auch wenn diese später umgeschaltet wird.
      await api.setPreviewHiddenForClassesGlobally(true);
      expect(await api.isPreviewHiddenForClass('10A'), isTrue);
    });
  });

  group('lesson visibility for a person', () {
    final VPlanAPI api = VPlanAPI();

    Map<String, dynamic> lesson(String course) => {
          'course': course,
          'lesson': '1',
          'teacher': 'AB',
        };

    test('a person without a course selection sees the class courses',
        () {
      // Leere Auswahl == gleiches Verhalten wie eine Klasse ohne Auswahl:
      // Alles sichtbar, was in der Klasse nicht ausgeblendet wurde.
      expect(api.isLessonVisibleForPerson(lesson('M-1'), [], []), isTrue);
      expect(api.isLessonVisibleForPerson(lesson('E-2'), [], []), isTrue);
    });

    test('a person without a course selection still respects hidden courses',
        () {
      expect(
        api.isLessonVisibleForPerson(lesson('M-1'), [], ['M-1']),
        isFalse,
      );
      expect(
        api.isLessonVisibleForPerson(lesson('E-2'), [], ['M-1']),
        isTrue,
      );
    });

    test('a person with a course selection only sees the selected courses',
        () {
      expect(
        api.isLessonVisibleForPerson(lesson('M-1'), ['M-1', 'E-2'], []),
        isTrue,
      );
      expect(
        api.isLessonVisibleForPerson(lesson('Deutsch'), ['M-1', 'E-2'], []),
        isFalse,
      );
    });

    test('a course selection wins over the class course list', () {
      // Die Auswahl der Person ist die engere Menge und hat Vorrang.
      expect(
        api.isLessonVisibleForPerson(lesson('M-1'), ['M-1'], ['M-1']),
        isTrue,
      );
    });
  });
}
