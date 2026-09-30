import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/PayloadCrypto.dart';
import '../crypto/Passphrase.dart';
import '../SchoolStorage.dart';
import 'NameGuard.dart';
import 'SyncApiClient.dart';
import 'SyncKeys.dart';
import 'SyncPayload.dart';

/// Wie ein Share beim Import behandelt wird.
///
/// Der Import kann die Daten entweder **so übernehmen, wie sie gespeichert
/// sind**, oder die Personen und Pläne auseinanderlösen und neu zusammenbauen.
/// Der dritte Weg ist wichtig, wenn die eigene Klassenstruktur anders ist als
/// die der teilenden Person: Eine fremde Klasse `7c` existiert lokal nicht,
/// und die Kurse darin gehören niemandem – die Person schon.
enum ShareImportMode {
  /// Genau so übernehmen, wie die Person es angelegt hat: `Hans` bleibt eine
  /// Person, `7c` bleibt eine Klasse, die Kurse bleiben die Kurse. Wer in
  /// einer ganz anderen Schule ist, sieht sie trotzdem als eigene Klassen.
  original,

  /// Jede übernommene Person wird zu einem **Plan**: die Kurse der Person
  /// werden zu einer Klasse zusammengefasst, sodass man sieht, wer wann
  /// welche Kurse unterrichtet.
  plans,

  /// Alles wird zu **Personen**: aus jeder Person, jeder Klasse und jedem Plan
  /// werden Namen gezogen.
  persons,
}

/// Was in einen Share aufgenommen wird.
///
/// Gespeichert wird die Auswahl im [LocalShare], damit sich ein Share später
/// mit derselben Auswahl erneut veröffentlichen lässt – sonst müsste der
/// Nutzer bei jeder Änderung alles neu auswählen.
class ShareSelection {
  const ShareSelection({
    this.classIds = const <String>{},
    this.personIds = const <String>{},
    this.includeSettings = false,
    this.includePlans = true,
    this.includeHistory = true,
  });

  /// Die ausgewählten Klassen, identified by their Kürzel – die App
  /// referenziert Klassen überall nur über das Kürzel.
  final Set<String> classIds;

  /// Die ausgewählten Personen, identified by their ID.
  final Set<String> personIds;

  /// Ob die Einstellungen mitgeteilt werden.
  final bool includeSettings;

  /// Ob die gespeicherten Vertretungspläne mitgeteilt werden.
  final bool includePlans;

  /// Ob Pläne aus der Vergangenheit mitgeteilt werden. Getrennt von
  /// [includePlans], weil ein langer vergangener Verlauf einen Share
  /// unverhältnismäßig groß machen kann.
  final bool includeHistory;

  bool get isEmpty => classIds.isEmpty && personIds.isEmpty;

  /// true, wenn mindestens etwas zum Teilen ausgewählt ist.
  bool get hasContent =>
      classIds.isNotEmpty ||
      personIds.isNotEmpty ||
      (includePlans && includeHistory);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'classIds': classIds.toList(),
        'personIds': personIds.toList(),
        'includeSettings': includeSettings,
        'includePlans': includePlans,
        'includeHistory': includeHistory,
      };

  static ShareSelection fromJson(Map<String, dynamic> json) => ShareSelection(
        classIds: <String>{
          ...?(json['classIds'] as List<dynamic>?)?.map((Object? e) => e.toString()),
        },
        personIds: <String>{
          ...?(json['personIds'] as List<dynamic>?)?.map((Object? e) => e.toString()),
        },
        includeSettings: json['includeSettings'] == true,
        includePlans: json['includePlans'] != false,
        includeHistory: json['includeHistory'] != false,
      );

  ShareSelection copyWith({
    Set<String>? classIds,
    Set<String>? personIds,
    bool? includeSettings,
    bool? includePlans,
    bool? includeHistory,
  }) =>
      ShareSelection(
        classIds: classIds ?? this.classIds,
        personIds: personIds ?? this.personIds,
        includeSettings: includeSettings ?? this.includeSettings,
        includePlans: includePlans ?? this.includePlans,
        includeHistory: includeHistory ?? this.includeHistory,
      );
}

/// Ein in der App angelegter Share.
class LocalShare {
  const LocalShare({
    required this.id,
    required this.username,
    required this.displayName,
    required this.label,
    required this.searchable,
    required this.isGlobal,
    required this.createdAt,
    required this.updatedAt,
    this.hasPassword = false,
    this.selection = const ShareSelection(),
  });

  final String id;
  final String username;
  final String displayName;
  final String label;

  /// Ob der Share im Suchmenü der eigenen Schule auftaucht.
  final bool searchable;

  /// Ob der Share auch von Nutzern **anderer** Schulen benutzt werden darf.
  final bool isGlobal;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ob der Share ein Passwort hat. Dann öffnen weder der Nutzername allein
  /// noch die Schulzugangsdaten den Share.
  final bool hasPassword;

  /// Was in diesen Share hineingegangen ist.
  final ShareSelection selection;

  /// Wie der Share in der eigenen Liste beschriftet wird.
  String get displayLabel => label.trim().isEmpty ? 'Share' : label.trim();

