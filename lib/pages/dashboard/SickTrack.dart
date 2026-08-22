import 'package:flutter/material.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/Button.dart';
import '../../models/ListItem.dart';
import '../../models/ListPage.dart';
import '../../models/LoadingProcess.dart';
import '../../services/SchoolStorage.dart';
import '../vplan/VPlanAPI.dart';

class SickTrack extends StatefulWidget {
  const SickTrack({Key? key}) : super(key: key);

  @override
  _SickTrackState createState() => _SickTrackState();
}

class _SickTrackState extends State<SickTrack> {
  VPlanAPI vplanAPI = VPlanAPI();
  List<Map<String, dynamic>> entries = [];
  Map<String, List<Map<String, dynamic>>> missedCache = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> _entries = await vplanAPI.getSickTrackEntries();
    if (!mounted) return;
    setState(() {
      entries = _entries;
      loading = false;
    });
    for (var entry in _entries) {
      _computeMissed(entry);
    }
  }

  Future<void> _computeMissed(Map<String, dynamic> entry) async {
    List<Map<String, dynamic>> missed = await vplanAPI.getMissedLessons(entry);
    if (!mounted) return;
    setState(() {
      missedCache[entry['id']] = missed;
    });
  }

  Future<void> _openEditor() async {
    final bool? saved = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: SickTrackEditor(),
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => loading = true);
      await _load();
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    await vplanAPI.deleteSickTrackEntry(entry['id']);
    if (!mounted) return;
    setState(() {
      entries.removeWhere((e) => e['id'] == entry['id']);
      missedCache.remove(entry['id']);
    });
  }

  String formatDay(String iso) {
    try {
      DateTime date = DateTime.parse(iso);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return iso;
    }
  }

  Widget _entryWidget(Map<String, dynamic> entry) {
    List<dynamic> courses = entry['courses'] as List? ?? [];
    List<dynamic> days = entry['days'] as List? ?? [];
    List<Map<String, dynamic>>? missed = missedCache[entry['id']];
    String classId = entry['classId']?.toString() ?? '';
    // Kurse, deren Unterschrift(en) bereits als erledigt markiert wurden.
    Set<String> doneSignatures =
        ((entry['signaturesDone'] as List?) ?? []).cast<String>().toSet();

    return ListItem(
      padding: 15,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classId,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 2),
          Text(
            courses.join(', '),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).focusColor.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 2),
          Text(
            '${AppLocalizations.of(context)!.sickDays}: '
            '${days.map((d) => formatDay(d.toString())).join(', ')}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).focusColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      subtitle: missed == null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: LoadingProcess(),
                ),
              ),
            )
          : missed.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppLocalizations.of(context)!.noMissedLessons,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).focusColor.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.missedLessons,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      ...missed.map(
                        (m) {
                          // Haken hinter erledigten Unterschriften, Kreuz
                          // hinter den noch offenen.
                          final bool done =
                              doneSignatures.contains(m['course']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Icon(
                                  done
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 16,
                                  color: done
                                      ? Colors.green
                                      : Theme.of(context)
                                          .focusColor
                                          .withValues(alpha: 0.5),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!.missedLesson(
                                      formatDay(m['date']),
                                      m['count'],
                                      m['course'],
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .focusColor
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      actionButton: IconButton(
        onPressed: () => _deleteEntry(entry),
        icon: Icon(
          Icons.delete_rounded,
          color: Theme.of(context).focusColor.withValues(alpha: 0.5),
        ),
      ),
      onClick: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: AppLocalizations.of(context)!.sickTrack,
      actions: [
        IconButton(
          onPressed: _openEditor,
          icon: const Icon(Icons.add_rounded),
          tooltip: AppLocalizations.of(context)!.sickTrackAdd,
        ),
      ],
      children: [
        if (loading)
          const Center(child: LoadingProcess())
        else if (entries.isEmpty)
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              Icon(
                Icons.sick_rounded,
                size: 60,
                color: Theme.of(context).focusColor.withValues(alpha: 0.3),
              ),
              SizedBox(height: 15),
              Text(
                AppLocalizations.of(context)!.noSickTrackEntries,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).focusColor.withValues(alpha: 0.6),
                ),
              ),
              Button(
                text: AppLocalizations.of(context)!.sickTrackAdd,
                onPressed: _openEditor,
                filled: true,
              ),
            ],
          )
        else
          ...entries.map(_entryWidget),
      ],
    );
  }
}

class SickTrackEditor extends StatefulWidget {
  const SickTrackEditor({Key? key}) : super(key: key);

  @override
  _SickTrackEditorState createState() => _SickTrackEditorState();
}

class _SickTrackEditorState extends State<SickTrackEditor> {
  VPlanAPI vplanAPI = VPlanAPI();
  String? classId;
  String? sourceLabel;
  bool loadingCourses = false;
  List<dynamic> availableCourses = [];
  Set<String> selectedCourses = {};
  List<String> days = [];

  String formatDay(String iso) {
    try {
      DateTime date = DateTime.parse(iso);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return iso;
    }
  }

  Future<void> _pickSource() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> classes =
        prefs.getStringList(SchoolStorage.scopedKey(prefs, 'classes')) ?? [];
    Map<String, String> classNames = await vplanAPI.getClassNames();
    List<Map<String, dynamic>> persons = await vplanAPI.getPersons();

