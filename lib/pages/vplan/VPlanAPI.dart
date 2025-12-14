import 'dart:convert';

import 'package:http_auth/http_auth.dart' as http_auth;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml2json/xml2json.dart';
import 'package:xml/xml.dart';

class VPlanAPI {
  int schoolnumber = 0; // = prefs.getString("vplanSchoolnumber");
  String vplanUsername = ''; // = prefs.getString("vplanUsername");
  String vplanPassword = ''; // = prefs.getString("vplanPassword");

  Future<void> login() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getString('customUrl') != null &&
        prefs.getString('customUrl') != '') {
      return;
    }
    schoolnumber = int.parse(prefs.getString("vplanSchoolnumber")!);
    vplanUsername = prefs.getString("vplanUsername")!;
    vplanPassword = prefs.getString("vplanPassword")!;
  }

  Future<dynamic> getClassList() async {
    this.login();

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

  void addHiddenCourse(String lesson) async {
    if (lesson == '---') {
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? hiddenSubjects = prefs.getStringList('hiddenSubjects');
    if (hiddenSubjects == null) {
      hiddenSubjects = [];
    }
    hiddenSubjects.add(lesson);

    prefs.setStringList('hiddenSubjects', hiddenSubjects);
  }

  void removeHiddenCourse(String course) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? hiddenSubjects = prefs.getStringList('hiddenSubjects');
    if (hiddenSubjects == null) {
      hiddenSubjects = [];
    }
    List<String> newCourses = [];

    for (int i = 0; i < hiddenSubjects.length; i++) {
      if (course != hiddenSubjects[i]) {
        newCourses.add(hiddenSubjects[i]);
      }
    }

    prefs.setStringList('hiddenSubjects', newCourses);
  }

  Future<List<String>> getHiddenCourses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? hiddenSubjects = prefs.getStringList('hiddenSubjects');
    if (hiddenSubjects == null) {
      hiddenSubjects = [];
    }

    return hiddenSubjects;
  }

  Future<List<dynamic>> getShownCourses(String classId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? hiddenSubjects = prefs.getStringList('hiddenSubjects');
    if (hiddenSubjects == null) {
      hiddenSubjects = [];
    }

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
    if (prefs.getStringList('offlineVPData') == null ||
        prefs.getStringList('offlineVPData') == []) {
      return false;
    }
    List<dynamic> jsonData = [];

    jsonData = prefs
        .getStringList('offlineVPData')!
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

  void removePlanByDate(String date) async {
    this.cleanVplanOfflineData();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<dynamic> vplanData = [];
    prefs
        .getStringList('offlineVPData')!
        .map((e) => vplanData.add(jsonDecode(e)));

    List<String> newVplanData = [];
    for (int i = 0; i < vplanData.length; i++) {
      if (vplanData[i]['date'] != date) {
        newVplanData.add(jsonEncode(vplanData[i]));
      }
    }
    prefs.setStringList('offlineVPData', newVplanData);
  }

  Future<dynamic> getAllOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? offlineVPData = prefs.getStringList('offlineVPData');

    if (offlineVPData == null) {
      return [];
    } else {
      // print('offlineVPData');
      return offlineVPData.map((e) => jsonDecode(e));
    }
  }

  Future<List<dynamic>> getCourses(String classId) async {
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

  Future<dynamic> getVPlanJSON(Uri url, DateTime vpDate, {bool forceRefresh = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<dynamic> data = [];

    // Check TTL cache first unless force refresh is requested
    if (!forceRefresh) {
      String cacheKey = 'vplan_cache_${vpDate.year}-${vpDate.month.toString().padLeft(2, '0')}-${vpDate.day.toString().padLeft(2, '0')}';
      String? cachedData = prefs.getString(cacheKey);
      int? cacheTime = prefs.getInt('${cacheKey}_time');
      
      if (cachedData != null && cacheTime != null) {
        int cacheTTL = prefs.getInt('vplanCacheTTL') ?? 300; // 5 minutes default
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
    await login();
    var client;

    if (prefs.getString('customUrl') != null &&
        prefs.getString('customUrl') != '') {
      if (url.toString().contains('PlanKl')) {
        // For dated requests, append the path to customUrl
        String path = url.path;
        url = Uri.parse(prefs.getString('customUrl')! + path);
      } else {
        url = Uri.parse(prefs.getString('customUrl')! + 'mobdaten/Klassen.xml');
      }
    } else {
      client = http_auth.BasicAuthClient(vplanUsername, vplanPassword);
    }
    try {
      return ((prefs.getString('customUrl') != null &&
                  prefs.getString('customUrl') != '')
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
        var lastNotEmpty =
            infoList.lastIndexWhere((s) => s.trim().isNotEmpty);
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
        List<String>? stringData = prefs.getStringList('offlineVPData');
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

        prefs.setStringList('offlineVPData', stringData);
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

    if (pureVPlan == {}) {
      return {};
    }
    if (pureVPlan['error'] != null) {
      return pureVPlan;
    }

    var jsonVPlan =
        pureVPlan['data']['Klassen']['Kl']; //get the XML data of the URL
    
    Map<String, bool>? classRoomChanges;
    if (pureVPlan['roomChanges']?[classId] != null) {
      classRoomChanges = Map<String, bool>.from(pureVPlan['roomChanges'][classId]);
    }

    List<dynamic> lessons = await parseVPlanXML(jsonVPlan, classId, classRoomChanges);
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

  Future<List<dynamic>> parseVPlanXML(dynamic jsonVPlan, String classId, [Map<String, bool>? roomChanges]) async {
    List<dynamic> _outpuLessons = [];

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
          bool placeChanged = roomChanges?[lessonCount] ?? false;
          
          _outpuLessons.add({
            'count': currentLesson['St'],
            'lesson': currentLesson['Fa'],
            'teacher': await replaceTeacherShort(currentLesson['Le']),
            'place': currentLesson['Ra'],
            'placeChanged': placeChanged,
            'begin': currentLesson['Beginn'],
            'end': currentLesson['Ende'],
            'info': currentLesson['If'],
            'course': currentLesson['Ku2'],
          });
        }
      }
    }


    _outpuLessons.sort((a, b) => a['count'].compareTo(b['count']));

    return _outpuLessons;
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

    if (pureVPlan.toString() == '{}') {
      return {};
    }
    if (pureVPlan['error'] != null) {
      return pureVPlan;
    }
    dynamic jsonVPlan =
        pureVPlan['data']['Klassen']['Kl']; //get the XML data of the URL
    
    Map<String, bool>? classRoomChanges = pureVPlan['roomChanges']?[classId];

    List<dynamic> lessons = await parseVPlanXML(jsonVPlan, classId, classRoomChanges);
    return {
      'date': pureVPlan['date'],
      'week': pureVPlan['week'],
      'data': lessons,
      'info': pureVPlan['info'],
    };
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

    return DateTime.parse(
      '${dateArray[2]}-${dateArray[1]}-${dateArray[0]}',
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

    if (prefs.getStringList('classes') == null) {
      prefs.setStringList('classes', []);
    }

    return prefs.getStringList('classes')!;
  }

  void cleanVplanOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? offlineVPData = prefs.getStringList('offlineVPData');

    if (offlineVPData == null || offlineVPData == []) {
      return;
    }

    List<dynamic> vplanData = [];
    for (int i = 0; i < offlineVPData.length; i++) {
      vplanData.add(jsonDecode(offlineVPData[i]));
    }
    List<dynamic> cleanedPlan = [];

    for (int i = 0; i < vplanData.length; i++) {
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
      'offlineVPData',
      cleanedPlan.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<List<String>> getTeachers() async {
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
        String teacher = courses[i]['teacher'];
        if (teacher != null && teacher.isNotEmpty && !allTeachers.contains(teacher)) {
          allTeachers.add(teacher);
        }
      }
    }

    // Sort the teachers alphabetically
    allTeachers.sort();

    // Check if we have stored teacher data
    if (prefs.getString('teacherShorts') != null &&
        prefs.getString('teacherShorts') != '') {
      List<dynamic> storedTeachers = jsonDecode(prefs.getString('teacherShorts')!);
      List<String> storedShorts = storedTeachers.map((teacher) => teacher['short'] as String).toList();

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
        prefs.setString('teacherShorts', jsonEncode(storedTeachers));
      }

      return storedTeachers.map((teacher) => teacher['short'] as String).toList();
    } else {
      // No stored data exists, store all teachers from courses
      List<dynamic> newStoredTeachers = [];
      for (String teacher in allTeachers) {
        newStoredTeachers.add({'short': teacher, 'realName': ''});
      }
      prefs.setString('teacherShorts', jsonEncode(newStoredTeachers));
      return allTeachers;
    }
  }

  Future<String?> replaceTeacherShort(String? teacherShort) async {
    if (teacherShort == null) return teacherShort;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (prefs.getString('teacherShorts') == null ||
        prefs.getString('teacherShorts') == '') return teacherShort;

    List<dynamic> teacherShorts = jsonDecode(prefs.getString('teacherShorts')!);

    for (int i = 0; i < teacherShorts.length; i++) {
      if (teacherShorts[i]['short'] == teacherShort) {
        if (teacherShorts[i]['realName'] != '')
          return teacherShorts[i]['realName'];
      }
    }
    return teacherShort;
  }
}