  LocalShare copyWith({
    String? label,
    bool? searchable,
    bool? isGlobal,
    DateTime? updatedAt,
    String? displayName,
    bool? hasPassword,
    ShareSelection? selection,
  }) =>
      LocalShare(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        label: label ?? this.label,
        searchable: searchable ?? this.searchable,
        isGlobal: isGlobal ?? this.isGlobal,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        hasPassword: hasPassword ?? this.hasPassword,
        selection: selection ?? this.selection,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'displayName': displayName,
        'label': label,
        'searchable': searchable,
        'isGlobal': isGlobal,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'hasPassword': hasPassword,
        'selection': selection.toJson(),
      };

  static LocalShare fromJson(Map<String, dynamic> json) => LocalShare(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        searchable: json['searchable'] == true,
        isGlobal: json['isGlobal'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        hasPassword: json['hasPassword'] == true,
        selection: json['selection'] is Map
            ? ShareSelection.fromJson(
                (json['selection'] as Map<String, dynamic>))
            : const ShareSelection(),
      );
}

/// Was ein Import bewirkt hat – für die Meldung danach.
class ShareImportResult {
  const ShareImportResult({
    required this.mode,
    required this.importedPersons,
    required this.importedClasses,
    required this.importedPlans,
    required this.displayName,
  });

  final ShareImportMode mode;
  final int importedPersons;
  final int importedClasses;
  final int importedPlans;

  /// Der Anzeigename der Person, von der der Share stammt.
  final String displayName;

  int get total => importedPersons + importedClasses + importedPlans;
}

/// Erzeugt, verwaltet und importiert Shares.
///
/// Ein Share ist bewusst **nicht** dasselbe wie eine Sync-Kette: Ein Sync
/// hält die eigenen Geräte automatisch auf dem neuesten Stand, ein Share ist
/// eine bewusste Übergabe an andere. Wer teilt, wählt deshalb aus, was
/// hineingeht; wer importiert, wählt aus, wie es hineinkommt.
///
/// ### Verschlüsselung
///
/// Der Server sieht nur unlesbare Hüllen. Damit die Daten mit drei
/// verschiedenen Mitteln zu öffnen sind – dem Nutzernamen, einem
/// Share-Passwort und den Schulzugangsdaten – enthält ein Share **mehrere
/// Hüllen** desselben Inhalts, jede mit einem anderen Schlüssel:
///
/// | Hülle        | Schlüssel wird abgeleitet aus         |
/// |--------------|---------------------------------------|
/// | `byUsername` | dem Share-Nutzernamen                 |
/// | `byPassword` | Nutzername + Share-Passwort           |
/// | `bySchool`   | Nutzername + Passwort der Schule       |
///
/// Ist ein Share passwortgeschützt, entfallen `byUsername` **und**
/// `bySchool`: Dann öffnet weder der Nutzername allein noch die
/// Schulzugangsdaten den Share – genau der Zweck des Passworts. Sonst
/// könnte jeder, dem die Schulzugangsdaten bekannt sind, die Person doch
/// finden.
class ShareManager {
  const ShareManager({required this.client});

  final SyncApiClient client;

  /// Trennung für die Ableitung der Hüllen-Schlüssel.
  static const String keyDomain = 'substitute/share/v1';

  /// Trennung für die Ableitung der Nutzernamen.
  static const String usernameDomain = 'substitute/share-username/v1';

  static const String sharesStorageKey = 'share.list';
  static const String usernameStorageKey = 'share.username';
  static const String displayNameStorageKey = 'share.displayName';
  static const String sharePasswordStorageKey = 'share.password';

  /// Pläne, die älter sind, gelten als "Vergangenheit" und können vom Teilen
  /// ausgenommen werden.
  static const int historyDays = 30;

  // ------------------------------------------------------------- Nutzername

  /// Erzeugt den Nutzernamen, unter dem die eigenen Shares erreichbar sind.
  ///
  /// Ebenfalls zehn echte englische Wörter – lesbar, vorlesbar und
  /// merkbar, statt einer Zeichenfolge wie bei einer UUID. Der Nutzername ist
  /// das, was man in einem Raum weitersagt; deshalb ist er bewusst getrennt
  /// von einem möglichen Passwort.
  static String generateUsername() => Passphrase.generate();

  /// Erzeugt ein Share-Passwort – ebenfalls zehn Wörter, aber nie identisch
  /// mit der Sync-Passphrase, weil der Schlüssel aus beiden gemeinsam
  /// abgeleitet wird.
  static String generateSharePassword() => Passphrase.generate();

  /// Die Kette, unter der die Shares dieses Nutzers liegen.
  ///
  /// Sie hängt an Nutzername **und** Schulnummer: Ein Nutzername aus einer
  /// anderen Schule findet so nicht dieselben Shares, und ein globaler Share
  /// muss trotzdem unter derselben ID liegen – deshalb wird für globale
  /// Shares dieselbe ID verwendet, der Nutzer gibt dann zusätzlich seine
  /// Schulnummer an.
  static String shareIdFor(String username, String schoolNumber) =>
      PayloadCrypto.publicId(
        '${Passphrase.normalize(username)}|${schoolNumber.trim()}',
        usernameDomain,
      );

