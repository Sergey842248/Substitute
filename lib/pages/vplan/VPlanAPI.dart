import 'dart:convert';

import 'package:http_auth/http_auth.dart' as http_auth;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:xml2json/xml2json.dart';
import 'package:xml/xml.dart';

import 'DemoData.dart';

class VPlanAPI {
  int schoolnumber = 0; // = prefs.getString("vplanSchoolnumber");
  String vplanUsername = ''; // = prefs.getString("vplanUsername");
  String vplanPassword = ''; // = prefs.getString("vplanPassword");

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  String _prefKey(SharedPreferences prefs, String key) {
    return SchoolStorage.scopedKey(prefs, key);
  }

  Future<void> login() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Detect demo mode: Schulnummer 123456, Benutzer user, Passwort password
    final sn = prefs.getString(_prefKey(prefs, "vplanSchoolnumber")) ?? '';
    final un = prefs.getString(_prefKey(prefs, "vplanUsername")) ?? '';
    final pw = prefs.getString(_prefKey(prefs, "vplanPassword")) ?? '';
    final customUrl = prefs.getString(_prefKey(prefs, 'customUrl')) ?? '';
    if (sn == "123456" && un == "user" && pw == "password") {
      _isDemoMode = true;
      schoolnumber = 123456;
      vplanUsername = "user";
      vplanPassword = "password";
      return;
    }
    _isDemoMode = false;

