import 'package:expandiware/models/ListItem.dart';
import 'package:expandiware/models/ListPage.dart';
import 'package:expandiware/models/LoadingProcess.dart';
import 'package:expandiware/models/ProcessBar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';

import '../vplan/VPlanAPI.dart';

class FindRoom extends StatefulWidget {
  const FindRoom({Key? key}) : super(key: key);

  @override
  _FindRoomState createState() => _FindRoomState();
}

class _FindRoomState extends State<FindRoom> {
  dynamic data = [];
  bool getDataExecuted = false;
  String loadText = '';

  int _selectedDay = 0; // 0 for today, 1 for tomorrow
  bool _tomorrowPlanAvailable = false;

  int process = 0;
  int totalSteps = 10;

  bool isNumeric(String s) {
    return double.tryParse(s) != null;
  }

  double toDouble(TimeOfDay myTime) => myTime.hour + myTime.minute / 60.0;

  void getData() async {
    getDataExecuted = true;
    if (mounted) {
      setState(() {
        data = [];
        loadText = AppLocalizations.of(context)!.loadingData;
      });
    }

    VPlanAPI vplanAPI = VPlanAPI();

    // Check if tomorrow's plan is available
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowPlan = await vplanAPI.getVPlanJSON(
        Uri.parse(await vplanAPI.getURL(tomorrow)),
        tomorrow,
      );
      if (tomorrowPlan != null &&
          tomorrowPlan['error'] == null &&
          tomorrowPlan.isNotEmpty) {
        if (mounted) {
          setState(() {
            _tomorrowPlanAvailable = true;
          });
        }
      }
    } catch (e) {
      // Tomorrow's plan not available
    }

    final dateToFetch = _selectedDay == 0
        ? DateTime.now()
        : DateTime.now().add(const Duration(days: 1));
    Uri url = Uri.parse(await vplanAPI.getURL(dateToFetch));

    if (mounted) setState(() => loadText = AppLocalizations.of(context)!.loadingSubstitutionPlan);
    dynamic _vplanData = await vplanAPI.getVPlanJSON(url, dateToFetch);
    if (mounted) setState(() => loadText = AppLocalizations.of(context)!.substitutionPlanLoaded);

    if (_vplanData == null ||
        _vplanData.isEmpty ||
        _vplanData['error'] != null ||
        _vplanData['data'] == null ||
        !vplanAPI.compareDate(dateToFetch, _vplanData['date'])) {
      if (mounted) {
        setState(() {
          loadText = _selectedDay == 0
              ? AppLocalizations.of(context)!.noSubstitutionPlanToday
              : AppLocalizations.of(context)!.noSubstitutionPlanTomorrow;
        });
      }
      return;
    }

    // --- Get all rooms ---
    List<int> rooms = [];
    if (_vplanData['data']['Klassen'] != null &&
        _vplanData['data']['Klassen']['Kl'] != null) {
      for (var klasse in _vplanData['data']['Klassen']['Kl']) {
        if (klasse['Pl'] == null || klasse['Pl']['Std'] == null) continue;
        for (var lesson in klasse['Pl']['Std']) {
          String? room = lesson['Ra'];
          if (room != null && room != 'Gang') {
            String editRoom = room
                .replaceAll('H1', '')
                .replaceAll('H2', '')
                .replaceAll('H3', '')
                .replaceAll('E', '');
            if (int.tryParse(editRoom) != null) {
              if (!rooms.contains(int.parse(editRoom))) {
                rooms.add(int.parse(editRoom));
              }
            }
          }
        }
      }
    }
    rooms.sort();
    // --- All rooms got ---