  /// Die ID eines globalen Shares – unabhängig von der Schulnummer, weil er
  /// gerade von Nutzern anderer Schulen geöffnet werden soll.
  static String globalShareIdFor(String username) =>
      PayloadCrypto.publicId(Passphrase.normalize(username), '$usernameDomain:global');

  /// Der Schlüssel einer Hülle.
  ///
  /// [scope] ist die Schulnummer der **besitzenden** Person – bei einem
  /// globalen Share steht hier stattdessen [globalScope], weil die öffnende
  /// Person die Schulnummer gar nicht kennt. Ohne das könnte ein globaler
  /// Share von niemandem außerhalb der Besitzerschule geöffnet werden, und
  /// "global" wäre wirkungslos.
  static DerivedKey _keyFor(
    String username,
    String scope,
    String secret,
  ) =>
      PayloadCrypto.deriveKey(
        '${Passphrase.normalize(username)}|$scope|$secret',
        salt: keyDomain,
      );

  /// Der Ersatz für die Schulnummer bei globalen Shares.
  static const String globalScope = '@global';

  /// Der Schlüsselbereich, in dem ein Share liegt.
  static String scopeFor(String schoolNumber, {required bool isGlobal}) =>
      isGlobal ? globalScope : schoolNumber.trim();

  static String? readUsername(SharedPreferences prefs) =>
      prefs.getString(usernameStorageKey);

  static String? readDisplayName(SharedPreferences prefs) =>
      prefs.getString(displayNameStorageKey);

  static String? readSharePassword(SharedPreferences prefs) =>
      prefs.getString(sharePasswordStorageKey);

  /// Legt Nutzername und Anzeigename an, falls noch nicht vorhanden.
  static Future<({String username, String displayName})> ensureIdentity(
    SharedPreferences prefs,
  ) async {
    String? username = prefs.getString(usernameStorageKey);
    if (username == null || username.trim().isEmpty) {
      username = generateUsername();
      await prefs.setString(usernameStorageKey, username);
    }
    String? displayName = prefs.getString(displayNameStorageKey);
    if (displayName == null || displayName.trim().isEmpty) {
      displayName = suggestDisplayName(username);
      await prefs.setString(displayNameStorageKey, displayName);
    }
    return (username: username, displayName: displayName);
  }

  /// Schlägt aus dem Nutzernamen einen lesbaren Anzeigenamen vor.
  ///
  /// Zehn zufällige Wörter wären als Anzeigename unbrauchbar, deshalb werden
  /// zwei davon zu einem Namen verbunden. Der Vorschlag ist nur ein Vorschlag
  /// – frei wählbar, aber durch [NameGuard] geprüft.
  static String suggestDisplayName(String username) {
    final List<String> words = Passphrase.split(username);
    if (words.length < 2) return 'Kollege';
    return '${_capitalize(words[0])} ${_capitalize(words[1])}';
  }

  static String _capitalize(String word) =>
      word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

  /// Prüft einen gewünschten Anzeigenamen und speichert ihn.
  ///
  /// Gibt false zurück, wenn der Name nicht erlaubt ist; die UI zeigt dann
  /// [NameGuard.check]s Begründung an.
  static Future<bool> setDisplayName(SharedPreferences prefs, String name) async {
    final NameVerdict verdict = NameGuard.check(name);
    if (verdict.isBlocked) return false;
    await prefs.setString(displayNameStorageKey, name.trim());
    return true;
  }

  // ------------------------------------------------------------------ Shares

  /// Liest die eigenen Shares aus den lokalen Einstellungen.
  ///
  /// Die Liste ist immer veränderbar, damit Aufrufer sie direkt bearbeiten
  /// können (neuer Share anlegen, bestehenden ersetzen).
  static List<LocalShare> readShares(SharedPreferences prefs) {
    final String? raw = prefs.getString(sharesStorageKey);
    if (raw == null || raw.isEmpty) return <LocalShare>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <LocalShare>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LocalShare.fromJson)
          .where((LocalShare share) => share.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <LocalShare>[];
    }
  }

  static Future<void> _writeShares(
    SharedPreferences prefs,
    List<LocalShare> shares,
  ) =>
      prefs.setString(
        sharesStorageKey,
        jsonEncode(shares.map((LocalShare s) => s.toJson()).toList()),
      );