    if (customUrl != '') {
      return;
    }
    if (sn == '' || un == '' || pw == '') {
      schoolnumber = 0;
      vplanUsername = un;
      vplanPassword = pw;
      return;
    }
    schoolnumber = int.parse(sn);
    vplanUsername = un;
    vplanPassword = pw;
  }

  Future<dynamic> getClassList() async {
    await this.login();

    if (_isDemoMode) {
      return DemoData.classes;
    }

    List<String> classList = [];

    dynamic data = await getVPlanJSON(
      Uri.parse(await getDayURL()),
      DateTime.now(),
    );

    if (data['error'] != null) {
      return data;
    }

    for (int i = 0; i < data['data']['Klassen']['Kl'].length; i++) {
      classList.add(data['data']['Klassen']['Kl'][i]['Kurz']);
    }
    return classList;
  }

  /// Speichert die ausgeblendeten Kurse **pro Klasse** (nicht mehr global),
  /// damit neu angelegte Klassen/Personen initial alle Kurse sichtbar haben.
  ///
  /// Format: 'hiddenSubjectsByClass' = JSON-Map { classId: [course, ...] }
  Map<String, dynamic> _decodeHiddenByClass(SharedPreferences prefs) {
    String? data = prefs.getString(_prefKey(prefs, 'hiddenSubjectsByClass'));
    if (data == null || data.isEmpty) return {};
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Einmalige Migration: die alte globale 'hiddenSubjects'-Liste wird auf
  /// alle bereits angelegten Klassen übertragen, damit sich für bestehende
  /// Klassen nichts ändert. Neu hinzugefügte Klassen starten leer (alle
  /// Kurse sichtbar).
  Future<void> _migrateHiddenCourses(SharedPreferences prefs) async {
    if (prefs.containsKey(_prefKey(prefs, 'hiddenSubjectsByClass'))) return;
    List<String>? old = prefs.getStringList(_prefKey(prefs, 'hiddenSubjects'));
    List<String>? classes = prefs.getStringList(_prefKey(prefs, 'classes'));
    Map<String, dynamic> byClass = {};
    if (old != null && old.isNotEmpty && classes != null) {
      for (String c in classes) {
        byClass[c] = List<String>.from(old);
      }
    }
    await prefs.setString(
        _prefKey(prefs, 'hiddenSubjectsByClass'), jsonEncode(byClass));
    await prefs.remove(_prefKey(prefs, 'hiddenSubjects'));
  }

  Future<void> addHiddenCourse(String classId, String lesson) async {
    if (lesson == '---') {
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> byClass = _decodeHiddenByClass(prefs);
    List<String> hidden = (byClass[classId] as List?)?.cast<String>() ?? [];
    if (!hidden.contains(lesson)) {
      hidden.add(lesson);
    }
    byClass[classId] = hidden;

    await prefs.setString(
        _prefKey(prefs, 'hiddenSubjectsByClass'), jsonEncode(byClass));
  }

  Future<void> removeHiddenCourse(String classId, String course) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> byClass = _decodeHiddenByClass(prefs);
    List<String> hidden = (byClass[classId] as List?)?.cast<String>() ?? [];
    hidden.remove(course);
    byClass[classId] = hidden;

    await prefs.setString(
        _prefKey(prefs, 'hiddenSubjectsByClass'), jsonEncode(byClass));
  }

  /// Entfernt die gespeicherten ausgeblendeten Kurse einer Klasse. Wird
  /// beim Löschen einer Klasse aus den Favoriten aufgerufen, damit eine
  /// später erneut hinzugefügte Klasse wieder mit allen Kursen startet.
  Future<void> removeHiddenCoursesForClass(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> byClass = _decodeHiddenByClass(prefs);
    byClass.remove(classId);
    await prefs.setString(
        _prefKey(prefs, 'hiddenSubjectsByClass'), jsonEncode(byClass));
  }

  /// Setzt die ausgeblendeten Kurse einer Klasse auf eine bestimmte Liste.
  /// Ermöglicht effiziente Bulk-Operationen statt einzelner Aufrufe.
  Future<void> setHiddenCourses(String classId, List<String> courses) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> byClass = _decodeHiddenByClass(prefs);
    byClass[classId] = courses;
    await prefs.setString(
        _prefKey(prefs, 'hiddenSubjectsByClass'), jsonEncode(byClass));
  }

  // --- Class initialization tracking ---

  Map<String, dynamic> _decodeInitializedClasses(SharedPreferences prefs) {
    String? data = prefs.getString(_prefKey(prefs, 'initializedClasses'));
    if (data == null || data.isEmpty) return {};
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> markClassInitialized(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> initialized = _decodeInitializedClasses(prefs);
    initialized[classId] = true;
    await prefs.setString(
        _prefKey(prefs, 'initializedClasses'), jsonEncode(initialized));
  }

  /// Benutzerdefinierte Namen für die Favoriten-Klassen.
  ///
  /// Format: 'classNames' = JSON-Map { classId: customName }
  Map<String, dynamic> _decodeClassNames(SharedPreferences prefs) {
    String? data = prefs.getString(_prefKey(prefs, 'classNames'));
    if (data == null || data.isEmpty) return {};
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Liefert den benutzerdefinierten Namen einer Klasse oder null, falls
  /// keiner gesetzt ist.
  Future<String?> getClassName(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? name = _decodeClassNames(prefs)[classId]?.toString();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Liefert alle benutzerdefinierten Klassennamen als Map { classId: name }.
  Future<Map<String, String>> getClassNames() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> names = _decodeClassNames(prefs);
    return names.map((key, value) => MapEntry(key, value.toString()));
  }

  /// Setzt den benutzerdefinierten Namen einer Klasse. Ein leerer Name
  /// entfernt den gespeicherten Namen wieder.
  Future<void> setClassName(String classId, String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> names = _decodeClassNames(prefs);
    if (name.trim().isEmpty) {
      names.remove(classId);
    } else {
      names[classId] = name.trim();
    }
    await prefs.setString(_prefKey(prefs, 'classNames'), jsonEncode(names));
  }

  /// Entfernt den gespeicherten Namen einer Klasse. Wird beim Löschen einer
  /// Klasse aus den Favoriten aufgerufen, damit ein später erneut
  /// hinzugefügter Klasseneintrag wieder ohne benutzerdefinierten Namen
  /// startet.
  Future<void> removeClassName(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> names = _decodeClassNames(prefs);
    names.remove(classId);
    await prefs.setString(_prefKey(prefs, 'classNames'), jsonEncode(names));
  }

  Future<List<String>> getHiddenCourses(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await _migrateHiddenCourses(prefs);

    Map<String, dynamic> byClass = _decodeHiddenByClass(prefs);
    return (byClass[classId] as List?)?.cast<String>() ?? [];
  }

  /// Prüft, ob ein Stunden-/Ausfall-Eintrag zu einem vom Nutzer
  /// ausgeblendeten Kurs gehört.
  ///
  /// Manche Einträge (v.a. komplette Kursausfälle wie
  /// "spl1 Herr Schilling fällt aus") haben kein gesetztes 'course'
  /// bzw. 'lesson' Feld - das Kurskürzel steckt dort nur als erstes
  /// Wort im freien 'info'-Text. Ohne diese zusätzliche Prüfung wurden
  /// solche Einträge nie herausgefiltert, selbst wenn der Kurs
  /// abgewählt war.
  bool isLessonHidden(dynamic lesson, List<String> hiddenCourses) {
    if (hiddenCourses.contains(lesson['course']) ||
        hiddenCourses.contains(lesson['lesson'])) {
      return true;
    }

    if (lesson['info'] != null) {
      String infoText = lesson['info'].toString().trim();
      if (infoText.isNotEmpty) {
        String firstWord = infoText.split(RegExp(r'\s+')).first;
        if (hiddenCourses.contains(firstWord)) {
          return true;
        }
      }
    }

    return false;
  }
  // --- Persons (named profiles with class + own course selection) ---

  Future<List<Map<String, dynamic>>> getPersons() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_prefKey(prefs, 'persons'));
    if (data == null || data.isEmpty) {
      return [];
    }
    try {
      List<dynamic> list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error parsing persons: $e');
      return [];
    }
  }

  Future<void> savePersons(List<Map<String, dynamic>> persons) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(_prefKey(prefs, 'persons'), jsonEncode(persons));
  }

  Future<void> addPerson(Map<String, dynamic> person) async {
    List<Map<String, dynamic>> persons = await getPersons();
    persons.add(person);
    await savePersons(persons);
  }

  Future<void> updatePersonCourses(
      String personId, List<String> courses) async {
    List<Map<String, dynamic>> persons = await getPersons();
    for (int i = 0; i < persons.length; i++) {
      if (persons[i]['id'] == personId) {
        persons[i]['courses'] = courses;
        break;
      }
    }
    await savePersons(persons);
  }

  Future<void> deletePerson(String personId) async {
    List<Map<String, dynamic>> persons = await getPersons();
    persons.removeWhere((p) => p['id'] == personId);
    await savePersons(persons);
  }

  Future<List<dynamic>> getShownCourses(String classId) async {
    List<String> hiddenSubjects = await getHiddenCourses(classId);

    List<dynamic> courses = await getCourses(classId);

    for (int i = 0; i < hiddenSubjects.length; i++) {
      for (int j = 0; j < courses.length; j++) {
        if (hiddenSubjects[i] == courses[j]['course']) courses.removeAt(j);
      }
    }

    return courses;
  }

  Future<dynamic> searchForOfflineData(DateTime vpDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getStringList(_prefKey(prefs, 'offlineVPData')) == null ||
        prefs.getStringList(_prefKey(prefs, 'offlineVPData')) == []) {
      return false;
    }
    List<dynamic> jsonData = [];

    jsonData = prefs
        .getStringList(_prefKey(prefs, 'offlineVPData'))!
        .map((e) => jsonDecode(e))
        .toList();

    for (int i = 0; i < jsonData.length; i++) {
      if (compareDate(vpDate, jsonData[i]['data']['Kopf']['DatumPlan'])) {
        // print('we have an offline backup!');
        return jsonData[i];
      }
    }
    return false;
  }

  Future<void> removePlanByDate(String date) async {
    await this.cleanVplanOfflineData();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? stored =
        prefs.getStringList(_prefKey(prefs, 'offlineVPData'));
    if (stored == null || stored.isEmpty) return;

    List<String> newVplanData = [];
    for (int i = 0; i < stored.length; i++) {
      dynamic entry;
      try {
        entry = jsonDecode(stored[i]);
      } catch (e) {
        continue;
      }
      if (entry['date'] != date) {
        newVplanData.add(stored[i]);
      }
    }
    prefs.setStringList(_prefKey(prefs, 'offlineVPData'), newVplanData);
  }

  Future<dynamic> getAllOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? offlineVPData =
        prefs.getStringList(_prefKey(prefs, 'offlineVPData'));

    if (offlineVPData == null) {
      return [];
    } else {
      // print('offlineVPData');
      return offlineVPData.map((e) => jsonDecode(e));
    }
  }

  Future<void> refreshAllPlansInBackground() async {
    await login();
    if (_isDemoMode) return; // No background refresh needed in demo mode

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get all student classes
    List<String>? classes = prefs.getStringList(_prefKey(prefs, 'classes'));
    if (classes == null || classes.isEmpty) return;

    // Get the URL for today's plan
    String urlString = await getDayURL();
    Uri url = Uri.parse(urlString);
    DateTime today = DateTime.now();

    // Refresh each class in the background in parallel (force refresh to get latest data)
    await Future.wait(classes.map((classId) async {
      try {
        // Force refresh by calling getVPlanJSON with forceRefresh: true
        await getVPlanJSON(url, today, forceRefresh: true);
      } catch (e) {
        print('Background refresh error for class $classId: $e');
      }
    }));
  }

  Future<List<dynamic>> getCourses(String classId) async {
    await login();

    if (_isDemoMode) {
      return DemoData.getCourses(classId);
    }

    List<dynamic> data = (await getVPlanJSON(
      Uri.parse(await getDayURL()),
      DateTime.now(),
    ))['courses'];

    List<dynamic> returnData = [];

    for (int i = 0; i < data.length; i++) {
      if (data[i]['classId'] == classId) {
        returnData.add(data[i]);
      }
    }
    return returnData;
  }

  Future<dynamic> getVPlanJSON(Uri url, DateTime vpDate,
      {bool forceRefresh = false}) async {
    // Check demo mode FIRST to avoid any caching/network interference
    await login();

    if (_isDemoMode) {
      if (DemoData.isWeekend(vpDate)) {
        return DemoData.buildEmptyDayPlan(vpDate);
      }
      return DemoData.buildDayPlan(vpDate);
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<dynamic> data = [];

    // Check TTL cache first unless force refresh is requested
    if (!forceRefresh) {
      String cacheKey =
          'vplan_cache_${vpDate.year}-${vpDate.month.toString().padLeft(2, '0')}-${vpDate.day.toString().padLeft(2, '0')}';
      String scopedCacheKey = _prefKey(prefs, cacheKey);
      String? cachedData = prefs.getString(scopedCacheKey);
      int? cacheTime = prefs.getInt('${scopedCacheKey}_time');

      if (cachedData != null && cacheTime != null) {
        int cacheTTL =
            prefs.getInt('vplanCacheTTL') ?? 300; // 5 minutes default
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        if (currentTime - cacheTime < cacheTTL * 1000) {
          print('Using cached data for ${vpDate.toString().split(' ')[0]}');
          return jsonDecode(cachedData);
        }
      }
    }

    dynamic offlinePlan = await searchForOfflineData(vpDate);

    if (offlinePlan != false) return offlinePlan;

    Xml2Json xml2json = Xml2Json();
    var client;

    if (prefs.getString(_prefKey(prefs, 'customUrl')) != null &&
        prefs.getString(_prefKey(prefs, 'customUrl')) != '') {
      if (url.toString().contains('PlanKl')) {
        // For dated requests, append the path to customUrl
        String path = url.path;
        url = Uri.parse(prefs.getString(_prefKey(prefs, 'customUrl'))! + path);
      } else {
        url = Uri.parse(prefs.getString(_prefKey(prefs, 'customUrl'))! +
            'mobdaten/Klassen.xml');
      }
    } else {
      client = http_auth.BasicAuthClient(vplanUsername, vplanPassword);
    }
    try {
      return ((prefs.getString(_prefKey(prefs, 'customUrl')) != null &&
                  prefs.getString(_prefKey(prefs, 'customUrl')) != '')
              ? http.Client()
              : client)
          .get(url)
          .then((res) {
        if (res.body
            .toString()
            .contains('Die eingegebene Schulnummer wurde nicht gefunden.')) {
          return {'error': 'schoolnumber'};
        }
        if (res.body.toString().contains('Error 401 - Unauthorized')) {
          return {'error': '401'};
        }
        //print(res.body);
        String source = utf8.decode(res.bodyBytes, allowMalformed: true);

        // remove BOM
        if (source.startsWith('\uFEFF')) {
          source = source.substring(1);
        }
        xml2json.parse(source);
        String stringVPlan = xml2json.toParker();

        dynamic jsonVPlan = jsonDecode(stringVPlan);

        if (jsonVPlan['VpMobil'] == null) {
          return {};
        }

        /* NEW XML PARSER */

        final XmlDocument xmlVPlan = XmlDocument.parse(source);

        Iterable<XmlElement>? ziZeilen;
        try {
          ziZeilen = xmlVPlan
              .getElement('VpMobil')!
              .getElement('ZusatzInfo')!
              .findAllElements('ZiZeile');
        } catch (e) {
          ziZeilen = [];
        }

        List<dynamic> courses = [];

        Iterable<XmlElement> classes = xmlVPlan
            .getElement('VpMobil')!
            .getElement('Klassen')!
            .findAllElements('Kl');

        for (int i = 0; i < classes.length; i++) {
          Iterable<XmlElement> _courses =
              classes.elementAt(i).getElement('Kurse')!.findAllElements('Ku');
          String classId = classes.elementAt(i).getElement('Kurz')!.innerText;
          for (int j = 0; j < _courses.length; j++) {
            XmlElement kkz = _courses.elementAt(j).getElement('KKz')!;
            courses.add(
              {
                'classId': classId,
                'course': kkz.innerText,
                'teacher': kkz.attributes.first.value
              },
            );
          }
        }

        // Parse room changes from XML (RaAe attribute indicates room change)
        Map<String, Map<String, bool>> roomChanges = {};
        for (int i = 0; i < classes.length; i++) {
          String classId = classes.elementAt(i).getElement('Kurz')!.innerText;
          roomChanges[classId] = {};

          XmlElement? pl = classes.elementAt(i).getElement('Pl');
          if (pl != null) {
            Iterable<XmlElement> stunden = pl.findAllElements('Std');
            for (var std in stunden) {
              XmlElement? raElement = std.getElement('Ra');
              XmlElement? stElement = std.getElement('St');
              if (raElement != null && stElement != null) {
                bool hasRaAe = raElement.getAttribute('RaAe') != null;
                roomChanges[classId]![stElement.innerText] = hasRaAe;
              }
            }
          }
        }

        /* NEW XML PARSER */

        var infoList = ziZeilen.map((e) => e.innerText).toList();
        var lastNotEmpty = infoList.lastIndexWhere((s) => s.trim().isNotEmpty);
        if (lastNotEmpty != -1) {
          infoList = infoList.sublist(0, lastNotEmpty + 1);
        }

        data.add({
          'date': jsonVPlan['VpMobil']['Kopf']['DatumPlan'],
          'week': jsonVPlan['VpMobil']['Kopf']['Woche'],
          'data': jsonVPlan['VpMobil'],
          'info': infoList,
          'courses': courses,
          'roomChanges': roomChanges,
        });
        //-------------------------------------
        List<String>? stringData =
            prefs.getStringList(_prefKey(prefs, 'offlineVPData'));
        stringData ??= [];

        // check if vplan already exist
        bool add = true;
        for (int i = 0; i < stringData.length; i++) {
          ziZeilen.map((e) => e.innerText.toString()).toList();
          if (compareDate(vpDate, jsonDecode(stringData[i])['date'])) {
            add = false;
          }
        }

        if (add) {
          stringData.add(jsonEncode(data.last));
          // print('added');
        } else {
          // print('plan already exist...');
        }

        prefs.setStringList(_prefKey(prefs, 'offlineVPData'), stringData);
        //print(prefs.getStringList('offlineVPData'));
        //-------------------------------------

        return data.last;
      });
    } catch (e) {
      print("Fehler bei getVplanJson");
    }
  }

  bool compareDate(DateTime datetime, String date2) {
    DateTime date1 = parseStringDatatoDateTime(date2);

    if (date1.day == datetime.day) {
      if (date1.month == datetime.month) {
        if (date1.year == datetime.year) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns a well-formed, empty plan for a given date so callers can
  /// always rely on the 'date'/'data'/'info' keys being present.
  Map<String, dynamic> _emptyPlan(DateTime date) {
    return {
      'date': DemoData.germanDate(date),
      'week': '',
      'data': [],
      'info': [],
    };
  }

  Future<dynamic> getLessonsForToday(String classId) async {
    await login();

    Uri url = Uri.parse(await getDayURL());

    dynamic pureVPlan;
    try {
      pureVPlan = await getVPlanJSON(url, DateTime.now());
      //print(pureVPlan);
    } catch (e) {
      // print('line 316 in VPlanAPI.dart --> $e');
      return {'error': 'no internet'};
    }

    if (pureVPlan == null || pureVPlan.isEmpty) {
      return _emptyPlan(DateTime.now());
    }
    if (pureVPlan['error'] != null) {
      return pureVPlan;
    }

    var jsonVPlan =
        pureVPlan['data']['Klassen']['Kl']; //get the XML data of the URL

    Map<String, bool>? classRoomChanges;
    if (pureVPlan['roomChanges']?[classId] != null) {
      classRoomChanges =
          Map<String, bool>.from(pureVPlan['roomChanges'][classId]);
    }

    List<dynamic> lessons =
        await parseVPlanXML(jsonVPlan, classId, classRoomChanges);
    return {
      'date': pureVPlan['date'],
      'week': pureVPlan['week'],
      'data': lessons,
      'info': pureVPlan['info'],
    };
  }

  Future<String> getDayURL() async {
    await login();
    return 'https://www.stundenplan24.de/${this.schoolnumber}/mobil/mobdaten/Klassen.xml';
  }

  Future<String> getURL(DateTime date) async {
    await login();
    return 'https://www.stundenplan24.de/${this.schoolnumber}/mobil/mobdaten/Klassen.xml';
  }

  Future<List<dynamic>> parseVPlanXML(dynamic jsonVPlan, String classId,
      [Map<String, bool>? roomChanges]) async {
    List<dynamic> _outpuLessons = [];
    final Map<String, Map<String, String>> lessonTimes =
        await _loadLessonTimes();

    if (jsonVPlan == null) {
      return List.empty();
    }
    for (int i = 0; i < jsonVPlan.length; i++) {
      // scan all classes
      if (jsonVPlan[i]['Kurz'] == classId) {
        // check if it is the right class
        var _lessons = jsonVPlan[i]['Pl']['Std'];

        for (int j = 0; j < _lessons.length; j++) {
          // parse the lessons
          var currentLesson = _lessons[j];
          String lessonCount = currentLesson['St']?.toString() ?? '';
          final Map<String, String>? lessonTime = lessonTimes[lessonCount];
          bool hasRaAe = roomChanges?[lessonCount] ?? false;
          String room = currentLesson['Ra'] ?? '';
          bool hasLetters = RegExp(r'[a-zA-Z]').hasMatch(room);
          bool placeChanged = hasRaAe && !hasLetters;

          _outpuLessons.add({
            'count': currentLesson['St'],
            'lesson': currentLesson['Fa'],
            'teacher': await replaceTeacherShort(currentLesson['Le']),
            'place': currentLesson['Ra'],
            'placeChanged': placeChanged,
            'begin': lessonTime?['start'] ?? currentLesson['Beginn'],
            'end': lessonTime?['end'] ?? currentLesson['Ende'],
            'info': currentLesson['If'],
            'course': currentLesson['Ku2'],
          });
        }
      }
    }

    _outpuLessons.sort((a, b) => a['count'].compareTo(b['count']));

    return _outpuLessons;
  }

  Future<Map<String, Map<String, String>>> _loadLessonTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? lessonTimesJson =
        prefs.getString(_prefKey(prefs, 'lessontimes'));

    if (lessonTimesJson == null || lessonTimesJson.isEmpty) {
      return {};
    }

    try {
      final dynamic decoded = jsonDecode(lessonTimesJson);
      if (decoded is! List) return {};

      final Map<String, Map<String, String>> lessonTimes = {};
      for (int i = 0; i < decoded.length; i++) {
        final dynamic rawLesson = decoded[i];
        if (rawLesson is! Map) continue;

        final String count =
            rawLesson['count']?.toString() ?? (i + 1).toString();
        final String? start = _normalizeLessonTime(rawLesson['start']);
        final String? end = _normalizeLessonTime(rawLesson['end']);

        if (start != null && end != null) {
          lessonTimes[count] = {
            'start': start,
            'end': end,
          };
        }
      }
      return lessonTimes;
    } catch (_) {
      return {};
    }
  }

  String? _normalizeLessonTime(dynamic value) {
    final String time = value?.toString() ?? '';
    final RegExpMatch? match = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(time);
    if (match == null) return null;

    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;

    final int normalizedHour = hour.clamp(0, 23).toInt();
    final int normalizedMinute = minute.clamp(0, 59).toInt();
    final String hourText = normalizedHour.toString().padLeft(2, '0');
    final String minuteText = normalizedMinute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }

  Future<dynamic> getLessonsByDate({
    required DateTime date,
    required String classId,
  }) async {
    await login();

    String stringDate = parseDate(date);
    Uri url = Uri.parse(
      'https://www.stundenplan24.de/${this.schoolnumber}/mobil/mobdaten/PlanKl$stringDate.xml',
    );

    dynamic pureVPlan;
    try {
      pureVPlan = await getVPlanJSON(url, date);
    } catch (e) {
      return {'error': 'no internet'};
    }

    if (pureVPlan == null || pureVPlan.isEmpty) {
      return _emptyPlan(date);
    }
    if (pureVPlan['error'] != null) {
      return pureVPlan;
    }
    dynamic jsonVPlan =
        pureVPlan['data']['Klassen']['Kl']; //get the XML data of the URL

    Map<String, bool>? classRoomChanges;
    if (pureVPlan['roomChanges']?[classId] != null) {
      classRoomChanges =
          Map<String, bool>.from(pureVPlan['roomChanges'][classId]);
    }

    List<dynamic> lessons =
        await parseVPlanXML(jsonVPlan, classId, classRoomChanges);
    return {
      'date': pureVPlan['date'],
      'week': pureVPlan['week'],
      'data': lessons,
      'info': pureVPlan['info'],
    };
  }

  /// Lädt den rohen Vertretungsplan (mit allen Klassen) für ein bestimmtes
  /// Datum, ohne ihn für eine einzelne Klasse aufzubereiten. Wird z.B. vom
  /// Raumplan genutzt, um die Belegung aller Räume zu durchsuchen.
  ///
  /// Für heute wird wie im restlichen App-Code die 'Klassen.xml' verwendet,
  /// für andere Tage die tagesbezogene 'PlanKl<Datum>.xml'.
  Future<dynamic> getRawPlanByDate(DateTime date,
      {bool forceRefresh = false}) async {
    await login();

    DateTime today = DateTime.now();
    bool isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    Uri url;
    if (isToday) {
      url = Uri.parse(await getDayURL());
    } else {
      url = Uri.parse(
        'https://www.stundenplan24.de/${this.schoolnumber}/mobil/mobdaten/PlanKl${parseDate(date)}.xml',
      );
    }

    dynamic pureVPlan;
    try {
      pureVPlan = await getVPlanJSON(url, date, forceRefresh: forceRefresh);
    } catch (e) {
      return {'error': 'no internet'};
    }

    if (pureVPlan == null || pureVPlan.toString() == '{}') {
      return {};
    }
    return pureVPlan;
  }

  String parseDate(DateTime _date) {
    String stringDate = '';

    stringDate += '${_date.year}';
    stringDate += _date.month < 10 ? '0${_date.month}' : _date.month.toString();
    stringDate += _date.day < 10 ? '0${_date.day}' : _date.day.toString();

    return stringDate;
  }

  DateTime parseStringDatatoDateTime(String date) {
    List dateArray = date.split(',')[1].replaceAll('.', '').trim().split(' ');
    switch (dateArray[1]) {
      case 'Januar':
        dateArray[1] = '01';
        break;
      case 'Februar':
        dateArray[1] = '02';
        break;
      case 'März':
        dateArray[1] = '03';
        break;
      case 'April':
        dateArray[1] = '04';
        break;
      case 'Mai':
        dateArray[1] = '05';
        break;
      case 'Juni':
        dateArray[1] = '06';
        break;
      case 'Juli':
        dateArray[1] = '07';
        break;
      case 'August':
        dateArray[1] = '08';
        break;
      case 'September':
        dateArray[1] = '09';
        break;
      case 'Oktober':
        dateArray[1] = '10';
        break;
      case 'November':
        dateArray[1] = '11';
        break;
      case 'Dezember':
        dateArray[1] = '12';
        break;
    }

    // German dates don't zero-pad the day (e.g. "4. August"), but
    // DateTime.parse requires two digits.
    return DateTime.parse(
      '${dateArray[2]}-${dateArray[1]}-${dateArray[0].padLeft(2, '0')}',
    );
  }

  DateTime changeDate({required String date, required bool nextDay}) {
    List dateArray = date.split(',')[1].replaceAll('.', '').trim().split(' ');
    switch (dateArray[1]) {
      case 'Januar':
        dateArray[1] = '01';
        break;
      case 'Februar':
        dateArray[1] = '02';
        break;
      case 'März':
        dateArray[1] = '03';
        break;
      case 'April':
        dateArray[1] = '04';
        break;
      case 'Mai':
        dateArray[1] = '05';
        break;
      case 'Juni':
        dateArray[1] = '06';
        break;
      case 'Juli':
        dateArray[1] = '07';
        break;
      case 'August':
        dateArray[1] = '08';
        break;
      case 'September':
        dateArray[1] = '09';
        break;
      case 'Oktober':
        dateArray[1] = '10';
        break;
      case 'November':
        dateArray[1] = '11';
        break;
      case 'Dezember':
        dateArray[1] = '12';
        break;
    }

    DateTime vpDate = DateTime.parse(
      '${dateArray[2]}-${dateArray[1]}-${dateArray[0]}',
    );

    // morgen
    if (nextDay) {
      int days = 1;
      if (vpDate.weekday == 5) {
        days = 3;
      }
      vpDate = vpDate.add(Duration(days: days));
    }
    // gestern
    if (!nextDay) {
      int days = 1;
      if (vpDate.weekday == 1) {
        days = 3;
      }
      vpDate = vpDate.subtract(Duration(days: days));
    }
    return vpDate;
  }

  Future<List<String>> getClasses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getStringList(_prefKey(prefs, 'classes')) == null) {
      prefs.setStringList(_prefKey(prefs, 'classes'), []);
    }

    return prefs.getStringList(_prefKey(prefs, 'classes'))!;
  }

  // --- Sick-Track (Krankheitstracker) ---

  /// Formatiert ein Datum als ISO-String (yyyy-MM-dd) zum Speichern/Vergleichen.
  String isoDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> getSickTrackEntries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_prefKey(prefs, 'sickTrack'));
    if (data == null || data.isEmpty) {
      return [];
    }
    try {
      List<dynamic> list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error parsing sickTrack: $e');
      return [];
    }
  }

  Future<void> saveSickTrackEntries(List<Map<String, dynamic>> entries) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(_prefKey(prefs, 'sickTrack'), jsonEncode(entries));
  }

  Future<void> addSickTrackEntry(Map<String, dynamic> entry) async {
    List<Map<String, dynamic>> entries = await getSickTrackEntries();
    entries.add(entry);
    await saveSickTrackEntries(entries);
  }

  Future<void> deleteSickTrackEntry(String entryId) async {
    List<Map<String, dynamic>> entries = await getSickTrackEntries();
    entries.removeWhere((e) => e['id'] == entryId);
    await saveSickTrackEntries(entries);
  }

  /// Kurse, deren Unterschrift(en) für diesen Krankheitseintrag bereits als
  /// erledigt (abgeholt) markiert wurden.
  Future<Set<String>> getDoneSignatures(String entryId) async {
    List<Map<String, dynamic>> entries = await getSickTrackEntries();
    for (var entry in entries) {
      if (entry['id'].toString() == entryId) {
        return ((entry['signaturesDone'] as List?) ?? [])
            .cast<String>()
            .toSet();
      }
    }
    return {};
  }

  /// Markiert die Unterschrift(en) eines Kurses für einen Krankheitseintrag
  /// als erledigt (abgeholt). Wird im Vertretungsplan aufgerufen, wenn der
  /// Nutzer das Stiftsymbol antippt und bestätigt.
  Future<void> markSignatureDone(String entryId, String course) async {
    List<Map<String, dynamic>> entries = await getSickTrackEntries();
    for (var entry in entries) {
      if (entry['id'].toString() == entryId) {
        List<String> done =
            ((entry['signaturesDone'] as List?) ?? []).cast<String>();
        if (!done.contains(course)) done.add(course);
        entry['signaturesDone'] = done;
        break;
      }
    }
    await saveSickTrackEntries(entries);
  }

  /// Erkennt, ob ein Plan-Eintrag eine ausgefallene Stunde ist (der
  /// Info-Text enthält z.B. „Entfall“, „Ausfall“, „ausgefallen“ oder
  /// „… fällt aus“). Ausgefallene Stunden zählen im Sick-Track nicht als
  /// verpasst – in diesem Kurs war man nicht abwesend.
  bool isCancelledLesson(dynamic lesson) {
    String? info = lesson?['info']?.toString();
    if (info == null || info.trim().isEmpty) return false;
    String t = info
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    if (RegExp(r'\b(entfall|entfallt|entfaellt|ausfall|ausgefallen)\b')
        .hasMatch(t)) {
      return true;
    }
    // Varianten wie „fällt heute aus“ / „fällt wegen … aus“.
    return RegExp(r'\b(fallt|faellt)\b').hasMatch(t) &&
        RegExp(r'\baus\b').hasMatch(t);
  }

  /// Ermittelt alle verpassten Stunden eines Krankheitszeitraums:
  /// für jeden ausgewählten Tag wird der (gespeicherte oder neu geladene)
  /// Vertretungsplan der Klasse durchsucht und alle Stunden der gewählten
  /// Kurse als verpasst markiert. Ausgefallene Stunden zählen nicht als
  /// verpasst.
  Future<List<Map<String, dynamic>>> getMissedLessons(
      Map<String, dynamic> entry) async {
    List<Map<String, dynamic>> missed = [];
    List<String> days = (entry['days'] as List?)?.cast<String>() ?? [];
    List<String> courses = (entry['courses'] as List?)?.cast<String>() ?? [];
    String classId = entry['classId']?.toString() ?? '';

    for (String day in days) {
      DateTime date;
      try {
        date = DateTime.parse(day);
      } catch (e) {
        continue;
      }

      dynamic plan;
      try {
        plan = await getLessonsByDate(date: date, classId: classId);
      } catch (e) {
        plan = null;
      }
      if (plan == null || plan['error'] != null || plan['data'] == null) {
        continue;
      }

      List<dynamic> lessons = plan['data'];
      for (var lesson in lessons) {
        // Ausgefallene Stunden („Entfall“, „… fällt aus“) wurden nicht
        // versäumt – dafür braucht man keine Unterschrift.
        if (isCancelledLesson(lesson)) continue;
        String course = lesson['course']?.toString() ?? '';
        if (course.isEmpty || course == '---') {
          course = lesson['lesson']?.toString() ?? '';
        }
        if (!courses.contains(course)) continue;
        missed.add({
          'date': day,
          'count': lesson['count']?.toString() ?? '',
          'lesson': lesson['lesson']?.toString() ?? '',
          'course': course,
          'teacher': lesson['teacher']?.toString() ?? '',
          'place': lesson['place']?.toString() ?? '',
          'begin': lesson['begin']?.toString() ?? '',
          'end': lesson['end']?.toString() ?? '',
          'info': lesson['info']?.toString(),
        });
      }
    }

    missed.sort((a, b) {
      int c = (a['date'] as String).compareTo(b['date'] as String);
      if (c != 0) return c;
      int aCount = int.tryParse(a['count']) ?? 0;
      int bCount = int.tryParse(b['count']) ?? 0;
      return aCount.compareTo(bCount);
    });
    return missed;
  }

  /// Liefert die Kurse, die am angezeigten Tag für eine Klasse das
  /// Stiftsymbol („Unterschrift holen“) bekommen, zusammen mit der Anzahl
  /// der dafür benötigten Unterschriften (Anzahl der verpassten Stunden des
  /// Kurses). Wird im Vertretungsplan genutzt, um das Stiftsymbol
  /// anzuzeigen.
  ///
  /// Das Stiftsymbol erscheint, wenn
  /// - der angezeigte Tag selbst ein Krankheitstag ist (alle Kurse des
  ///   Zeitraums wurden an diesem Tag verpasst) oder
  /// - der angezeigte Tag die **nächste Stunde** eines Kurses nach dem Ende
  ///   des Krankheitszeitraums ist – genau dort muss die Unterschrift
  ///   eingeholt werden.
  Future<Map<String, int>> getMissedCoursesForDate(
      String classId, DateTime date) async {
    Map<String, Map<String, dynamic>> details =
        await getMissedCourseDetailsForDate(classId, date);
    return details.map((course, d) => MapEntry(course, d['count'] as int));
  }

  /// Wie [getMissedCoursesForDate], liefert aber zusätzlich zu jedem Kurs die
  /// IDs der Krankheitseinträge, aus denen das Stiftsymbol stammt – damit die
  /// Unterschrift im Vertretungsplan als erledigt markiert werden kann.
  ///
  /// Rückgabe: { Kurs: { 'count': int, 'entryIds': [String, ...] } }
  Future<Map<String, Map<String, dynamic>>> getMissedCourseDetailsForDate(
      String classId, DateTime date) async {
    Map<String, Map<String, dynamic>> missed = {};
    String iso = isoDate(date);
    List<Map<String, dynamic>> entries = await getSickTrackEntries();
    for (var entry in entries) {
      if (entry['classId']?.toString() != classId) continue;
      List<String> days = (entry['days'] as List?)?.cast<String>() ?? [];
      if (days.isEmpty) continue;
      List<String> courses = (entry['courses'] as List?)?.cast<String>() ?? [];
      if (courses.isEmpty) continue;

      // Kurse, deren Unterschrift bereits als erledigt markiert wurde,
      // bekommen für diesen Eintrag kein Stiftsymbol mehr.
      Set<String> done = await getDoneSignatures(entry['id'].toString());
      courses = courses.where((c) => !done.contains(c)).toList();
      if (courses.isEmpty) continue;

      // Nur tatsächlich verpasste Stunden zählen (ausgefallene Stunden
      // nicht) – eine Unterschrift pro verpasster Stunde.
      List<Map<String, dynamic>> missedLessons = await getMissedLessons(entry);
      Map<String, int> counts = {};
      for (var m in missedLessons) {
        String course = m['course']?.toString() ?? '';
        counts[course] = (counts[course] ?? 0) + 1;
      }

      // Kurse, die am angezeigten Tag das Stiftsymbol bekommen.
      Set<String> toShow = {};

      // Krankheitstag selbst: Nur die Kurse, die an diesem Tag tatsächlich
      // eine (nicht ausgefallene) Stunde hatten, wurden verpasst – nicht
      // alle Kurse, an denen man generell teilnimmt.
      if (days.contains(iso)) {
        for (var m in missedLessons) {
          if (m['date'] == iso && courses.contains(m['course'])) {
            toShow.add(m['course'] as String);
          }
        }
      } else {
        // Nach dem Krankheitszeitraum: Das Stiftsymbol erscheint nur an der
        // nächsten Stunde des Kurses. Dafür wird ab dem Tag nach dem letzten
        // Krankheitstag vor dem angezeigten Tag gescannt, wann der Kurs zum
        // ersten Mal wieder im Plan auftaucht – nur dieser Tag bekommt das
        // Symbol. Ausgefallene Stunden zählen dabei nicht als „nächste
        // Stunde“.
        days.sort();
        // Letzter Krankheitstag, der vor dem angezeigten Tag liegt.
        String? lastSickBefore;
        for (final d in days) {
          if (d.compareTo(iso) < 0) lastSickBefore = d;
        }
        if (lastSickBefore == null) continue; // vor dem Krankheitszeitraum

        DateTime lastSick;
        try {
          lastSick = DateTime.parse(lastSickBefore);
        } catch (e) {
          continue;
        }
        // Nur kurze Zeit nach der Krankheit erinnern, sonst würde ein alter
        // Eintrag bei jedem Planaufruf viele Tage abfragen.
        if (date.difference(lastSick).inDays > 14) continue;

        Set<String> pending = Set.from(courses);
        DateTime cursor = lastSick.add(const Duration(days: 1));
        while (!cursor.isAfter(date) && pending.isNotEmpty) {
          // Wochenenden überspringen (keine Pläne/Stunden).
          if (cursor.weekday == DateTime.saturday ||
              cursor.weekday == DateTime.sunday) {
            cursor = cursor.add(const Duration(days: 1));
            continue;
          }
          dynamic plan;
          try {
            plan = await getLessonsByDate(date: cursor, classId: classId);
          } catch (e) {
            plan = null;
          }
          if (plan != null && plan['error'] == null && plan['data'] != null) {
            Set<String> onThisDay = {};
            for (var lesson in plan['data']) {
              // Ausgefallene Stunde ist nicht die nächste Stunde des Kurses.
              if (isCancelledLesson(lesson)) continue;
              String course = lesson['course']?.toString() ?? '';
              if (course.isEmpty || course == '---') {
                course = lesson['lesson']?.toString() ?? '';
              }
              if (pending.contains(course)) onThisDay.add(course);
            }
            if (isoDate(cursor) == iso) {
              // Der angezeigte Tag ist die erste Stunde nach der Krankheit.
              toShow.addAll(onThisDay);
            }
            pending.removeAll(onThisDay);
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }

      if (toShow.isEmpty) continue;

      for (String c in toShow) {
        int? count = counts[c];
        // Nur Kurse, die tatsächlich verpasst wurden, bekommen das Symbol –
        // Kurse ohne verpasste Stunde (z.B. weil sie am Krankheitstag gar
        // keine Stunde hatten) nicht.
        if (count == null || count <= 0) continue;
        Map<String, dynamic> details =
            missed[c] ??= {'count': 0, 'entryIds': <String>[]};
        details['count'] = (details['count'] as int) + count;
        (details['entryIds'] as List).add(entry['id'].toString());
      }
    }
    return missed;
  }

  // Local plans are kept for at least 14 days so the user can navigate back
  // in time. Plans older than that are pruned during cleanup.
  static const int offlinePlanRetentionDays = 14;

  Future<void> cleanVplanOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? offlineVPData =
        prefs.getStringList(_prefKey(prefs, 'offlineVPData'));

    if (offlineVPData == null || offlineVPData == []) {
      return;
    }

    List<dynamic> vplanData = [];
    for (int i = 0; i < offlineVPData.length; i++) {
      vplanData.add(jsonDecode(offlineVPData[i]));
    }
    List<dynamic> cleanedPlan = [];
    DateTime today = DateTime.now();

    for (int i = 0; i < vplanData.length; i++) {
      // Skip plans older than the retention period (future plans are kept).
      DateTime? planDate;
      try {
        planDate = parseStringDatatoDateTime(
          vplanData[i]['data']['Kopf']['DatumPlan'],
        );
      } catch (e) {
        planDate = null;
      }
      if (planDate != null &&
          today.difference(planDate).inDays > offlinePlanRetentionDays) {
        continue;
      }

      bool addIt = true;
      for (int j = 0; j < cleanedPlan.length; j++) {
        if (cleanedPlan[j]['data']['Kopf']['DatumPlan'] ==
            vplanData[i]['data']['Kopf']['DatumPlan']) {
          addIt = false;
        }
      }
      if (addIt) cleanedPlan.add(vplanData[i]);
    }
    prefs.setStringList(
      _prefKey(prefs, 'offlineVPData'),
      cleanedPlan.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<List<String>> getTeachers() async {
    await login();

    if (_isDemoMode) {
      return DemoData.teacherShorts;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get teachers from the courses data (all teachers who teach any course)
    List<String> allTeachers = [];
    dynamic vplanData = await getVPlanJSON(
      Uri.parse(await getDayURL()),
      DateTime.now(),
    );

    if (vplanData != null && vplanData['courses'] != null) {
      List<dynamic> courses = vplanData['courses'];
      for (int i = 0; i < courses.length; i++) {
        String? teacher = courses[i]['teacher']?.toString();
        if (teacher != null &&
            teacher.isNotEmpty &&
            !allTeachers.contains(teacher)) {
          allTeachers.add(teacher);
        }
      }
    }

    // Sort the teachers alphabetically
    allTeachers.sort();

    // Check if we have stored teacher data
    if (prefs.getString(_prefKey(prefs, 'teacherShorts')) != null &&
        prefs.getString(_prefKey(prefs, 'teacherShorts')) != '') {
      List<dynamic> storedTeachers =
          jsonDecode(prefs.getString(_prefKey(prefs, 'teacherShorts'))!);
      List<String> storedShorts =
          storedTeachers.map((teacher) => teacher['short'] as String).toList();

      // Add any new teachers from courses to stored data
      bool hasNewTeachers = false;
      for (String teacher in allTeachers) {
        if (!storedShorts.contains(teacher)) {
          storedTeachers.add({'short': teacher, 'realName': ''});
          hasNewTeachers = true;
        }
      }

      // Save updated list if new teachers were added
      if (hasNewTeachers) {
        prefs.setString(
            _prefKey(prefs, 'teacherShorts'), jsonEncode(storedTeachers));
      }

      return storedTeachers
          .map((teacher) => teacher['short'] as String)
          .toList();
    } else {
      // No stored data exists, store all teachers from courses
      List<dynamic> newStoredTeachers = [];
      for (String teacher in allTeachers) {
        newStoredTeachers.add({'short': teacher, 'realName': ''});
      }
      prefs.setString(
          _prefKey(prefs, 'teacherShorts'), jsonEncode(newStoredTeachers));
      return allTeachers;
    }
  }

  Future<String?> replaceTeacherShort(String? teacherShort) async {
    if (teacherShort == null) return teacherShort;

    if (_isDemoMode) {
      return DemoData.teacherName(teacherShort) ?? teacherShort;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getString(_prefKey(prefs, 'teacherShorts')) == null ||
        prefs.getString(_prefKey(prefs, 'teacherShorts')) == '')
      return teacherShort;

    List<dynamic> teacherShorts =
        jsonDecode(prefs.getString(_prefKey(prefs, 'teacherShorts'))!);

    for (int i = 0; i < teacherShorts.length; i++) {
      if (teacherShorts[i]['short'] == teacherShort) {
        if (teacherShorts[i]['realName'] != '')
          return teacherShorts[i]['realName'];
      }
    }
    return teacherShort;
  }
}
