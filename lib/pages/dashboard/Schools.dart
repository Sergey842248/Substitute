import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:page_transition/page_transition.dart';
import 'package:substitute/main.dart';
import 'package:substitute/models/ListItem.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/pages/dashboard/settings/VPlanLogin.dart';
import 'package:substitute/services/SchoolStorage.dart';

class Schools extends StatefulWidget {
  const Schools({Key? key}) : super(key: key);

  @override
  State<Schools> createState() => _SchoolsState();
}

class _SchoolsState extends State<Schools> {
  List<SchoolProfile> schools = [];
  String activeSchoolId = SchoolStorage.defaultSchoolId;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    final profiles = await SchoolStorage.getProfiles();
    final active = await SchoolStorage.getActiveProfile();
    if (!mounted) return;
    setState(() {
      schools = profiles;
      activeSchoolId = active.id;
    });
  }

  Future<String?> _askSchoolName({String? initialName}) {
    final controller = TextEditingController(text: initialName ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          initialName == null ? 'Schule hinzufügen' : 'Schule umbenennen',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Name der Schule'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              'Speichern',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSchool() async {
    final String? name = await _askSchoolName();
    if (name == null || name.trim().isEmpty) return;

    final school = await SchoolStorage.addSchool(name);
    await SchoolStorage.setActiveSchool(school.id);
    if (!mounted) return;

    await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: VPlanLogin(),
      ),
    );
    await _loadSchools();
  }

  Future<void> _renameSchool(SchoolProfile school) async {
    final String? name = await _askSchoolName(initialName: school.name);
    if (name == null || name.trim().isEmpty) return;
    await SchoolStorage.renameSchool(school.id, name);
    await _loadSchools();
  }

  Future<void> _deleteSchool(SchoolProfile school) async {
    if (school.id == SchoolStorage.defaultSchoolId) {
      Fluttertoast.showToast(
          msg: 'Die erste Schule bleibt als Standard erhalten.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Schule löschen?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: Text(
          'Die Schule wird aus der Auswahl entfernt. Ihre gespeicherten Bereichsdaten bleiben auf dem Gerät unangetastet.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await SchoolStorage.deleteSchool(school.id);
    await _loadSchools();
  }

  Future<void> _activateSchool(SchoolProfile school) async {
    await SchoolStorage.setActiveSchool(school.id);
    Fluttertoast.showToast(msg: '${school.name} ist jetzt aktiv');
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePageWithVPlanTab()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListPage(
        title: 'Schulen',
        actions: [
          IconButton(
            onPressed: _addSchool,
            icon: Icon(Icons.add_rounded),
          ),
        ],
        children: [
          ...schools.map((school) {
            final bool active = school.id == activeSchoolId;
            return ListItem(
              leading: Icon(
                active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: active ? Theme.of(context).primaryColor : null,
              ),
              title: Text(
                school.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                active
                    ? 'Aktive Schule'
                    : 'Antippen, um diese Schule zu nutzen',
              ),
              actionButton: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _renameSchool(school),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_rounded, size: 20),
                    onPressed: () => _deleteSchool(school),
                  ),
                ],
              ),
              onClick: () => _activateSchool(school),
            );
          }),
          ListItem(
            leading: Icon(Icons.add_rounded),
            title: Text(
              'Schule hinzufügen',
              style: TextStyle(fontSize: 18),
            ),
            subtitle:
                Text('Legt einen eigenen Bereich mit eigenen Zugangsdaten an'),
            onClick: _addSchool,
          ),
        ],
      ),
    );
  }
}