  /// Baut den Inhalt eines Shares aus den ausgewählten Daten zusammen.
  ///
  /// Es werden **nur** die ausgewählten Klassen und Personen übernommen: Wer
  /// eine Person teilt, gibt nicht automatisch die ganze Klasse mit. Pläne
  /// werden immer mitgenommen (sofern nicht abgewählt), weil sie zu den
  /// Klassen gehören, die mitgeteilt werden.
  static Future<Map<String, dynamic>> buildPayload(
    SharedPreferences prefs,
    ShareSelection selection, {
    String? deviceName,
  }) async {
    final String scope = scopeSuffix(prefs);

    final Map<String, List<Map<String, dynamic>>> source =
        await SyncDataReader.readParts(prefs, <String>[
      '${scope}classes',
      '${scope}classNames',
      '${scope}persons',
      '${scope}offlineVPData',
      '${scope}lessontimes',
      '${scope}teacherShorts',
    ]);

    // Klassen: nur die ausgewählten.
    final List<Map<String, dynamic>> classes = <Map<String, dynamic>>[];
    final Set<String> sharedClasses = <String>{};
    for (final Map<String, dynamic> item
        in source['${scope}classes'] ?? const <Map<String, dynamic>>[]) {
      final String short = classNameOf(item) ?? '';
      if (short.isEmpty || !selection.classIds.contains(short)) continue;
      classes.add(<String, dynamic>{'name': short, 'displayName': short});
      sharedClasses.add(short);
    }
    // Anzeigenamen der Klassen (z.B. "5a" -> "Klasse 5a, Gymnasium").
    for (final Map<String, dynamic> item
        in source['${scope}classNames'] ?? const <Map<String, dynamic>>[]) {
      final String short = classNameOf(item) ?? '';
      if (!sharedClasses.contains(short)) continue;
      final String display = item['displayName']?.toString() ?? '';
      if (display.isEmpty || display == short) continue;
      for (final Map<String, dynamic> target in classes) {
        if (target['name'] == short) target['displayName'] = display;
      }
    }

    // Personen: nur die ausgewählten. Die zugehörige Klasse wird
    // mitgenommen, damit die Kurse der Person einordbar bleiben.
    final List<Map<String, dynamic>> persons = <Map<String, dynamic>>[];
    final Set<String> impliedClasses = <String>{...sharedClasses};
    for (final Map<String, dynamic> item
        in source['${scope}persons'] ?? const <Map<String, dynamic>>[]) {
      final String id = item['id']?.toString() ?? '';
      if (!selection.personIds.contains(id)) continue;
      persons.add(item);
      final String classId = item['classId']?.toString() ?? '';
      if (classId.isNotEmpty) impliedClasses.add(classId);
    }
    // Klassen, die nur wegen einer Person mitkommen, stehen in `classes`.
    for (final Map<String, dynamic> item
        in source['${scope}classes'] ?? const <Map<String, dynamic>>[]) {
      final String short = classNameOf(item) ?? '';
      if (!impliedClasses.contains(short)) continue;
      if (classes.any((Map<String, dynamic> c) => c['name'] == short)) continue;
      classes.add(<String, dynamic>{'name': short, 'displayName': short});
    }

    // Pläne: die gespeicherten Vertretungspläne, ggf. auf die letzten
    // [historyDays] Tage beschränkt.
    final List<Map<String, dynamic>> plans = <Map<String, dynamic>>[];
    if (selection.includePlans) {
      for (final Map<String, dynamic> item in source['${scope}offlineVPData'] ??
          const <Map<String, dynamic>>[]) {
        final String date = planDateOf(item) ?? '';
        if (!selection.includeHistory && !isRecent(date)) continue;
        plans.add(item);
      }
    }

    final Map<String, dynamic> settings = <String, dynamic>{};
    if (selection.includeSettings) {
      settings.addAll(await SyncDataReader.readSettings(
        prefs,
        SyncKeys.settingKeys.map((String key) => '$scope$key').toList(),
      ));
    }

    return SyncPayload(
      parts: <SyncPart>[
        if (classes.isNotEmpty)
          SyncPayload.describePart('${scope}classes', classes),
        if (persons.isNotEmpty)
          SyncPayload.describePart('${scope}persons', persons),
        if (plans.isNotEmpty)
          SyncPayload.describePart('${scope}offlineVPData', plans),
        // Kurzstunden und Lehrerkürzel: ohne sie ist ein Plan nicht lesbar.
        for (final String key in <String>['lessontimes', 'teacherShorts'])
          if ((source['$scope$key'] ?? const <Map<String, dynamic>>[]).isNotEmpty)
            SyncPayload.describePart('$scope$key', source['$scope$key']!),
      ],
      tombstones: const <SyncTombstone>[],
      settings: settings,
      updatedAt: DateTime.now().toUtc(),
      deviceName: deviceName ?? '',
    ).toJson();
  }

  // ------------------------------------------------------------ Veröffentlichen

