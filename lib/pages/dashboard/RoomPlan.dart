import 'package:expandiware/models/ListItem.dart';
import 'package:expandiware/models/ListPage.dart';
import 'package:expandiware/models/LoadingProcess.dart';
import 'package:flutter/material.dart';
import 'package:expandiware/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../vplan/VPlanAPI.dart';

/// Zeigt den Stundenplan eines ausgewählten Raums: Wähle einen Raum aus und
/// sieh, welche Unterrichtsstunde zu welcher Zeit in ihm stattfindet. Über
/// die Pfeile kann zwischen den Tagen gewechselt werden (Wochenenden werden
/// übersprungen).
class RoomPlan extends StatefulWidget {
  const RoomPlan({Key? key}) : super(key: key);

  @override
  _RoomPlanState createState() => _RoomPlanState();
}

class _RoomPlanState extends State<RoomPlan> {
  final VPlanAPI vplanAPI = VPlanAPI();

  dynamic data; // roher Vertretungsplan des gewählten Tages
  List<String> rooms = [];
  String? selectedRoom;
  List<dynamic> roomLessons = [];

  DateTime currentDate = DateTime.now();
  DateTime planDate = DateTime.now(); // Datum, das der Plan tatsächlich hat
  bool loading = true;
  String loadText = '';
  String errorText = '';

