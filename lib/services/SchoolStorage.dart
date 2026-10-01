import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/AppClock.dart';

class SchoolProfile {
  SchoolProfile({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory SchoolProfile.fromJson(Map<String, dynamic> json) {
    return SchoolProfile(
      id: json['id']?.toString() ?? SchoolStorage.defaultSchoolId,
      name: json['name']?.toString() ?? 'Meine Schule',
    );
  }

  SchoolProfile copyWith({String? name}) {
    return SchoolProfile(
      id: id,
      name: name ?? this.name,
    );
  }
}

class SchoolStorage {
  static const String defaultSchoolId = 'default';
  static const String _profilesKey = 'schoolProfiles';
  static const String _activeSchoolKey = 'activeSchoolId';

  static String activeSchoolId(SharedPreferences prefs) {
    return prefs.getString(_activeSchoolKey) ?? defaultSchoolId;
  }

  static String scopedKey(SharedPreferences prefs, String key) {
    final String schoolId = activeSchoolId(prefs);
    if (schoolId == defaultSchoolId) return key;
    return 'schools.$schoolId.$key';
  }

  /// Dasselbe für eine **benannte** Schule statt für die gerade aktive.
  ///
  /// Nötig für alles, das über alle Schulen hinweg etwas in Ordnung bringen
  /// soll – etwa die Klassenliste. `scopedKey` sieht immer nur nach der
  /// aktiven Schule, und wer nur sie repariert, lässt die Listen der anderen
  /// unverändert stehen; die tauchen dann wieder auf, sobald jemand umschaltet.
  static String keyForSchool(String schoolId, String key) {
    if (schoolId == defaultSchoolId) return key;
    return 'schools.$schoolId.$key';
  }

  /// Die Kennungen aller Schulen, für die es Daten gibt – die aktive zuerst.
  ///
  /// Gesucht wird in **zwei** Quellen, und das ist Absicht:
  ///
  /// * der Profilliste, damit jede angelegte Schule vorkommt, auch wenn für sie
  ///   noch nichts gespeichert wurde;
  /// * den gespeicherten Schlüsseln, damit auch die Daten einer **verwaisten**
  ///   Schule gefunden werden – ein Profil wurde gelöscht, die Daten sind aber
  ///   noch da. Aus der Profilliste allein würde sie nicht gefunden, ihre
  ///   Klassen blieben unsortiert und tauchten beim Umschalten wieder auf.
  ///
  /// `ensureInitialized` wird bewusst **nicht** aufgerufen: Diese Liste dient
  /// dem Reparieren, und das Anlegen eines Profils gehört nicht dazu.
  static List<String> allSchoolIds(SharedPreferences prefs) {
    final List<String> ids = <String>[activeSchoolId(prefs)];

    final String? raw = prefs.getString(_profilesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final Object? entry in decoded) {
            if (entry is! Map) continue;
            final String id = entry['id']?.toString() ?? defaultSchoolId;
            if (!ids.contains(id)) ids.add(id);
          }
        }
      } catch (_) {
        // Beschädigte Profilliste: Es bleibt bei der aktiven Schule – besser so,
        // als Profile zu erfinden, die es nicht gibt. Der Schlüssel-Durchgang
        // unten findet deren Daten trotzdem.
      }
    }

    for (final String key in prefs.getKeys()) {
      final String? id = _schoolIdOfKey(key);
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// `schools.<id>.classes` -> `<id>`, sonst null.
  static String? _schoolIdOfKey(String key) {
    const String praefix = 'schools.';
    if (!key.startsWith(praefix)) return null;
    final int punkt = key.indexOf('.', praefix.length);
    if (punkt <= praefix.length) return null;
    return key.substring(praefix.length, punkt);
  }

  static Future<void> ensureInitialized(SharedPreferences prefs) async {
    if (prefs.getString(_profilesKey) != null) return;

    String schoolName = 'Meine Schule';
    final String? schoolNumber = prefs.getString('vplanSchoolnumber');
    if (schoolNumber != null && schoolNumber.trim().isNotEmpty) {
      schoolName = 'Schule $schoolNumber';
    }

    await prefs.setString(
      _profilesKey,
      jsonEncode([
        SchoolProfile(id: defaultSchoolId, name: schoolName).toJson(),
      ]),
    );
    await prefs.setString(_activeSchoolKey, defaultSchoolId);
  }

  static Future<List<SchoolProfile>> getProfiles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await ensureInitialized(prefs);
    final String? raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<SchoolProfile> profiles = decoded
          .map((e) => SchoolProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (profiles.isEmpty) {
        return [SchoolProfile(id: defaultSchoolId, name: 'Meine Schule')];
      }
      return profiles;
    } catch (e) {
      return [SchoolProfile(id: defaultSchoolId, name: 'Meine Schule')];
    }
  }

  static Future<void> saveProfiles(List<SchoolProfile> profiles) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((school) => school.toJson()).toList()),
    );
  }

  static Future<SchoolProfile> getActiveProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<SchoolProfile> profiles = await getProfiles();
    if (profiles.isEmpty) {
      final SchoolProfile fallback =
          SchoolProfile(id: defaultSchoolId, name: 'Meine Schule');
      await saveProfiles([fallback]);
      await prefs.setString(_activeSchoolKey, defaultSchoolId);
      return fallback;
    }
    final String activeId = activeSchoolId(prefs);
    return profiles.firstWhere(
      (school) => school.id == activeId,
      orElse: () => profiles.first,
    );
  }

  /// Prüft, ob für die aktive Schule Zugangsdaten (Benutzername) hinterlegt
  /// sind.
  static Future<bool> hasCredentials([SharedPreferences? prefs]) async {
    final SharedPreferences instance =
        prefs ?? await SharedPreferences.getInstance();
    final String? username =
        instance.getString(scopedKey(instance, 'vplanUsername'));
    return username != null && username.trim().isNotEmpty;
  }

  static Future<void> setActiveSchool(String schoolId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await ensureInitialized(prefs);
    await prefs.setString(_activeSchoolKey, schoolId);
  }

  static Future<SchoolProfile> addSchool(String name) async {
    final List<SchoolProfile> profiles = await getProfiles();
    final SchoolProfile school = SchoolProfile(
      id: AppClock.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Neue Schule' : name.trim(),
    );
    profiles.add(school);
    await saveProfiles(profiles);
    return school;
  }

  static Future<void> renameSchool(String schoolId, String name) async {
    final List<SchoolProfile> profiles = await getProfiles();
    final List<SchoolProfile> renamed = profiles
        .map(
          (school) => school.id == schoolId
              ? school.copyWith(name: name.trim().isEmpty ? school.name : name)
              : school,
        )
        .toList();
    await saveProfiles(renamed);
  }

  static Future<void> deleteSchool(String schoolId) async {
    if (schoolId == defaultSchoolId) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<SchoolProfile> profiles = await getProfiles();
    final List<SchoolProfile> remaining =
        profiles.where((school) => school.id != schoolId).toList();
    if (remaining.isEmpty) return;

    await saveProfiles(remaining);
    if (activeSchoolId(prefs) == schoolId) {
      await prefs.setString(_activeSchoolKey, remaining.first.id);
    }
  }
}