  /// Verschlüsselt [payload] und veröffentlicht den Share.
  ///
  /// Ohne [sharePassword] ist der Share über den Nutzernamen **und** über die
  /// Schulzugangsdaten zu öffnen. Mit Passwort nur über das Passwort – das
  /// Passwort schützt also gerade auch vor Leuten, denen die
  /// Schulzugangsdaten bekannt sind.
  Future<LocalShare> publish({
    required SharedPreferences prefs,
    required String schoolNumber,
    required String schoolPassword,
    required String displayName,
    required String label,
    required Map<String, dynamic> payload,
    required ShareSelection selection,
    required bool searchable,
    required bool isGlobal,
    String? sharePassword,
  }) async {
    final String username = readUsername(prefs) ?? '';
    if (username.isEmpty) throw const ShareException('noUsername');

    final NameVerdict verdict = NameGuard.check(displayName);
    if (verdict.isBlocked) {
      throw ShareException('nameBlocked', detail: verdict.matchedTerm);
    }
    if (selection.isEmpty) {
      throw const ShareException('nothingSelected');
    }

    final String shareId =
        isGlobal ? globalShareIdFor(username) : shareIdFor(username, schoolNumber);
    final bool protected = sharePassword != null && sharePassword.trim().isNotEmpty;
    // Bei einem globalen Share darf die Schulnummer der Besitzerin nicht in
    // den Schlüssel eingehen – sie kennt die öffnende Person nicht.
    final String scope = scopeFor(schoolNumber, isGlobal: isGlobal);

    final Map<String, dynamic> envelopes = <String, dynamic>{};
    if (protected) {
      envelopes[ShareSlot.byPassword.id] = PayloadCrypto.encryptJson(
        _keyFor(username, scope, Passphrase.normalize(sharePassword)),
        payload,
        salt: keyDomain,
      );
    } else {
      envelopes[ShareSlot.byUsername.id] = PayloadCrypto.encryptJson(
        _keyFor(username, scope, ''),
        payload,
        salt: keyDomain,
      );
      envelopes[ShareSlot.bySchool.id] = PayloadCrypto.encryptJson(
        _keyFor(username, scope, schoolPassword),
        payload,
        salt: keyDomain,
      );
    }

    final DateTime now = DateTime.now().toUtc();
    await client.publishShare(
      shareId: shareId,
      username: username,
      schoolNumber: schoolNumber,
      displayName: displayName,
      label: label,
      envelopes: envelopes,
      searchable: searchable,
      isGlobal: isGlobal,
      updatedAt: now,
    );

    final LocalShare share = LocalShare(
      id: shareId,
      username: username,
      displayName: displayName,
      label: label,
      searchable: searchable,
      isGlobal: isGlobal,
      createdAt: now,
      updatedAt: now,
      hasPassword: protected,
      selection: selection,
    );

    final List<LocalShare> shares = readShares(prefs)
      ..removeWhere((LocalShare s) => s.id == shareId)
      ..add(share);
    await _writeShares(prefs, shares);
    if (protected) {
      await prefs.setString(sharePasswordStorageKey, sharePassword);
    }
    return share;
  }

  /// Ändert die Eigenschaften eines eigenen Shares und lädt ihn neu hoch.
  ///
  /// Der **Inhalt** wird dabei neu aus der gespeicherten Auswahl gebaut – der
  /// Nutzer muss also nicht erneut auswählen, bekommt aber trotzdem frische
  /// Daten, wenn inzwischen etwas dazugekommen ist.
  Future<void> update({
    required SharedPreferences prefs,
    required String schoolNumber,
    required String schoolPassword,
    required LocalShare share,
    String? label,
    bool? searchable,
    bool? isGlobal,
    String? displayName,
    ShareSelection? selection,
  }) async {
    final ShareSelection effective = selection ?? share.selection;
    final Map<String, dynamic> payload =
        await buildPayload(prefs, effective);

    final LocalShare updated = share.copyWith(
      label: label,
      searchable: searchable,
      isGlobal: isGlobal,
      displayName: displayName,
      selection: effective,
      updatedAt: DateTime.now().toUtc(),
    );

    await publish(
      prefs: prefs,
      schoolNumber: schoolNumber,
      schoolPassword: schoolPassword,
      displayName: updated.displayName,
      label: updated.label,
      payload: payload,
      selection: effective,
      searchable: updated.searchable,
      isGlobal: updated.isGlobal,
      sharePassword: share.hasPassword ? readSharePassword(prefs) : null,
    );
  }

  /// Löscht einen Share beim Server und aus der eigenen Liste.
  Future<void> remove(SharedPreferences prefs, String shareId) async {
    try {
      await client.deleteShare(shareId);
    } on SyncException {
      // Lokal wird er trotzdem entfernt: Ein Share, den niemand mehr
      // hochlädt, soll nicht ewig in der Liste stehen.
    }
    final List<LocalShare> remaining = readShares(prefs)
        .where((LocalShare s) => s.id != shareId)
        .toList();
    await _writeShares(prefs, remaining);
  }

  // ------------------------------------------------------------------ Import

  /// Welche Hüllen dieses Share anbietet – für die Oberfläche, damit sie
  /// gezielt nach dem Passwort fragen kann.
  static bool canUnlockWithUsername(ShareRecord record) =>
      record.envelopes.containsKey(ShareSlot.byUsername.id);

  static bool canUnlockWithPassword(ShareRecord record) =>
      record.envelopes.containsKey(ShareSlot.byPassword.id);

  static bool canUnlockWithSchool(ShareRecord record) =>
      record.envelopes.containsKey(ShareSlot.bySchool.id);