    List<int> usedRooms = [];
    if (_selectedDay == 0 &&
        _vplanData['data']['Klassen'] != null &&
        _vplanData['data']['Klassen']['Kl'] != null) {
      // Only check for currently used rooms for today
      if (mounted) setState(() => loadText = AppLocalizations.of(context)!.browsingPlan);
      totalSteps = _vplanData['data']['Klassen']['Kl'].length;
      process = 0;

      for (var cl in _vplanData['data']['Klassen']['Kl']) {
        if (mounted) setState(() => process++);
        if (cl['Pl'] == null || cl['Pl']['Std'] == null) continue;
        for (var lesson in cl['Pl']['Std']) {
          try {
            if (lesson['Beginn'] == null || lesson['Ende'] == null) continue;

            int bhours = int.parse((lesson['Beginn'] as String).split(':')[0]);
            int bminutes =
            int.parse((lesson['Beginn'] as String).split(':')[1]);

            int ehours = int.parse((lesson['Ende'] as String).split(':')[0]);
            int eminutes = int.parse((lesson['Ende'] as String).split(':')[1]);

            TimeOfDay _begin = TimeOfDay(hour: bhours, minute: bminutes);
            TimeOfDay _end = TimeOfDay(hour: ehours, minute: eminutes);
            TimeOfDay _now = initTime; // Use selected time

            if (toDouble(_now) >= toDouble(_begin) &&
                toDouble(_now) <= toDouble(_end)) {
              String? room = lesson['Ra'];
              if (room != null) {
                String editRoom = room
                    .replaceAll('H1', '')
                    .replaceAll('H2', '')
                    .replaceAll('H3', '')
                    .replaceAll('E', '');
                if (isNumeric(editRoom)) {
                  int roomInt = int.parse(editRoom);
                  if (!usedRooms.contains(roomInt)) {
                    usedRooms.add(roomInt);
                  }
                }
              }
            }
          } catch (e) {}
        }
      }
      usedRooms.sort();
    }

    if (mounted) setState(() => loadText = AppLocalizations.of(context)!.analysingRooms);
    totalSteps = rooms.length;
    process = 0;
    List<dynamic> allRooms = [];
    for (int i = 0; i < rooms.length; i++) {
      if (mounted) {
        setState(() {
          process++;
          loadText = AppLocalizations.of(context)!.checkRoom(rooms[i].toString());
        });
      }

      List<dynamic> roomLessons = await getRoomLessons(
        rooms[i],
        _vplanData,
      );

      allRooms.add({
        'room': rooms[i],
        'open': !usedRooms.contains(rooms[i]),
        'used_this_day': roomLessons.isNotEmpty,
        'room_lessons': roomLessons,
      });
    }

