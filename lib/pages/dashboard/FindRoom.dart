import 'dart:convert';

import 'package:substitute/models/ListItem.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/models/ProcessBar.dart';
import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../vplan/VPlanAPI.dart';
import '../../services/SchoolStorage.dart';

/// Raumplan: Zeigt alle Räume und deren Belegung für einen bestimmten Tag
/// und eine bestimmte Uhrzeit bzw. Stunde. Der Nutzer kann wählen zwischen
/// einer konkreten Uhrzeit (Date+Time-Picker), einer Schulstunde (1.–10.)
/// oder dem gesamten Tag (ohne Zeitfilter).
class FindRoom extends StatefulWidget {
  const FindRoom({Key? key}) : super(key: key);

  @override
  _FindRoomState createState() => _FindRoomState();
}

class _FindRoomState extends State<FindRoom> {
  dynamic data = [];
  bool getDataExecuted = false;
  String loadText = '';

  // Date selection
  DateTime _selectedDate = DateTime.now();

  // Time mode: null = full day, TimeOfDay = specific time
  TimeOfDay? _selectedTime;

  // Hour mode: null = use time, int = lesson number (1, 2, 3, ...)
  int? _selectedHour;

  // Lesson times loaded from settings
  List<Map<String, dynamic>> _lessonTimes = [];

  int process = 0;
  int totalSteps = 10;

  /// Normalisiert eine Raumbezeichnung (entfernt Gebäudepräfixe wie H1/H2/H3
  /// und E sowie überflüssige Leerzeichen), damit identische Räume zusammenge-
  /// fasst werden – unabhängig davon, ob der Name Ziffern oder Buchstaben
  /// enthält.
  String _normalizeRoom(String room) {
    return room
        .replaceAll('H1', '')
        .replaceAll('H2', '')
        .replaceAll('H3', '')
        .replaceAll('E', '')
        .trim();
  }

  /// Sortiert Räume: rein numerische aufsteigend, danach alphabetisch.
  int _compareRooms(String a, String b) {
    int? an = int.tryParse(a);
    int? bn = int.tryParse(b);
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    return a.compareTo(b);
  }

  double toDouble(TimeOfDay myTime) => myTime.hour + myTime.minute / 60.0;

  /// Returns the effective TimeOfDay to filter rooms by.
  /// If a specific hour is selected, uses the lesson's start time.
  /// If a specific time is selected, uses that.
  /// If full day, returns null.
  TimeOfDay? get _effectiveTime {
    if (_selectedHour != null && _lessonTimes.isNotEmpty) {
      int idx = _selectedHour! - 1;
      if (idx >= 0 && idx < _lessonTimes.length) {
        dynamic start = _lessonTimes[idx]['start'];
        return _parseTimeOfDay(start);
      }
    }
    return _selectedTime;
  }