    final String? result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.selectClassOrPerson,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...persons.map(
              (p) => ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(p['name']?.toString() ?? ''),
                subtitle: Text(p['classId']?.toString() ?? ''),
                onTap: () => Navigator.pop(context, 'person:${p['id']}'),
              ),
            ),
            ...classes.map(
              (c) => ListTile(
                leading: const Icon(Icons.school_rounded),
                title: Text(classNames[c] ?? c),
                onTap: () => Navigator.pop(context, 'class:$c'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded),
              title: Text(AppLocalizations.of(context)!.anotherClass),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result == 'other') {
      await _pickOtherClass();
      return;
    }

    if (result.startsWith('person:')) {
      String personId = result.substring(7);
      for (var p in persons) {
        if (p['id'] == personId) {
          setState(() {
            classId = p['classId']?.toString();
            sourceLabel = p['name']?.toString();
            selectedCourses =
                ((p['courses'] as List?) ?? []).cast<String>().toSet();
          });
          break;
        }
      }
      await _loadCourses(classId!);
    } else if (result.startsWith('class:')) {
      setState(() {
        classId = result.substring(6);
        sourceLabel = classNames[classId] ?? classId;
        selectedCourses = {};
      });
      await _loadCourses(classId!, preselectShown: true);
    }
  }

  Future<void> _pickOtherClass() async {
    dynamic list = await vplanAPI.getClassList();
    if (!mounted) return;
    if (list is! List) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.couldNotLoadVPlanData),
        ),
      );
      return;
    }
    final String? picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.selectClassTitle,
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.4,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) => ListTile(
              title: Text('${list[index]}'),
              onTap: () => Navigator.pop(context, '${list[index]}'),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      classId = picked;
      sourceLabel = picked;
      selectedCourses = {};
    });
    await _loadCourses(picked, preselectShown: true);
  }

  Future<void> _loadCourses(String _classId,
      {bool preselectShown = false}) async {
    setState(() => loadingCourses = true);
    List<dynamic> courses = await vplanAPI.getCourses(_classId);
    if (!mounted) return;
    Set<String> selected = selectedCourses;
    if (selected.isEmpty) {
      if (preselectShown) {
        // Übernimm die Kurse, die für diese Klasse bereits gewählt sind
        // (alle Kurse der Klasse minus die im Vertretungsplan
        // ausgeblendeten). Im Sick Tracker kann die Auswahl danach nur
        // noch feinjustiert werden.
        List<String> hidden = await vplanAPI.getHiddenCourses(_classId);
        selected = courses
            .map((c) => c['course']?.toString() ?? '')
            .where((c) => !hidden.contains(c))
            .toSet();
      } else {
        selected = courses.map((c) => c['course']?.toString() ?? '').toSet();
      }
    }
    if (!mounted) return;
    setState(() {
      availableCourses = courses;
      loadingCourses = false;
      selectedCourses = selected;
    });
  }

  Future<void> _addDay() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: AppLocalizations.of(context)!.selectSickDays,
    );
    if (picked == null) return;
    String iso = vplanAPI.isoDate(picked);
    setState(() {
      if (!days.contains(iso)) days.add(iso);
      days.sort();
    });
  }

  Future<void> _save() async {
    if (classId == null || days.isEmpty) return;
    Map<String, dynamic> entry = {
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'classId': classId,
      'courses': selectedCourses.toList(),
      'days': days,
    };
    await vplanAPI.addSickTrackEntry(entry);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: AppLocalizations.of(context)!.sickTrackAdd,
      actions: [
        IconButton(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          tooltip: AppLocalizations.of(context)!.save,
        ),
      ],
      children: [
        // 1. Class / person
        ListItem(
          padding: 15,
          leading: Icon(
            Icons.school_rounded,
            color: Theme.of(context).focusColor,
          ),
          title: Text(
            AppLocalizations.of(context)!.selectClassOrPerson,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            sourceLabel ??
                AppLocalizations.of(context)!.selectClassOrPersonHint,
            style: TextStyle(
              color: Theme.of(context).focusColor.withValues(alpha: 0.6),
            ),
          ),
          onClick: _pickSource,
        ),
        // 2. Courses
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 15, bottom: 5),
          child: Text(
            AppLocalizations.of(context)!.selectCourses,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (classId == null)
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 10),
            child: Text(
              AppLocalizations.of(context)!.selectClassOrPersonHint,
              style: TextStyle(
                color: Theme.of(context).focusColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else if (loadingCourses)
          const Center(child: LoadingProcess())
        else if (availableCourses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 10),
            child: Text(
              AppLocalizations.of(context)!.couldNotLoadVPlanData,
              style: TextStyle(
                color: Theme.of(context).focusColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableCourses.map((c) {
                String course = c['course']?.toString() ?? '';
                bool selected = selectedCourses.contains(course);
                return FilterChip(
                  label: Text(
                    c['teacher'] == null || c['teacher'] == ''
                        ? course
                        : '$course (${c['teacher']})',
                  ),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selectedCourses.add(course);
                      } else {
                        selectedCourses.remove(course);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        // 3. Sick days
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 20, bottom: 5),
          child: Text(
            AppLocalizations.of(context)!.selectSickDays,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 15, bottom: 10),
            child: Text(
              AppLocalizations.of(context)!.noSickDaysSelected,
              style: TextStyle(
                color: Theme.of(context).focusColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((day) {
                return InputChip(
                  label: Text(formatDay(day)),
                  onDeleted: () {
                    setState(() => days.remove(day));
                  },
                );
              }).toList(),
            ),
          ),
        Button(
          text: AppLocalizations.of(context)!.addDay,
          onPressed: _addDay,
        ),
        Button(
          text: AppLocalizations.of(context)!.save,
          onPressed: _save,
          filled: true,
        ),
      ],
    );
  }
}