  /// Öffnet einen Share.
  ///
  /// [schoolNumber] ist die Schulnummer der eingebenden Person. Sie wird nur
  /// dann gebraucht, wenn der Share **nicht** global ist: Bei einem
  /// normalen Share geht die Schulnummer der Besitzerin in den Schlüssel ein,
  /// und die muss man kennen. Bei einem globalen Share wird stattdessen
  /// [globalScope] verwendet – deshalb funktioniert er auch von einer anderen
  /// Schule aus.
  static Map<String, dynamic> unlock(
    ShareRecord record,
    String username, {
    required String schoolNumber,
    String? sharePassword,
    String? schoolPassword,
  }) {
    final String scope = scopeFor(schoolNumber, isGlobal: record.isGlobal);
    final List<({String slot, String secret})> candidates =
        <({String slot, String secret})>[];

    if (sharePassword != null && sharePassword.trim().isNotEmpty) {
      candidates.add((
        slot: ShareSlot.byPassword.id,
        secret: Passphrase.normalize(sharePassword),
      ));
    }
    if (record.envelopes.containsKey(ShareSlot.byUsername.id)) {
      candidates.add((slot: ShareSlot.byUsername.id, secret: ''));
    }
    if (schoolPassword != null && schoolPassword.trim().isNotEmpty) {
      candidates.add((
        slot: ShareSlot.bySchool.id,
        secret: schoolPassword,
      ));
    }

    for (final ({String slot, String secret}) candidate in candidates) {
      final Object? envelope = record.envelopes[candidate.slot];
      if (envelope is! Map<String, dynamic>) continue;
      try {
        return PayloadCrypto.decryptJson(
          _keyFor(username, scope, candidate.secret),
          envelope,
        );
      } on PayloadCryptoException {
        // Falscher Schlüssel für diese Hülle – die nächste versuchen.
        continue;
      }
    }
    throw const ShareException('wrongCredentials');
  }

  /// Wie viele Klassen und Personen ein geöffneter Share enthält – für die
  /// Vorauswahl in der Import-Oberfläche.
  static ({int classes, int persons, int plans}) countContents(
    Map<String, dynamic> payload,
  ) {
    final SyncPayload data = _readPayload(payload);
    int classes = 0;
    int persons = 0;
    int plans = 0;
    for (final SyncPart part in data.parts) {
      if (part.key.endsWith('classes')) classes += part.items.length;
      if (part.key.endsWith('persons')) persons += part.items.length;
      if (part.key.endsWith('offlineVPData')) plans += part.items.length;
    }
    return (classes: classes, persons: persons, plans: plans);
  }