    if (mounted) {
      setState(() {
        data = allRooms;
        loadText = '';
      });
    }
  }

  Future<List<dynamic>> getRoomLessons(int _room, _data) async {
    List<dynamic> res = [];
    if (_data == null ||
        _data['data'] == null ||
        _data['data']['Klassen'] == null ||
        _data['data']['Klassen']['Kl'] == null) {
      return res;
    }

    for (var currentClass in _data['data']['Klassen']['Kl']) {
      if (currentClass['Pl'] == null || currentClass['Pl']['Std'] == null) {
        continue;
      }

      for (var currentLesson in currentClass['Pl']['Std']) {
        try {
          String? room = currentLesson['Ra'];
          if (room != null) {
            String editRoom = room
                .replaceAll('H1', '')
                .replaceAll('H2', '')
                .replaceAll('H3', '')
                .replaceAll('E', '');
            if (int.tryParse(editRoom) != null &&
                int.parse(editRoom) == _room) {
              res.add({
                'count': int.parse(currentLesson['St']),
                'lesson': currentLesson['Fa'],
                'class': currentClass['Kurz'],
                'teacher': currentLesson['Le'],
                'info': currentLesson['If'],
              });
            }
          }
        } catch (e) {}
      }
    }
    res.sort((a, b) => a['count'].compareTo(b['count']));
    return res;
  }

  void roomInfo(context, roomData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Container(
                alignment: Alignment.topCenter,
                width: double.infinity,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  width: 100,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Theme.of(context).backgroundColor,
                  ),
                ),
              ),
              Container(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      roomData.isNotEmpty
                          ? AppLocalizations.of(context)!.lessonsInThisRoom
                          : AppLocalizations.of(context)!.todayNoLessonsInThisRoom,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 25),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Scrollbar(
                          thumbVisibility: true,
                          radius: Radius.circular(100),
                          thickness: 2,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            children: [
                              roomData.isEmpty
                                  ? Text(
                                '...',
                                textAlign: TextAlign.center,
                              )
                                  : SizedBox(),
                              ...roomData.map(
                                    (e) => ListItem(
                                  onClick: () {},
                                  color: e['info'] == null
                                      ? null
                                      : Color(0x889E1414),
                                  leading: Text(
                                    printValue('${e['count']}'),
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  title: Container(
                                    alignment: Alignment.centerLeft,
                                    width:
                                    MediaQuery.of(context).size.width * 0.1,
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          printValue(e['lesson']),
                                          style: TextStyle(fontSize: 19),
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.group_rounded,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 3),
                                                Text(printValue(e['class'])),
                                              ],
                                            ),
                                            SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_rounded,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 3),
                                                Text(printValue(e['teacher'])),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(width: 50),
                                      ],
                                    ),
                                  ),
                                  subtitle: e['info'] == null
                                      ? null
                                      : Text(
                                    '${e['info']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String printValue(String? value) {
    if (value == null) {
      return '---';
    }
    return value;
  }

  setTime(BuildContext context) async {
    final newTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(AppLocalizations.of(context)!.chooseTimeAndDay),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_tomorrowPlanAvailable)
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(20),
                      isSelected: [_selectedDay == 0, _selectedDay == 1],
                      onPressed: (index) {
                        setState(() {
                          _selectedDay = index;
                        });
                      },
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(AppLocalizations.of(context)!.today),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(AppLocalizations.of(context)!.tomorrow),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TimePickerSpinner(
                    time: DateTime(DateTime.now().year, DateTime.now().month,
                        DateTime.now().day, initTime.hour, initTime.minute),
                    is24HourMode: false,
                    isShowSeconds: false,
                    normalTextStyle: const TextStyle(fontSize: 18),
                    highlightedTextStyle: TextStyle(
                        fontSize: 24, color: Theme.of(context).primaryColor),
                    spacing: 20,
                    itemHeight: 60,
                    isForce2Digits: true,
                    onTimeChange: (DateTime newTime) {
                      setState(() {
                        initTime = TimeOfDay(
                            hour: newTime.hour, minute: newTime.minute);
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(AppLocalizations.of(context)!.cancel),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                TextButton(
                  child: Text(AppLocalizations.of(context)!.ok),
                  onPressed: () => Navigator.of(context).pop(initTime),
                ),
              ],
            );
          },
        );
      },
    );

    if (newTime != null) {
      initTime = newTime;
      getData();
      if (mounted) setState(() {});
    }
  }

  TimeOfDay initTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    String time =
        '${initTime.hour <= 9 ? '0${initTime.hour}' : initTime.hour}:${initTime.minute <= 9 ? '0${initTime.minute}' : initTime.minute}';
    if (!getDataExecuted) getData();
    return Container(
      child: ListPage(
        title: AppLocalizations.of(context)!.freeRoomsTitle(time),
        smallTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () => setTime(context),
          ),
          IconButton(
            onPressed: () => getData(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
        children: [
          loadText != ''
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                loadText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                AppLocalizations.of(context)!.processCanTakeSeconds,
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 15),
              ProcessBar(
                slow: true,
                width: MediaQuery.of(context).size.width * 0.6,
                totalSteps: totalSteps,
                currentStep: process,
              )
            ],
          )
              : data == []
              ? SizedBox(
            width: 100,
            height: 200,
            child: Text(AppLocalizations.of(context)!.loading),
          )
              : GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 3 / 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...(data as List).map(
                    (e) => InkWell(
                  onTap: () async => roomInfo(
                    context,
                    e['room_lessons'],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).backgroundColor,
                      border: e['open']
                          ? Border.all(
                        color: Theme.of(context).primaryColor,
                      )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        e['used_this_day']
                            ? '${e['room']}'
                            : '(${e['room']})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