  TimeOfDay? _parseTimeOfDay(dynamic value) {
    final String time = value?.toString() ?? '';
    final RegExpMatch? match = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(time);
    if (match == null) return null;

    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour != null && minute != null) {
      return TimeOfDay(
        hour: hour.clamp(0, 23).toInt(),
        minute: minute.clamp(0, 59).toInt(),
      );
    }
    return null;
  }

  /// Returns true if we are in full-day mode (no time/hour filter).
  bool get _isFullDay => _selectedTime == null && _selectedHour == null;

  void getData() async {
    getDataExecuted = true;
    if (mounted) {
      setState(() {
        data = [];
        loadText = AppLocalizations.of(context)!.loadingData;
      });
    }

    // Load lesson times from settings
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lessonTimesJson =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'lessontimes'));
    if (lessonTimesJson != null && lessonTimesJson.isNotEmpty) {
      try {
        List<dynamic> decoded = jsonDecode(lessonTimesJson);
        _lessonTimes = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        _lessonTimes = [];
      }
    }

    final VPlanAPI vplanAPI = VPlanAPI();

    if (mounted) {
      setState(() {
        loadText = AppLocalizations.of(context)!.loadingSubstitutionPlan;
      });
    }

    // Den vollständigen Tagesplan direkt laden. Dieser Pfad funktioniert auch
    // ohne angelegte Klasse/Person und verwendet für vergangene Tage
    // automatisch PlanKl<Datum>.xml.
    dynamic _vplanData;
    try {
      _vplanData = await vplanAPI.getRawPlanByDate(_selectedDate);
    } catch (e) {
      _vplanData = {'error': 'no internet'};
    }
    if (mounted) {
      setState(() {
        loadText = AppLocalizations.of(context)!.substitutionPlanLoaded;
      });
    }

    // Prüft, ob der geladene Plan überhaupt brauchbare Raumdaten enthält.
    // Bewusst OHNE compareDate: Der vom Server gelieferte Vertretungsplan für
    // "heute" ist oft noch auf den letzten Schultag datiert (die Schule
    // veröffentlicht den aktuellen Plan erst im Laufe des Tages). Ein solcher
    // Plan ist trotzdem die gültige Quelle für die heutige Raumbelegung und
    // darf nicht pauschal verworfen werden – genau wie es der Klassen-
    // /Kursplan auch handhabt.
    bool planLooksInvalid() {
      return _vplanData == null ||
          _vplanData is! Map ||
          _vplanData.isEmpty ||
          _vplanData['error'] != null ||
          _vplanData['data'] == null ||
          _vplanData['data']['Klassen'] == null;
    }

    // Der erste Abruf kann fehlschlagen (z.B. veralteter Cache-Eintrag für
    // diesen Tag, kurzer Netzwerk-/Server-Hänger beim ersten Request der
    // Session). In diesem Fall den Vertretungsplan einmalig frisch vom Server
    // laden, damit der Raumplan sich nicht erst auf das vorherige Öffnen
    // eines Klassen-/Kursplans verlassen muss.
    if (planLooksInvalid()) {
      try {
        _vplanData =
            await vplanAPI.getRawPlanByDate(_selectedDate, forceRefresh: true);
      } catch (e) {
        _vplanData = {'error': 'no internet'};
      }
      if (mounted) {
        setState(() {
          loadText = AppLocalizations.of(context)!.substitutionPlanLoaded;
        });
      }
    }

    if (planLooksInvalid()) {
      if (mounted) {
        setState(() {
          loadText = _vplanData is Map &&
                  _vplanData['error'] == 'no internet'
              ? AppLocalizations.of(context)!.noInternetConnection
              : AppLocalizations.of(context)!.noPlanForThisDay;
        });
      }
      return;
    }

    // --- Get all rooms from plan data (Zahlen- UND Buchstabenräume) ---
    List<String> rooms = [];
    if (_vplanData['data']['Klassen'] != null &&
        _vplanData['data']['Klassen']['Kl'] != null) {
      for (var klasse in _vplanData['data']['Klassen']['Kl']) {
        if (klasse['Pl'] == null || klasse['Pl']['Std'] == null) continue;
        for (var lesson in klasse['Pl']['Std']) {
          String? room = lesson['Ra'];
          if (room != null && room != 'Gang') {
            String editRoom = _normalizeRoom(room);
            if (editRoom.isNotEmpty && !rooms.contains(editRoom)) {
              rooms.add(editRoom);
            }
          }
        }
      }
    }

    // Merge with previously cached rooms so ALL known rooms are shown
    SharedPreferences prefs2 = await SharedPreferences.getInstance();
    List<String> cachedRooms =
        (prefs2.getStringList(SchoolStorage.scopedKey(prefs2, 'cachedRooms')) ??
            []);
    for (var r in cachedRooms) {
      if (!rooms.contains(r)) rooms.add(r);
    }
    // Save merged list for next time
    await prefs2.setStringList(
      SchoolStorage.scopedKey(prefs2, 'cachedRooms'),
      rooms,
    );

    rooms.sort(_compareRooms);
    // --- All rooms got ---

    List<String> usedRooms = [];
    if (_vplanData['data']['Klassen'] != null &&
        _vplanData['data']['Klassen']['Kl'] != null) {
      // Belegte Räume ermitteln:
      // - Stunde:  nur Räume mit dieser Stundenzahl
      // - Uhrzeit: nur Räume, die zur gewählten Zeit belegt sind
      // - ganzer Tag: jeder Raum, der an diesem Tag überhaupt belegt ist
      if (mounted)
        setState(() => loadText = AppLocalizations.of(context)!.browsingPlan);
      totalSteps = _vplanData['data']['Klassen']['Kl'].length;
      process = 0;

      final bool hourMode = _selectedHour != null;
      final bool fullDayMode = _isFullDay;
      final int selectedHour = _selectedHour ?? -1;
      final TimeOfDay filterTime = _effectiveTime ?? TimeOfDay.now();

      for (var cl in _vplanData['data']['Klassen']['Kl']) {
        if (mounted) setState(() => process++);
        if (cl['Pl'] == null || cl['Pl']['Std'] == null) continue;
        for (var lesson in cl['Pl']['Std']) {
          try {
            if (hourMode) {
              // Nach der echten Stundenzahl filtern, nicht nach Uhrzeit.
              final int? lessonNum =
                  int.tryParse(lesson['St']?.toString() ?? '');
              if (lessonNum != selectedHour) continue;
            } else if (!fullDayMode) {
              if (lesson['Beginn'] == null || lesson['Ende'] == null) continue;

              int bhours = int.parse((lesson['Beginn'] as String).split(':')[0]);
              int bminutes =
                  int.parse((lesson['Beginn'] as String).split(':')[1]);

              int ehours = int.parse((lesson['Ende'] as String).split(':')[0]);
              int eminutes = int.parse((lesson['Ende'] as String).split(':')[1]);

              TimeOfDay _begin = TimeOfDay(hour: bhours, minute: bminutes);
              TimeOfDay _end = TimeOfDay(hour: ehours, minute: eminutes);

              if (!(toDouble(filterTime) >= toDouble(_begin) &&
                  toDouble(filterTime) <= toDouble(_end))) {
                continue;
              }
            }
            // Bei "ganzer Tag" werden alle Räume übernommen, die an diesem
            // Tag irgendwann belegt sind.

            String? room = lesson['Ra'];
            if (room != null) {
              String editRoom = _normalizeRoom(room);
              if (editRoom.isNotEmpty && !usedRooms.contains(editRoom)) {
                usedRooms.add(editRoom);
              }
            }
          } catch (e) {}
        }
      }
      usedRooms.sort();
    }

    if (mounted)
      setState(() => loadText = AppLocalizations.of(context)!.analysingRooms);
    totalSteps = rooms.length;
    process = 0;
    List<dynamic> allRooms = [];
    for (int i = 0; i < rooms.length; i++) {
      if (mounted) {
        setState(() {
          process++;
          loadText =
              AppLocalizations.of(context)!.checkRoom(rooms[i].toString());
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

  Future<List<dynamic>> getRoomLessons(String _room, _data) async {
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
            String editRoom = _normalizeRoom(room);
            if (editRoom == _room) {
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
                    color: Theme.of(context).colorScheme.surface,
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
                          : AppLocalizations.of(context)!
                              .todayNoLessonsInThisRoom,
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

  /// Shows the combined date/time/hour selection dialog.
  void _showSelectionDialog(BuildContext context) async {
    DateTime tempDate = _selectedDate;
    TimeOfDay? tempTime = _selectedTime;
    int? tempHour = _selectedHour;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String dateStr = DateFormat('dd.MM.yyyy').format(tempDate);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(AppLocalizations.of(context)!.chooseTimeAndDay),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker button
                    ListTile(
                      leading: Icon(Icons.calendar_today_rounded),
                      title: Text(dateStr),
                      subtitle: Text(AppLocalizations.of(context)!.selectDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempDate,
                          firstDate:
                              DateTime.now().subtract(Duration(days: 30)),
                          lastDate: DateTime.now().add(Duration(days: 30)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    // Mode toggle: Time / Hour / Full Day
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(20),
                      isSelected: [
                        tempHour == null && tempTime != null,
                        tempHour != null,
                        tempHour == null && tempTime == null,
                      ],
                      onPressed: (index) {
                        setDialogState(() {
                          if (index == 0) {
                            // Time mode
                            tempHour = null;
                            tempTime = tempTime ?? TimeOfDay.now();
                          } else if (index == 1) {
                            // Hour mode
                            tempTime = null;
                            tempHour = tempHour ?? 1;
                          } else {
                            // Full day mode
                            tempHour = null;
                            tempTime = null;
                          }
                        });
                      },
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(AppLocalizations.of(context)!.time),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(AppLocalizations.of(context)!.hour),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(AppLocalizations.of(context)!.fullDay),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Time picker (when in time mode)
                    if (tempHour == null && tempTime != null)
                      ListTile(
                        leading: Icon(Icons.access_time_rounded),
                        title: Text(
                          '${tempTime!.hour.toString().padLeft(2, '0')}:${tempTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle:
                            Text(AppLocalizations.of(context)!.selectTime),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: tempTime!,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempTime = picked;
                            });
                          }
                        },
                      ),
                    // Hour picker (when in hour mode) – es wird nach Stunde
                    // gefiltert, daher werden hier keine Uhrzeiten angezeigt.
                    if (tempHour != null)
                      Column(
                        children: List.generate(
                          _lessonTimes.isNotEmpty
                              ? (_lessonTimes.length < 10
                                  ? 10
                                  : _lessonTimes.length)
                              : 10,
                          (index) {
                            int lessonNum = index + 1;
                            return ListTile(
                              leading: Icon(
                                tempHour == lessonNum
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: tempHour == lessonNum
                                    ? Theme.of(context).primaryColor
                                    : null,
                              ),
                              title: Text(
                                '$lessonNum. ${AppLocalizations.of(context)!.hour}',
                                style: TextStyle(
                                  fontWeight: tempHour == lessonNum
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                setDialogState(() {
                                  tempHour = lessonNum;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    // Full day message
                    if (tempHour == null && tempTime == null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          AppLocalizations.of(context)!.fullDayMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .focusColor
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(AppLocalizations.of(context)!.cancel),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                TextButton(
                  child: Text(AppLocalizations.of(context)!.ok),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'date': tempDate,
                      'time': tempTime,
                      'hour': tempHour,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedDate = result['date'];
          _selectedTime = result['time'];
          _selectedHour = result['hour'];
        });
        getData();
      }
    });
  }

  /// Builds the display text for the current selection.
  String _buildTitleTime() {
    String dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
    if (_isFullDay) {
      return '$dateStr – ${AppLocalizations.of(context)!.fullDay}';
    } else if (_selectedHour != null) {
      return '$dateStr – ${_selectedHour}. ${AppLocalizations.of(context)!.hour}';
    } else if (_selectedTime != null) {
      String timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
      return '$dateStr – $timeStr';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    if (!getDataExecuted) getData();
    return Container(
      child: ListPage(
        title:
            '${AppLocalizations.of(context)!.roomPlan}\n${_buildTitleTime()}',
        smallTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () => _showSelectionDialog(context),
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
                                color: Theme.of(context).colorScheme.surface,
                                border: !e['open']
                                    ? Border.all(
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                              ),
                                child: Center(
                                  child: Text(
                                    '${e['room']}',
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