  /// Schreibt einen geöffneten Share in die lokalen Daten.
  ///
  /// Der Import ist **nicht destruktiv**: Vorhandene Klassen und Personen
  /// bleiben, die importierten kommen hinzu. Nur die Kürzel werden
  /// entkollidiert, damit eine importierte Klasse `7c` nicht die lokale
  /// Klasse `7c` überschreibt.
  static Future<ShareImportResult> applyImport(
    SharedPreferences prefs,
    Map<String, dynamic> payload, {
    required ShareImportMode mode,
    required String displayName,
  }) async {
    final SyncPayload data = _readPayload(payload);
    final String scope = scopeSuffix(prefs);

    // Die Kürzel, die es lokal schon gibt.
    final Set<String> usedShorts = (prefs.getStringList('${scope}classes') ??
            const <String>[])
        .map(classNameOfRaw)
        .whereType<String>()
        .toSet();

    final List<Map<String, dynamic>> newPersons = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> newClasses = <Map<String, dynamic>>[];
    final List<String> newPlans = <String>[];

    /// Vergibt einen freien Kürzel und merkt ihn sich.
    String nextShort(String base) {
      final String cleaned = _shortenClassName(base);
      if (usedShorts.add(cleaned)) return cleaned;
      for (int counter = 2;; counter++) {
        final String candidate = _shortenClassName('$base $counter');
        if (usedShorts.add(candidate)) return candidate;
      }
    }

    /// Die Kurse einer Person.
    List<String> coursesOf(Map<String, dynamic> person) =>
        stringList(person['courses']);

    switch (mode) {
      case ShareImportMode.original:
        // 1:1 übernehmen. Die fremden Klassennummern bleiben erhalten – das ist
        // der Sinn von "Original" – und die Personen behalten ihre Kurse.
        final Map<String, String> classMapping = <String, String>{};
        for (final SyncPart part in data.parts) {
          if (!part.key.endsWith('classes')) continue;
          for (final Map<String, dynamic> item in part.items) {
            final String short = classNameOf(item) ?? '';
            if (short.isEmpty) continue;
            final String unique = nextShort(short);
            classMapping[short] = unique;
            newClasses.add(<String, dynamic>{
              'name': unique,
              'displayName': item['displayName']?.toString() ?? short,
            });
          }
        }
        for (final SyncPart part in data.parts) {
          if (part.key.endsWith('offlineVPData')) {
            for (final Map<String, dynamic> item in part.items) {
              newPlans.add(jsonEncode(item));
            }
          }
        }
        for (final SyncPart part in data.parts) {
          if (!part.key.endsWith('persons')) continue;
          for (final Map<String, dynamic> item in part.items) {
            final String name = item['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            final String originalClass = item['classId']?.toString() ?? '';
            newPersons.add(<String, dynamic>{
              'id': _importedId(displayName, name, newPersons.length),
              'name': name,
              'classId': classMapping[originalClass] ?? originalClass,
              'courses': coursesOf(item),
              'importedFrom': displayName,
            });
          }
        }

      case ShareImportMode.plans:
        // Jede Person wird zu einem Plan: eine Klasse mit ihrem Namen und je
        // ein Plan-Eintrag pro Kurs. So sieht man, wer wann welchen Kurs
        // hatte, ohne die fremde Klassenstruktur zu übernehmen.
        for (final SyncPart part in data.parts) {
          if (!part.key.endsWith('persons')) continue;
          for (final Map<String, dynamic> item in part.items) {
            final String name = item['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            final String short = nextShort(name);
            newClasses.add(<String, dynamic>{
              'name': short,
              'displayName': name,
              'importedFrom': displayName,
            });
            for (final String course in coursesOf(item)) {
              newPlans.add(jsonEncode(<String, dynamic>{
                'date': 'import-${DateTime.now().toUtc().millisecondsSinceEpoch}',
                'name': '$name – $course',
                'classes': <String>[short],
                'courses': <String>[course],
                'importedFrom': displayName,
                '_importedAs': 'plan',
              }));
            }
          }
        }

      case ShareImportMode.persons:
        // Aus allem wird ein Name: aus jeder Person, jeder Klasse und jedem
        // Plan. Die Namen werden zu je einer Person mit eigener Klasse.
        final Set<String> seen = <String>{};
        void addAsPerson(String rawName, List<String> courses) {
          final String name = rawName.trim();
          if (name.isEmpty || !seen.add(name)) return;
          final String short = nextShort(name);
          newClasses.add(<String, dynamic>{
            'name': short,
            'displayName': name,
            'importedFrom': displayName,
          });
          newPersons.add(<String, dynamic>{
            'id': _importedId(displayName, name, newPersons.length),
            'name': name,
            'classId': short,
            'courses': courses,
            'importedFrom': displayName,
          });
        }

        for (final SyncPart part in data.parts) {
          if (part.key.endsWith('persons')) {
            for (final Map<String, dynamic> item in part.items) {
              addAsPerson(item['name']?.toString() ?? '', coursesOf(item));
            }
          } else if (part.key.endsWith('classes')) {
            for (final Map<String, dynamic> item in part.items) {
              addAsPerson(
                item['displayName']?.toString() ?? classNameOf(item) ?? '',
                const <String>[],
              );
            }
          } else if (part.key.endsWith('offlineVPData')) {
            for (final Map<String, dynamic> item in part.items) {
              addAsPerson(item['name']?.toString() ?? '', const <String>[]);
            }
          }
        }
    }

    // Und schreiben. Vorhandenes bleibt erhalten.
    if (newClasses.isNotEmpty) {
      // `getStringList` liefert eine unveränderliche Liste – deshalb wird
      // vor dem Anhängen kopiert.
      final List<String> merged = <String>[
        ...?prefs.getStringList('${scope}classes'),
      ];
      for (final Map<String, dynamic> item in newClasses) {
        merged.add(jsonEncode(<String, dynamic>{'name': item['name']}));
      }
      await prefs.setStringList('${scope}classes', merged);

      final Map<String, dynamic> names =
          (prefs.getString('${scope}classNames') != null)
              ? Map<String, dynamic>.of(
                  (jsonDecode(prefs.getString('${scope}classNames')!) as Map)
                      .cast<String, dynamic>(),
                )
              : <String, dynamic>{};
      for (final Map<String, dynamic> item in newClasses) {
        final String short = item['name'].toString();
        final String display = item['displayName']?.toString() ?? short;
        if (display.isNotEmpty && display != short) {
          names[short] = <String, dynamic>{
            'id': short,
            'displayName': display,
            'importedFrom': displayName,
          };
        }
      }
      if (names.isNotEmpty) {
        await prefs.setString('${scope}classNames', jsonEncode(names));
      }
    }
    if (newPersons.isNotEmpty) {
      final List<String> merged = <String>[
        ...?prefs.getStringList('${scope}persons'),
      ];
      merged.addAll(newPersons.map(jsonEncode));
      await prefs.setStringList('${scope}persons', merged);
    }
    if (newPlans.isNotEmpty) {
      final List<String> merged = <String>[
        ...?prefs.getStringList('${scope}offlineVPData'),
      ];
      merged.addAll(newPlans);
      await prefs.setStringList('${scope}offlineVPData', merged);
    }

    return ShareImportResult(
      mode: mode,
      importedPersons: newPersons.length,
      importedClasses: newClasses.length,
      importedPlans: newPlans.length,
      displayName: displayName,
    );
  }

  // ----------------------------------------------------------------- Helfer

  static SyncPayload _readPayload(Map<String, dynamic> payload) {
    try {
      return SyncPayload.fromJson(payload);
    } on FormatException catch (error) {
      throw ShareException('unreadable', detail: error.message);
    }
  }

  /// Der Suffix, den `SchoolStorage` für die aktive Schule verwendet.
  static String scopeSuffix(SharedPreferences prefs) {
    final String schoolId = SchoolStorage.activeSchoolId(prefs);
    if (schoolId == SchoolStorage.defaultSchoolId) return '';
    return 'schools.$schoolId.';
  }

  /// Der Kürzel eines Klassen-Eintrags, oder null, wenn keiner lesbar ist.
  static String? classNameOf(Map<String, dynamic> item) {
    final String name = item['name']?.toString() ?? '';
    return name.isEmpty ? null : name;
  }

  /// Dasselbe für den rohen JSON-String aus `SharedPreferences`.
  static String? classNameOfRaw(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return classNameOf(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<String> stringList(Object? value) => value is List
      ? value.map((Object? e) => e.toString()).toList()
      : const <String>[];

  /// Das Datum eines Planeintrags – auch aus der verschachtelten Form der
  /// API (`data.Kopf.DatumPlan`).
  static String? planDateOf(Map<String, dynamic> item) {
    final Object? date = item['date'] ?? _nestedPlanDate(item['data']);
    return date?.toString();
  }

  static Object? _nestedPlanDate(Object? data) {
    if (data is! Map) return null;
    final Object? kopf = data['Kopf'];
    return kopf is Map ? kopf['DatumPlan'] : null;
  }

  /// Ist ein Plan jünger als [historyDays]?
  static bool isRecent(String date) {
    if (date.isEmpty) return false;
    final DateTime? parsed = parsePlanDate(date);
    if (parsed == null) return false;
    return parsed.isAfter(
      DateTime.now().subtract(const Duration(days: historyDays)),
    );
  }

  /// Liest das Datum eines Plans – in den Formen, die die App schreibt
  /// (`yyyy-MM-dd`, `dd.MM.yyyy`) und die die API liefert
  /// (`Montag, 22. August 2025`).
  static DateTime? parsePlanDate(String raw) {
    final String trimmed = raw.trim();
    // '2026-09-30' und '2026-09-30 08:00:00' gehen direkt.
    final DateTime? iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final RegExp numeric = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');
    final Match? numbers = numeric.firstMatch(trimmed);
    if (numbers != null) {
      return DateTime(
        int.parse(numbers.group(3)!),
        int.parse(numbers.group(2)!),
        int.parse(numbers.group(1)!),
      );
    }

    final RegExp german = RegExp(r'(\d{1,2})\.\s*([A-Za-zä]+)\s+(\d{4})');
    final Match? match = german.firstMatch(trimmed);
    if (match != null) {
      final int month = _germanMonths
          .indexOf(_foldGerman(match.group(2)!))
          .toInt() +
          1;
      if (month > 0) {
        return DateTime(
          int.parse(match.group(3)!),
          month,
          int.parse(match.group(1)!),
        );
      }
    }
    return null;
  }

  /// 'März' und 'Maerz' sollen dasselbe sein.
  static String _foldGerman(String month) {
    const Map<String, String> umlauts = <String, String>{
      'ä': 'ae',
      'ö': 'oe',
      'ü': 'ue',
    };
    String result = month.toLowerCase();
    umlauts.forEach((String from, String to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  static const List<String> _germanMonths = <String>[
    'januar', 'februar', 'maerz', 'april', 'mai', 'juni', 'juli', //
    'august', 'september', 'oktober', 'november', 'dezember',
  ];

  /// Eine ID für einen importierten Eintrag.
  ///
  /// Abgeleitet aus Anzeigename, Namen und Position, damit ein zweiter Import
  /// desselben Shares die gleichen IDs erzeugt (wiedererkennbar) und keine
  /// Kollision mit lokalen IDs entsteht.
  static String _importedId(String displayName, String name, int index) =>
      'import-$index-${NameGuard.normalize(displayName)}'
      '-${NameGuard.normalize(name)}';

  /// Macht aus einem langen Klassennamen ein Kürzel: höchstens drei Wörter und
  /// höchstens zwölf Zeichen, damit es noch in eine Klassenliste passt.
  static String _shortenClassName(String name) {
    final List<String> words = name
        .split(RegExp(r'[\s,]+'))
        .where((String word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'Klasse';

    final List<String> kept = <String>[];
    int length = 0;
    for (final String word in words) {
      final int next = length + (kept.isEmpty ? 0 : 1) + word.length;
      if (kept.isNotEmpty && next > 12) break;
      kept.add(word);
      length = next;
    }
    String result = kept.join(' ');
    if (result.length > 12) result = result.substring(0, 12).trim();
    return result.isEmpty ? 'Klasse' : result;
  }
}

/// Fehler beim Teilen oder Importieren.
class ShareException implements Exception {
  const ShareException(this.code, {this.detail});

  /// Der Fehlercode, z.B. `nameBlocked`, `wrongCredentials`, `noUsername`.
  final String code;

  /// Zusatzinformation für die Anzeige, z.B. das blockierte Wort.
  final String? detail;

  @override
  String toString() => 'ShareException($code${detail == null ? '' : ', $detail'})';
}