  String printValue(String? value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '---';
    }
    return value.toString();
  }

  /// Normalisiert Raumbezeichnungen (z.B. 'H1 101' -> '101'), wie es auch
  /// die Raum-Suche macht, damit identische Räume zusammengefasst werden.
  String normalizeRoom(String room) {
    return room
        .replaceAll('H1', '')
        .replaceAll('H2', '')
        .replaceAll('H3', '')
        .replaceAll('E', '')
        .trim();
  }

  /// Wechselt zum vorherigen/nächsten Schultag (Wochenenden werden
  /// übersprungen).
  void changeDay(bool nextDay) {
    DateTime newDate = currentDate;
    if (nextDay) {
      newDate = currentDate.add(const Duration(days: 1));
      if (newDate.weekday == 6) newDate = newDate.add(const Duration(days: 2));
      if (newDate.weekday == 7) newDate = newDate.add(const Duration(days: 1));
    } else {
      newDate = currentDate.subtract(const Duration(days: 1));
      if (newDate.weekday == 6) newDate = newDate.subtract(const Duration(days: 1));
      if (newDate.weekday == 7) newDate = newDate.subtract(const Duration(days: 2));
    }
    setState(() {
      currentDate = newDate;
      planDate = newDate;
      data = null;
      roomLessons = [];
    });
    getData();
  }

  bool _invalidPlan(dynamic p) {
    return p == null ||
        p['error'] != null ||
        p.isEmpty ||
        p['data'] == null ||
        p['data']['Klassen'] == null;
  }

  Future<void> getData() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorText = '';
        loadText = AppLocalizations.of(context)!.loadingSubstitutionPlan;
      });
    }

    dynamic plan = await vplanAPI.getRawPlanByDate(currentDate);

    if (!mounted) return;

    if (_invalidPlan(plan)) {
      // Der erste Abruf ist fehlgeschlagen (z.B. kurzer Netzwerk- oder
      // Serverhänger beim ersten Request der Session). Nach einer kurzen
      // Pause einmal erneut laden, bevor eine Fehlermeldung angezeigt wird.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      plan = await vplanAPI.getRawPlanByDate(currentDate, forceRefresh: true);
    }

    if (!mounted) return;

    if (_invalidPlan(plan)) {
      setState(() {
        loading = false;
        loadText = '';
        errorText = AppLocalizations.of(context)!.noPlanForThisDay;
        data = null;
        rooms = [];
        selectedRoom = null;
        roomLessons = [];
      });
      return;
    }

    // Angezeigtes Datum: das Datum, das der Plan selbst trägt (die Schule
    // veröffentlicht z.B. abends ggf. schon den nächsten Tag), sonst der
    // gewählte Tag.
    DateTime shownDate = currentDate;
    if (plan['date'] != null) {
      try {
        shownDate =
            vplanAPI.parseStringDatatoDateTime(plan['date'].toString());
      } catch (e) {
        shownDate = currentDate;
      }
    }
    planDate = shownDate;

    // Alle Räume des Plans sammeln (normalisiert und eindeutig)
    List<String> allRooms = [];
    if (plan['data']['Klassen'] != null &&
        plan['data']['Klassen']['Kl'] != null) {
      for (var klasse in plan['data']['Klassen']['Kl']) {
        if (klasse['Pl'] == null || klasse['Pl']['Std'] == null) continue;
        for (var lesson in klasse['Pl']['Std']) {
          String? room = lesson['Ra'];
          if (room == null || room.trim().isEmpty || room == 'Gang') continue;
          String normalized = normalizeRoom(room);
          if (normalized.isEmpty) continue;
          if (!allRooms.contains(normalized)) {
            allRooms.add(normalized);
          }
        }
      }
    }
    // Nummerische Räume zuerst (aufsteigend), danach alphabetisch
    allRooms.sort((a, b) {
      int? an = int.tryParse(a);
      int? bn = int.tryParse(b);
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.compareTo(b);
    });

    // Auswahl beibehalten, falls der Raum auch heute noch existiert
    String? keep = selectedRoom;
    if (keep == null || !allRooms.contains(keep)) {
      keep = allRooms.isNotEmpty ? allRooms.first : null;
    }

    setState(() {
      data = plan;
      rooms = allRooms;
      selectedRoom = keep;
      loading = false;
      loadText = '';
    });

    if (selectedRoom != null) {
      await loadRoomLessons();
    }
  }

  /// Sammelt alle Stunden des gewählten Tages, die im ausgewählten Raum
  /// stattfinden, sortiert nach Stundenzahl.
  Future<void> loadRoomLessons() async {
    if (data == null || selectedRoom == null) return;
    List<dynamic> lessons = [];
    if (data['data']['Klassen'] != null &&
        data['data']['Klassen']['Kl'] != null) {
      for (var klasse in data['data']['Klassen']['Kl']) {
        if (klasse['Pl'] == null || klasse['Pl']['Std'] == null) continue;
        for (var lesson in klasse['Pl']['Std']) {
          String? room = lesson['Ra'];
          if (room == null) continue;
          if (normalizeRoom(room) != selectedRoom) continue;
          lessons.add({
            'count': lesson['St'],
            'lesson': lesson['Fa'],
            'class': klasse['Kurz'],
            'teacher': await vplanAPI.replaceTeacherShort(lesson['Le']),
            'begin': lesson['Beginn'],
            'end': lesson['Ende'],
            'info': lesson['If'],
          });
        }
      }
    }
    lessons.sort((a, b) {
      int aCount = int.tryParse(a['count']?.toString() ?? '') ?? 0;
      int bCount = int.tryParse(b['count']?.toString() ?? '') ?? 0;
      return aCount.compareTo(bCount);
    });
    if (mounted) {
      setState(() {
        roomLessons = lessons;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Erst nach dem ersten Frame laden, damit in getData() auf
    // AppLocalizations.of(context) zugegriffen werden kann (das ist vor
    // Abschluss von initState nicht erlaubt).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) getData();
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayDate = DateFormat('dd.MM.yyyy').format(planDate);

    return ListPage(
      title: '${selectedRoom ?? '...'}\n$displayDate',
      smallTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          onPressed: loading ? null : () => getData(),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: loading ? null : () => changeDay(false),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: loading ? null : () => changeDay(true),
        ),
      ],
      children: [
        if (loading)
          Column(
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
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 15),
              const LoadingProcess(),
            ],
          )
        else if (errorText.isNotEmpty)
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 40),
            child: Text(
              errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          )
        else ...[
          // Raum-Auswahl
          Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                value: selectedRoom,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_rounded),
                items: rooms
                    .map(
                      (r) => DropdownMenuItem<String>(
                        value: r,
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRoom = value;
                    roomLessons = [];
                  });
                  loadRoomLessons();
                },
                hint: Text(AppLocalizations.of(context)!.selectRoom),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (roomLessons.isEmpty)
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 40),
              child: Text(
                AppLocalizations.of(context)!.noLessonsInRoom,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            )
          else
            ...roomLessons.map(
              (e) => ListItem(
                onClick: () {},
                color: e['info'] == null ? null : const Color(0x889E1414),
                leading: Text(
                  printValue('${e['count']}'),
                  style: const TextStyle(fontSize: 18),
                ),
                title: Container(
                  alignment: Alignment.centerLeft,
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        printValue(e['lesson']),
                        style: const TextStyle(fontSize: 19),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${printValue(e['begin'])} - ${printValue(e['end'])}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.group_rounded, size: 16),
                              const SizedBox(width: 3),
                              Text(printValue(e['class'])),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16),
                              const SizedBox(width: 3),
                              Text(printValue(e['teacher'])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
                subtitle: e['info'] == null
                    ? null
                    : Text(
                        '${e['info']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}
