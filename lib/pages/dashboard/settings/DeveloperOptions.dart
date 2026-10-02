import 'package:substitute/models/Button.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../models/ListPage.dart';
import '../../../models/SettingsSwitchTile.dart';
import '../../../services/SchoolStorage.dart';
import '../../../services/AppClock.dart';
import '../../../services/sync/SyncEngine.dart';

import 'package:shared_preferences/shared_preferences.dart';

class DeveloperOptions extends StatefulWidget {
  void deleteOfflineData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setStringList(SchoolStorage.scopedKey(prefs, 'offlineVPData'), []);
  }

  @override
  _DeveloperOptionsState createState() => _DeveloperOptionsState();
}

class _DeveloperOptionsState extends State<DeveloperOptions> {
  bool _isAnalysisEnabled = false;
  bool _showSyncDetails = false;
  DateTime? _customDate;

  @override
  void initState() {
    super.initState();
    _loadAnalysisStatus();
    _loadCustomDate();
    _loadSyncDetails();
  }

  /// Liest den Schalter für die zusätzlichen Sync-Anzeigen.
  ///
  /// Gespeichert wird er unter `sync.showDetails`, also gerätelokal: Er ist eine
  /// Frage der Anzeige auf **diesem** Gerät, keine Eigenschaft der Kette.
  Future<void> _loadSyncDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showSyncDetails = SyncEngine.showsDetails(prefs);
    });
  }

  Future<void> _setSyncDetails(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SyncEngine.showDetailsStorageKey, value);
    if (!mounted) return;
    setState(() {
      _showSyncDetails = value;
    });
  }

  Future<void> _loadAnalysisStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAnalysisEnabled = prefs.getBool('analysis') ?? false;
    });
  }

  Future<void> _loadCustomDate() async {
    final date = await AppClock.getOverriddenNow();
    if (mounted) {
      setState(() {
        _customDate = date;
      });
    }
  }

  Future<void> _pickCustomDate() async {
    final DateTime base = _customDate ?? AppClock.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    // Zusätzlich zur Uhrzeit auch die Uhrzeit wählen lassen, damit sich z.B.
    // „vor/nach der letzten Stunde“ sauber testen lässt.
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null || !mounted) return;

    final DateTime picked = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await AppClock.setOverriddenNow(picked);
    if (mounted) {
      setState(() {
        _customDate = picked;
      });
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(DateTime date) {
    return '${_two(date.day)}.${_two(date.month)}.${date.year} '
        '${_two(date.hour)}:${_two(date.minute)}';
  }

  Future<void> _clearCustomDate() async {
    await AppClock.setOverriddenNow(null);
    if (mounted) {
      setState(() {
        _customDate = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> options = [
      {
        'title': 'Delete offline substitution plan',
        'actionText': 'Delete',
        'action': widget.deleteOfflineData,
      },
      {
        'title': 'Clear all SharedPreferences',
        'actionText': 'Clear',
        'action': () => SharedPreferences.getInstance()
            .then((instance) => instance.clear()),
      },
      {
        'title': 'Remove Teacher abbreviations',
        'actionText': 'Remove',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString(SchoolStorage.scopedKey(prefs, 'teacherShorts'), '');
        },
      },
      {
        'title': 'Clear news feeds',
        'actionText': 'Clear',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('newsfeeds', '[]');
        },
      },
      {
        'title': 'Toggle Material You',
        'actionText': 'Toggle',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool('materialyou', !prefs.getBool('materialyou')!);
          Fluttertoast.showToast(
            msg:
                'prefs.getBool(\'materialyou\') => ${prefs.getBool('materialyou')}',
          );
        },
      },
      {
        'title': 'Delete lesson times',
        'actionText': 'Delete',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString(SchoolStorage.scopedKey(prefs, 'lessontimes'), '[]');
        },
      },
      {
        'title': 'firstTime to true',
        'actionText': 'Set',
        'action': () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool('firstTime', true);
        },
      },
    ];
    return Scaffold(
      body: ListPage(
        title: 'Developer options',
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom date & time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customDate == null
                            ? 'No override'
                            : _formatDateTime(_customDate!),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_customDate != null)
                  Button(
                    text: 'Clear',
                    onPressed: _clearCustomDate,
                  ),
                Button(
                  text: _customDate == null ? 'Set' : 'Change',
                  onPressed: _pickCustomDate,
                ),
              ],
            ),
          ),
          SettingsSwitchTile(
            icon: Icons.sync_rounded,
            title: 'Show additional sync options and information',
            subtitle: 'Adds server status, automatic sync and the number of '
                'transferred entries to the sync page',
            value: _showSyncDetails,
            onChanged: _setSyncDetails,
          ),
          ...options.map(
            (e) => Container(
              margin: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    e['title'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Button(
                    text: e['actionText'],
                    onPressed: e['action'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
