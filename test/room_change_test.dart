import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:xml/xml.dart';
import 'package:xml2json/xml2json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('marks only the changed parallel course, including named rooms',
      () async {
    // Corresponds to the affected entries of PlanKl20261006.xml: `ch2`
    // changes to the named room "Bibo" while `de1` and `ge1` do not change.
    const String source = '''
<VpMobil><Klassen><Kl><Kurz>11</Kurz><Pl>
  <Std><St>1</St><Fa>de1</Fa><Ku2>de1</Ku2><Le>WA</Le><Ra>214</Ra><Nr>521</Nr></Std>
  <Std><St>5</St><Fa>ge1</Fa><Ku2>ge1</Ku2><Le>SI</Le><Ra>214</Ra><Nr>547</Nr></Std>
  <Std><St>5</St><Fa>ch2</Fa><Ku2>ch2</Ku2><Le LeAe="LeGeaendert">BA</Le><Ra RaAe="RaGeaendert">Bibo</Ra><Nr>546</Nr></Std>
  <Std><St>6</St><Fa>ge1</Fa><Ku2>ge1</Ku2><Le>SI</Le><Ra>214</Ra><Nr>547</Nr></Std>
  <Std><St>6</St><Fa>ch2</Fa><Ku2>ch2</Ku2><Le>BA</Le><Ra RaAe="RaGeaendert">Bibo</Ra><Nr>546</Nr></Std>
</Pl></Kl></Klassen></VpMobil>''';
    final XmlDocument document = XmlDocument.parse(source);
    final Iterable<XmlElement> classes = document
        .getElement('VpMobil')!
        .getElement('Klassen')!
        .findAllElements('Kl');
    final Map<String, Map<String, bool>> roomChanges =
        VPlanAPI.roomChangesFromXml(classes);
    final Map<String, Map<String, bool>> teacherChanges =
        VPlanAPI.teacherChangesFromXml(classes);

    final Xml2Json xml2json = Xml2Json()..parse(source);
    final dynamic parker = jsonDecode(xml2json.toParker());
    final List<dynamic> lessons = await VPlanAPI().parseVPlanXML(
      parker['VpMobil']['Klassen']['Kl'],
      '11',
      roomChanges['11'],
      teacherChanges['11'],
    );

    dynamic lesson(String course, String period) => lessons.singleWhere(
          (dynamic item) => item['course'] == course && item['count'] == period,
        );

    expect(lesson('de1', '1')['placeChanged'], isFalse);
    expect(lesson('ge1', '5')['placeChanged'], isFalse);
    expect(lesson('ch2', '5')['place'], 'Bibo');
    expect(lesson('ch2', '5')['placeChanged'], isTrue);
    expect(lesson('ch2', '6')['placeChanged'], isTrue);
    expect(lesson('ch2', '5')['teacherChanged'], isTrue);
    expect(lesson('ge1', '5')['teacherChanged'], isFalse);
  });
}
