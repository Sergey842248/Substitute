import 'dart:async';
import 'dart:math';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:expandiware/pages/vplan/VPlanAPI.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

Timer? _timer;

@pragma('vm:entry-point')
Future<bool> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: false,
      notificationChannelId: 'my-foreground',
      initialNotificationTitle: 'Expandiware Service',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    )
  );

  return service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  if (prefs.getBool('automaticLoad') == false) {
    service.stopSelf();
    return;
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      _timer?.cancel();
      service.stopSelf();
    });

    service.on('restartTimer').listen((event) {
      _timer?.cancel();
      startTimer();
    });
  }

  startTimer();
}

void startTimer() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getInt('interval') == null) prefs.setInt('interval', 300);
  int _interval = prefs.getInt('interval')!;
  _timer = Timer.periodic(Duration(seconds: _interval), vplanNotifications);
}

void vplanNotifications(Timer timer) async {
  print('background process');
  SharedPreferences prefs = await SharedPreferences.getInstance();

  if (prefs.getBool('automaticLoad') == false) {
    return;
  }

  if (prefs.getString('prefClass') == null)
    prefs.setString('prefClass', (await VPlanAPI().getClasses())[0].toString());
  if (prefs.getString('hour') == null) prefs.setString('hour', '0');
  if (prefs.getString('minute') == null) prefs.setString('minute', '0');
  if (prefs.getBool('remindDayBefore') == null)
    prefs.setBool('remindDayBefore', true);
  if (prefs.getBool('remindOnlyChange') == null)
    prefs.setBool('remindOnlyChange', true);

  String _classId = prefs.getString('prefClass')!;
  DateTime _today = DateTime.now();
  int _remindHour = int.parse(prefs.getString('hour')!);
  int _remindMinutes = int.parse(prefs.getString('minute')!);
  bool _remindDayBefore = prefs.getBool('remindDayBefore')!;
  DateTime _vplanDate;
  bool _remindOnlyChange = prefs.getBool('remindOnlyChange')!;

  dynamic data = await VPlanAPI().getLessonsForToday(_classId);

  if (data == null || data.toString() == '{}') {
    // no school today
    data = await VPlanAPI().getLessonsByDate(
      date: _today.add(Duration(days: 1)),
      classId: _classId,
    );
    if (data == null || data.toString() == '{}') {
      // no school tomorrow
      return;
    }
  }
  if (!prefs.getBool('intiligentNotification')!) return;

  _vplanDate = VPlanAPI().parseStringDatatoDateTime(data['date']);
  List<dynamic> _lessons = [];
  if (_remindDayBefore) {
    if (_today.difference(_vplanDate) <= Duration(days: 1)) {
      List<String> _courses = await VPlanAPI().getHiddenCourses();
      for (int i = 0; i < data['data'].length; i++) {
        if (!_courses.contains(data['data'][i]['course'])) {
          _lessons.add(data['data'][i]);
        }
      }
    }
  } else {
    // not _remindDayBefore
    if (_today.day == _vplanDate.day &&
        _today.month == _vplanDate.month &&
        _today.year == _vplanDate.year) {
      if (_today.hour == _remindHour && _today.minute == _remindMinutes) {
        List<String> _courses = await VPlanAPI().getHiddenCourses();
        for (int i = 0; i < data['data'].length; i++) {
          if (!_courses.contains(data['data'][i]['course'])) {
            _lessons.add(data['data'][i]);
          }
        }
      }
    }
  }

  _lessons = _lessons.reversed.toList();

  bool reminded = false;

  if (prefs.getStringList('notified') == null)
    prefs.setStringList('notified', []);

  if (!prefs.getStringList('notified')!.contains(data['date'])) {
    for (int i = 0; i < _lessons.length; i++) {
      if (!_remindOnlyChange) {
        reminded = true;
        try {
          createNotification(
            id: i,
            title: _lessons[i]['lesson'],
            body:
                '${_lessons[i]['place']} ${(_lessons[i]['teacher'] == null ? 'without teacher' : _lessons[i]['teacher'])}',
            subtitle: 'Substitute',
          );
        } catch (e) {
          createNotification(
            title: 'exception',
            body: e.toString(),
            subtitle: 'Substitute',
            normal: true,
          );
        }
      } else {
        if (!(_lessons[i]['info'] == '' || _lessons[i]['info'] == null)) {
          reminded = true;
          //try {
          String lesson =
              _lessons[i]['lesson'] != null ? _lessons[i]['lesson'] : '---';
          String teacher = _lessons[i]['teacher'] != null
              ? _lessons[i]['teacher']
              : 'ohne Lehrer';
          String place =
              _lessons[i]['place'] != null ? _lessons[i]['place'] : 'No room';
          String info = _lessons[i]['info'] != null
              ? _lessons[i]['info']
              : 'No additional information';

          if ((_lessons[i]['lesson'] == null ||
                  _lessons[i]['lesson'] == '---') &&
              _lessons[i]['teacher'] == null &&
              _lessons[i]['place'] == null) {
            createNotification(
              id: i,
              title: _lessons[i]['count'] + ' $info',
              body: '-',
              subtitle: 'Substitute',
            );
          } else {
            createNotification(
              id: i,
              title: '$lesson $teacher $place',
              body: info,
              subtitle: 'Substitute',
            );
          }
        }
      }
    }

    if (!reminded) {
      createNotification(
        id: 10000000,
        title: 'keine Veränderungen (${_vplanDate.day}.${_vplanDate.month})',
        body: ' ',
        subtitle: 'expandiware',
        normal: true,
      );
    }

    List<String> _addList = prefs.getStringList('notified')!;
    _addList.add(data['date']);
    prefs.setStringList('notified', _addList);
  }
}

void createNotification({
  required String title,
  required String body,
  required String subtitle,
  bool? normal,
  int? id,
}) {
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'vplan_notification',
        channelName: 'Vertretungsplan Benachrichtigungen',
        channelDescription: 'Benachrichtigungen zu Änderungen und Fächern',
      )
    ],
  );
  id ??= Random().nextInt(100000000);
  normal ??= false;

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: id,
      channelKey: 'vplan_notification',
      title: title,
      body: body,
      summary: subtitle,
      color: Colors.transparent,
      notificationLayout:
          normal ? NotificationLayout.BigText : NotificationLayout.Messaging,
    ),
  );
}
