import 'package:flutter/material.dart';

import '../../../models/ListItem.dart';
import '../../../models/ListPage.dart';

import '../../vplan/VPlanAPI.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../background_service.dart';

class Notifications extends StatefulWidget {
  const Notifications({Key? key}) : super(key: key);

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  Widget heading(String text) => Container(
        margin: EdgeInsets.all(13),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: !_automaticLoad ? Colors.grey.shade500 : null,
          ),
        ),
      );

  bool _automaticLoad = false;
  bool _intiligentNotification = false;
  String _prefClass = '';
  int? _hour;
  int? _minute;
  bool _remindDayBefore = true;
  int? _interval;
  bool _remindOnlyChange = true;
  bool _isHours = false;

  List<String> _classes = [];

  void restartBackgroundSevice() {
    FlutterBackgroundService().sendData({'action': 'restartTimer'});
  }

  void changeAutomaticLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _automaticLoad = !_automaticLoad;
    prefs.setBool('automaticLoad', _automaticLoad);
    setState(() {});

    if (_automaticLoad) {
      FlutterBackgroundService.initialize(onStart);
    } else {
      FlutterBackgroundService().sendData({'action': 'stopService'});
    }

    // peset if all is null
    if (prefs.getString('prefClass') == null)
      prefs.setString(
          'prefClass', (await VPlanAPI().getClasses())[0].toString());
    if (prefs.getString('hour') == null) prefs.setString('hour', '0');
    if (prefs.getString('minute') == null) prefs.setString('minute', '0');
    if (prefs.getBool('remindDayBefore') == null)
      prefs.setBool('remindDayBefore', true);
    if (prefs.getBool('intiligentNotification') == null)
      prefs.setBool('intiligentNotification', false);
    if (prefs.getInt('interval') == null) prefs.setInt('interval', 300);
    if (prefs.getBool('remindOnlyChange') == null)
      prefs.setBool('remindOnlyChange', true);
  }

  void changeNotification() async {
    if (!_automaticLoad) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _intiligentNotification = !_intiligentNotification;
    prefs.setBool('intiligentNotification', _intiligentNotification);
    setState(() {});
    restartBackgroundSevice();
  }

  void changeTime() async {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    _hour = time.hour;
    _minute = time.minute;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('hour', _hour.toString());
    prefs.setString('minute', _minute.toString());
    setState(() {});
    restartBackgroundSevice();
  }

  void changeRemindDayBefore() async {
    if (!_automaticLoad) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _remindDayBefore = !_remindDayBefore;
    prefs.setBool('remindDayBefore', _remindDayBefore);
    setState(() {});
    restartBackgroundSevice();
  }

  void changeRemindOnlyChange() async {
    if (!_automaticLoad) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _remindOnlyChange = !_remindOnlyChange;
    prefs.setBool('remindOnlyChange', _remindOnlyChange);
    setState(() {});
    restartBackgroundSevice();
  }

  void getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _classes = await VPlanAPI().getClasses();

    _automaticLoad = prefs.getBool('automaticLoad') ?? false;
    _intiligentNotification = prefs.getBool('intiligentNotification') ?? false;
    _prefClass = prefs.getString('prefClass') ?? _classes[0];
    _hour = int.parse(prefs.getString('hour') ?? '0');
    _minute = int.parse(prefs.getString('minute') ?? '0');
    _remindDayBefore = prefs.getBool('remindDayBefore') ?? true;
    _interval = prefs.getInt('interval') ?? 300;
    _remindOnlyChange = prefs.getBool('remindOnlyChange') ?? true;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListPage(
          title: 'Notifications',
          children: [
            heading('General'),
            ListItem(
              title: Text('Load Substitution plan automatically'),
              onClick: () => changeAutomaticLoad(),
              actionButton: Switch.adaptive(
                value: _automaticLoad,
                onChanged: (change) => changeAutomaticLoad(),
                activeColor: Theme.of(context).accentColor,
              ),
            ),
            ListItem(
              title: Text(
                'Smart Notifications',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: changeNotification,
              actionButton: Switch.adaptive(
                value: _intiligentNotification,
                onChanged: (change) => changeNotification(),
                activeColor: Theme.of(context).accentColor,
              ),
            ),
            ListItem(
              title: Text(
                'Preferred Classes',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              onClick: () {},
              color: !_automaticLoad ? Color(0xff161616) : null,
              actionButton: DropdownButton(
                onChanged: (change) async {
                  setState(() => _prefClass = change.toString());
                  SharedPreferences.getInstance().then(
                    (instance) => instance.setString('prefClass', _prefClass),
                  );
                  restartBackgroundSevice();
                },
                value: _prefClass,
                dropdownColor: Theme.of(context).backgroundColor,
                icon: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 15,
                    color: !_automaticLoad ? Colors.grey.shade500 : null,
                  ),
                ),
                items: [
                  ..._classes.map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_automaticLoad ? Colors.grey.shade500 : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---------------------
            /* heading('Zeit der Erinnerung'),
            ListItem(
              title: Text(
                'Stunde',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: changeTime,
              actionButton: _hour == null
                  ? Icon(
                      Icons.schedule_rounded,
                      color: !_automaticLoad ? Colors.grey.shade500 : null,
                    )
                  : Text('${_hour}h'),
            ),
            ListItem(
              title: Text(
                'Minute',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: changeTime,
              actionButton: _hour == null
                  ? Icon(
                      Icons.schedule_rounded,
                      color: !_automaticLoad ? Colors.grey.shade500 : null,
                    )
                  : Text('${_minute}m'),
            ),
            ListItem(
              title: Text(
                'Erinnerung am Tag davor',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: () {},
              actionButton: Switch.adaptive(
                value: _remindDayBefore,
                onChanged: (change) => changeRemindDayBefore(),
                activeColor: Theme.of(context).accentColor,
              ),
            ), */
            // ---------------------
            heading('Other'),
            ListItem(
              title: Text(
                'Call interval',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: () => showDialog(
                context: context,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: AlertDialog(
                    title: heading('Call interval'),
                    content: StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                          child: Column(
                            children: [
                              Slider(
                                onChanged: (change) {
                                  setState(() {
                                    _interval = _isHours
                                        ? change.toInt() * 3600
                                        : change.toInt() * 60;
                                  });
                                },
                                onChangeEnd: (change) {
                                  SharedPreferences.getInstance().then(
                                    (instance) => instance.setInt(
                                        'interval',
                                        _isHours
                                            ? change.toInt() * 3600
                                            : change.toInt() * 60),
                                  );
                                  restartBackgroundSevice();
                                },
                                value: _isHours
                                    ? ((_interval ?? 3600) / 3600).toDouble()
                                    : ((_interval ?? 300) / 60).toDouble(),
                                max: _isHours ? 24 : 60,
                                min: 1,
                                label: _isHours
                                    ? '${(_interval ?? 3600) ~/ 3600}h'
                                    : '${(_interval ?? 300) ~/ 60}min',
                                divisions: _isHours ? 24 : 60,
                                activeColor: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.8),
                                inactiveColor: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.1),
                                thumbColor: Theme.of(context).accentColor,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Minutes'),
                                  Switch(
                                    value: _isHours,
                                    onChanged: (value) {
                                      setState(() {
                                        _isHours = value;
                                      });
                                    },
                                    activeColor:
                                        Theme.of(context).accentColor,
                                  ),
                                  Text('Hours'),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ],
                    backgroundColor: Theme.of(context).backgroundColor,
                  ),
                ),
              ),
              actionButton: Text(
                _isHours
                    ? '${(_interval ?? 3600) ~/ 3600}h'
                    : '${(_interval ?? 300) ~/ 60}min',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
            ),
            ListItem(
              title: Text(
                'Only remind when lesson changes',
                style: TextStyle(
                  color: !_automaticLoad ? Colors.grey.shade500 : null,
                ),
              ),
              color: !_automaticLoad ? Color(0xff161616) : null,
              onClick: changeRemindOnlyChange,
              actionButton: Switch.adaptive(
                value: _remindOnlyChange,
                onChanged: (change) => changeRemindOnlyChange(),
                activeColor: Theme.of(context).accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
