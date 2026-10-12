import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Alles wird zu **Klassen**: jede übernommene Klasse und jede übernommene
  /// Person wird eine Klasse. Aus einer Person `Hans` mit den Kursen Deutsch
  /// und Mathe wird also die Klasse `Hans`, und die Kurse bleiben an ihr
  /// hängen – es werden **keine** weiteren Klassen und **keine** Pläne
  /// erzeugt. Vorher stand hier je ein zusätzlicher Plan „Hans – Deutsch“,
  /// „Hans – Mathe“ …, der nichts brachte außer einer Unmenge Zeilen in der
  /// Planliste.
  plans,

  /// Alles wird zu **Personen**: jede übernommene Klasse und jede übernommene
  /// Person wird eine Person mit einer eigenen Klasse dazu.
  persons,
}

/// Was aus einem geöffneten Share **ausgewählt** übernommen wird.
///
/// Der Import ist nicht destruktiv, aber er ist auch nicht blind: Wer einen
/// fremden Share öffnet, will in aller Regel *einige* Klassen und Personen
/// sehen, nicht den kompletten Bestand einer Kollegin. Deshalb werden hier
/// die gewählten Kürzel und IDs festgehalten – leer heißt „nichts davon
/// übernehmen“, das ist ein gültiger Zustand und kein Fehler.
///
/// Gespeichert wird das nicht: Die Auswahl gehört zum einmaligen Import und
/// wäre beim nächsten Share ohnehin wieder anders.
class ShareImportSelection {
  const ShareImportSelection({
    this.classIds = const <String>{},
    this.personIds = const <String>{},
    this.includePlans = true,
  });

  /// Die ausgewählten Klassen, identified by their Kürzel.
  final Set<String> classIds;

  /// Die ausgewählten Personen, identified by their ID.
  final Set<String> personIds;

  /// Ob die zwischengespeicherten Pläne des Shares mit übernommen werden.
  ///
  /// Voreingestellt an: Die Pläne sind der eigentliche Inhalt eines
  /// Vertretungsplans, und wer sie nicht braucht, schaltet sie ab.
  final bool includePlans;

  bool get isEmpty => classIds.isEmpty && personIds.isEmpty && !includePlans;

  /// Nichts ausgewählt – weder Klassen noch Personen noch Pläne.
  bool get hasNothing =>
      classIds.isEmpty && personIds.isEmpty && !includePlans;

  ShareImportSelection copyWith({
    Set<String>? classIds,
    Set<String>? personIds,
    bool? includePlans,
  }) =>
      ShareImportSelection(
        classIds: classIds ?? this.classIds,
        personIds: personIds ?? this.personIds,
        includePlans: includePlans ?? this.includePlans,
      );
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
    this.includeHistory = true,
  });

  /// Die ausgewählten Klassen, identified by their Kürzel – die App
  /// referenziert Klassen überall nur über das Kürzel.
  final Set<String> classIds;

  /// Die ausgewählten Personen, identified by their ID.
  final Set<String> personIds;

  /// Ob die Einstellungen mitgeteilt werden.
  final bool includeSettings;

  /// Ob auch Pläne aus der **Vergangenheit** mitgeteilt werden.
  ///
  /// Die Pläne selbst werden immer mitgenommen – sie gehören zu den geteilten
  /// Klassen, und ohne sie wäre der geteilte Plan leer. Dieser Schalter
  /// beschränkt sie nur auf die letzten [historyDays] Tage. Ausgeschaltet
  /// heißt: nur die Pläne der letzten 30 Tage. Eingeschaltet: alle gespeicherten
  /// Pläne, auch ältere.
  final bool includeHistory;

  bool get isEmpty => classIds.isEmpty && personIds.isEmpty;

  /// true, wenn mindestens etwas zum Teilen ausgewählt ist.
  bool get hasContent => classIds.isNotEmpty || personIds.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'classIds': classIds.toList(),
        'personIds': personIds.toList(),
        'includeSettings': includeSettings,
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
        includeHistory: json['includeHistory'] != false,
      );

  ShareSelection copyWith({
    Set<String>? classIds,
    Set<String>? personIds,
    bool? includeSettings,
    bool? includeHistory,
  }) =>
      ShareSelection(
        classIds: classIds ?? this.classIds,
        personIds: personIds ?? this.personIds,
        includeSettings: includeSettings ?? this.includeSettings,
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
    required this.createdAt,
    required this.updatedAt,
    this.hasPassword = false,
    this.selection = const ShareSelection(),
  });

  final String id;
  final String username;
  final String displayName;
  final String label;

  /// Ob der Share im Suchmenü auftaucht.
  ///
  /// Das Suchmenü zeigt **nur die eigene Schule**: Der Server filtert das
  /// Verzeichnis nach der Schulnummer der suchenden Person. Wer aus einer
  /// anderen Schule öffnen will, braucht den Nutzernamen – dann geht es, denn
  /// der Nutzername hängt nicht an der Schule.
  final bool searchable;

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
///
/// ### Schulen
///
/// Ein Share hängt am **Nutzernamen**, nicht an der Schule: Wer die zehn Wörter
/// kennt, öffnet ihn – auch von einer anderen Schule aus.
///
/// Im **Suchverzeichnis** stehen dagegen nur die Menschen der eigenen Schule.
/// Das ist eine Grenze des Verzeichnisses, keine des Inhalts: Mit dem
/// Nutzernamen kommt man auch an einen Share einer fremden Schule. Die
/// Schulnummer hält das Suchmenü also überschaubar und schützt nichts.
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
  /// Höchstens so viele Zeichen darf der Nutzername haben.
  ///
  /// Der Wert kommt vom Sync-Server (`MAX_USERNAME_LENGTH` in
  /// `supabase/functions/_shared/http.ts`). Eine Phrase aus zehn Wörtern wird
  /// im Mittel etwa 63 Zeichen lang und wurde deshalb **immer** wieder
  /// abgelehnt – mit der nichts aussagenden Meldung „Dieser Share ist nicht
  /// erlaubt". Die Grenze wird deshalb schon beim Erzeugen eingehalten.
  static const int maxUsernameLength = 60;

  static String generateUsername() =>
      Passphrase.generate(maxLength: maxUsernameLength);

  /// Erzeugt ein Share-Passwort – ebenfalls zehn Wörter, aber nie identisch
  /// mit der Sync-Passphrase, weil der Schlüssel aus beiden gemeinsam
  /// abgeleitet wird.
  static String generateSharePassword() => Passphrase.generate();

  /// Die ID eines Shares.
  ///
  /// Sie hängt **nur** am Nutzernamen, nicht an der Schulnummer. Wer die zehn
  /// Wörter kennt, kann den Share deshalb von jeder Schule aus öffnen – und
  /// nur so ist das überhaupt möglich: Eine ID mit der Schulnummer der
  /// Besitzerin darin kann niemand außerhalb dieser Schule berechnen, weil er
  /// sie nicht kennt.
  ///
  /// Ob ein Share **gefunden** wird, ist eine andere Frage als ob er **zu öffnen**
  /// ist: Das Suchverzeichnis filtert nach der Schulnummer der suchenden Person
  /// und listet darum nur die eigene Schule auf. Gefunden werden und geöffnet
  /// werden können sind bewusst getrennt – der Nutzername ist der Schlüssel zum
  /// Öffnen, die Schulnummer ist die Grenze des Verzeichnisses.
  static String shareIdFor(String username) => PayloadCrypto.publicId(
        Passphrase.normalize(username),
        usernameDomain,
      );

  /// Der Schlüssel einer Hülle.
  ///
  /// Der Schlüssel hängt an Nutzername, [shareScope] und dem Geheimnis der
  /// jeweiligen Hülle. Er enthält **keine Schulnummer**: Sie geht nicht in den
  /// Schlüssel ein, sonst wäre ein Share aus einer fremden Schule gar nicht
  /// zu öffnen – und gerade das soll der Nutzername ermöglichen.
  static DerivedKey _keyFor(
    String username,
    String secret,
  ) =>
      PayloadCrypto.deriveKey(
        '${Passphrase.normalize(username)}|$shareScope|$secret',
        salt: keyDomain,
      );

  /// Der Schlüsselbereich, in dem ein Share liegt.
  ///
  /// Nur noch **ein** Bereich für alle Shares: Es gibt keinen "globalen" Share
  /// mehr, der außerhalb der Besitzerschule zu öffnen wäre, und keinen
  /// schulgebundenen, der nur drinnen aufginge. Der Nutzername entscheidet, ob
  /// ein Share zu öffnen ist; die Schulnummer entscheidet nur, ob er im
  /// Suchverzeichnis auftaucht.
  static const String shareScope = 'share';

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

  /// Schreibt [share] in die eigene Liste – **an der Stelle, an der er
  /// schon stand**.
  ///
  /// Ein bearbeiteter Share wird überschrieben, nicht angehängt: Sonst stünde
  /// nach jeder Bearbeitung derselbe Share noch einmal in der Liste, und weil
  /// er ans Ende wandert, sähe es aus, als wäre ein neuer dazugekommen.
  /// `_republish` unten sorgt zusätzlich dafür, dass die ID dieselbe bleibt –
  /// beide Hälften gehören zusammen, sonst ist die Liste zwar kurz, der
  /// Inhalt aber ein zweiter Share.
  static Future<LocalShare> _replaceShare(
    SharedPreferences prefs,
    LocalShare share,
  ) async {
    final List<LocalShare> shares = readShares(prefs);
    final int index = shares.indexWhere((LocalShare s) => s.id == share.id);
    if (index < 0) {
      shares.add(share);
    } else {
      shares[index] = share;
    }
    await _writeShares(prefs, shares);
    return share;
  }

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

    final Map<String, List<Object>> source =
        await SyncDataReader.readParts(prefs, <String>[
      '${scope}classes',
      '${scope}persons',
      '${scope}offlineVPData',
      '${scope}lessontimes',
      '${scope}teacherShorts',
    ]);

    // Klassen: nur die ausgewählten. Ein Eintrag ist hier der **Name**
    // (`'8a'`), kein Objekt – so legt die App sie ab.
    final List<Object> classes = <Object>[];
    final Set<String> sharedClasses = <String>{};
    for (final Object item
        in source['${scope}classes'] ?? const <Object>[]) {
      final String short = classNameOf(item) ?? '';
      if (short.isEmpty || !selection.classIds.contains(short)) continue;
      classes.add(short);
      sharedClasses.add(short);
    }

    // Personen: nur die ausgewählten. Die zugehörige Klasse wird
    // mitgenommen, damit die Kurse der Person einordbar bleiben.
    final List<Map<String, dynamic>> persons = <Map<String, dynamic>>[];
    final Set<String> impliedClasses = <String>{...sharedClasses};
    for (final Object item
        in source['${scope}persons'] ?? const <Object>[]) {
      if (item is! Map) continue;
      final Map<String, dynamic> record = item.cast<String, dynamic>();
      final String id = record['id']?.toString() ?? '';
      if (!selection.personIds.contains(id)) continue;
      persons.add(record);
      final String classId = record['classId']?.toString() ?? '';
      if (classId.isNotEmpty) impliedClasses.add(classId);
    }
    // Klassen, die nur wegen einer Person mitkommen, stehen in `classes`.
    for (final Object item
        in source['${scope}classes'] ?? const <Object>[]) {
      final String short = classNameOf(item) ?? '';
      if (short.isEmpty || !impliedClasses.contains(short)) continue;
      if (classes.contains(short)) continue;
      classes.add(short);
    }

    // Pläne: die gespeicherten Vertretungspläne gehören zu den geteilten Klassen
    // und kommen **immer** mit. Nur ihr Alter ist eine Frage – und die
    // entscheidet [selection.includeHistory].
    final List<Map<String, dynamic>> plans = <Map<String, dynamic>>[];
    for (final Object item
        in source['${scope}offlineVPData'] ?? const <Object>[]) {
      if (item is! Map) continue;
      final Map<String, dynamic> record = item.cast<String, dynamic>();
      final String date = planDateOf(record) ?? '';
      if (!selection.includeHistory && !isRecent(date)) continue;
      plans.add(record);
    }

    final Map<String, dynamic> settings = <String, dynamic>{};
    if (selection.includeSettings) {
      // Dieselbe Regel wie beim Sync: **alle** übertragbaren Werte, nicht eine
      // Positivliste. Eine Liste kann nicht vollständig sein, und eine neue
      // Einstellung bliebe sonst auf dem Gerät, von dem geteilt wurde – der
      // Empfänger bekäme dann einen Plan ohne die Ansicht, die die Kollegin
      // sieht, und wunderte sich.
      settings.addAll(SyncDataReader.readValues(prefs));
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
  ///
  /// [existing] ist der Share, der **überschrieben** werden soll. Er behält
  /// seine ID und sein Erstellungsdatum – ein bearbeiteter Share ist derselbe
  /// Share, nicht ein neu entstandener. Ohne [existing] wird die ID aus dem
  /// Nutzernamen berechnet und ein neuer Share angelegt.
  Future<LocalShare> publish({
    required SharedPreferences prefs,
    required String schoolNumber,
    required String schoolPassword,
    required String displayName,
    required String label,
    required Map<String, dynamic> payload,
    required ShareSelection selection,
    required bool searchable,
    String? sharePassword,
    LocalShare? existing,
  }) async {
    final String username = readUsername(prefs) ?? '';
    if (username.isEmpty) throw const ShareException('noUsername');
    // Zu langer Nutzername: Der Server würde das mit derselben Meldung
    // ablehnen wie einen verbotenen Namen ("invalidShare"), und niemand
    // käme darauf, dass es an der Länge liegt. Deshalb wird es hier erkannt
    // und mit einer eigenen Meldung gemeldet.
    if (username.length > maxUsernameLength) {
      throw const ShareException('usernameTooLong');
    }

    final NameVerdict verdict = NameGuard.check(displayName);
    if (verdict.isBlocked) {
      throw ShareException('nameBlocked', detail: verdict.matchedTerm);
    }
    if (selection.isEmpty) {
      throw const ShareException('nothingSelected');
    }

    final String shareId = existing?.id ?? shareIdFor(username);
    final bool protected = sharePassword != null && sharePassword.trim().isNotEmpty;

    final Map<String, dynamic> envelopes = await compute(
      _sealShare,
      (
        username: username,
        sharePassword: sharePassword,
        schoolPassword: schoolPassword,
        payload: payload,
      ),
    );

    final DateTime now = DateTime.now().toUtc();
    await client.publishShare(
      shareId: shareId,
      username: username,
      schoolNumber: schoolNumber,
      displayName: displayName,
      label: label,
      envelopes: envelopes,
      searchable: searchable,
      updatedAt: now,
    );

    final LocalShare share = LocalShare(
      id: shareId,
      username: username,
      displayName: displayName,
      label: label,
      searchable: searchable,
      // Das Erstellungsdatum gehört zu **einem** Share. Ein bearbeiteter
      // Share ist nicht neu entstanden, deshalb bleibt sein altes Datum
      // stehen – vorher bekam jeder Bearbeitung ein neues, und die Liste sah
      // danach aus, als wäre ein zweiter Share dazugekommen.
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      hasPassword: protected,
      selection: selection,
    );

    await _replaceShare(prefs, share);
    if (protected) {
      await prefs.setString(sharePasswordStorageKey, sharePassword);
    } else {
      // Das Passwort ist abgeschaltet: Was einmal gespeichert war, darf nicht
      // liegen bleiben und beim nächsten Bearbeiten ungefragt wieder verwendet
      // werden.
      await prefs.remove(sharePasswordStorageKey);
    }
    return share;
  }

  /// Ändert die Eigenschaften eines bestehenden Shares und lädt ihn neu hoch.
  ///
  /// Der **Inhalt** wird dabei neu aus der gespeicherten Auswahl gebaut – der
  /// Nutzer muss also nicht erneut auswählen, bekommt aber trotzdem frische
  /// Daten, wenn inzwischen etwas dazugekommen ist.
  ///
  /// Das ist ein **Überschreiben**, kein Neuanlegen: Es bleibt dieselbe ID,
  /// dieselbe Zeile in der Liste und dasselbe Erstellungsdatum. Genau das war
  /// vorher anders – [publish] legte einen neuen Share an, während die alte
  /// Zeile stehen blieb.
  Future<LocalShare> update({
    required SharedPreferences prefs,
    required String schoolNumber,
    required String schoolPassword,
    required LocalShare share,
    String? label,
    bool? searchable,
    String? displayName,
    ShareSelection? selection,
    String? sharePassword,
  }) async {
    final ShareSelection effective = selection ?? share.selection;
    final Map<String, dynamic> payload =
        await buildPayload(prefs, effective);

    final LocalShare updated = share.copyWith(
      label: label,
      searchable: searchable,
      displayName: displayName,
      selection: effective,
      updatedAt: DateTime.now().toUtc(),
    );

    return publish(
      prefs: prefs,
      schoolNumber: schoolNumber,
      schoolPassword: schoolPassword,
      displayName: updated.displayName,
      label: updated.label,
      payload: payload,
      selection: effective,
      searchable: updated.searchable,
      // Das Passwort kommt aus dem Formular, wenn der Bearbeitungsbildschirm
      // eines schickt. `null` bedeutet: ungesichert. Ohne das konnte ein
      // Bearbeiten das Passwort weder setzen noch abschalten – es wurde still
      // das alte verwendet oder eines eingegebenes verworfen.
      sharePassword: sharePassword ?? (share.hasPassword ? readSharePassword(prefs) : null),
      existing: share,
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
  /// Es wird nacheinander jede Hülle durchprobiert, die der Share anbietet: das
  /// Share-Passwort, falls eines angegeben wurde, den Nutzernamen und das
  /// Schulpasswort. Der erste passende Schlüssel gewinnt.
  ///
  /// Eine Schulnummer wird **nicht** gebraucht: Der Schlüssel hängt am
  /// Nutzernamen, und der ist der Grund, warum ein Share aus einer anderen
  /// Schule überhaupt geöffnet werden kann. Wer die Schulnummer kennt, aber den
  /// Nutzamen nicht, kommt nicht an den Share – die zehn Wörter sind der
  /// einzige Weg hinein.
  static Map<String, dynamic> unlock(
    ShareRecord record,
    String username, {
    String? sharePassword,
    String? schoolPassword,
  }) {
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
          _keyFor(username, candidate.secret),
          envelope,
        );
      } on PayloadCryptoException {
        // Falscher Schlüssel für diese Hülle – die nächste versuchen.
        continue;
      }
    }
    throw const ShareException('wrongCredentials');
  }

  /// Öffnet einen Share – wie [unlock], aber ohne den Bildschirm anzuhalten.
  ///
  /// [unlock] braucht für jede angebotene Hülle eine PBKDF2-Ableitung mit
  /// 120 000 Runden. Auf dem UI-Thread gerechnet steht die Oberfläche für den
  /// ganzen Vorgang still: Die Ladeanzeige bleibt stehen, statt sich zu
  /// bewegen, und man sieht nicht, worauf man wartet. Hier läuft die Rechnung
  /// in einem eigenen Isolate, die Anzeige läuft weiter.
  static Future<Map<String, dynamic>> unlockAsync(
    ShareRecord record,
    String username, {
    String? sharePassword,
    String? schoolPassword,
  }) =>
      compute(
        _openShare,
        (
          record: record,
          username: username,
          sharePassword: sharePassword,
          schoolPassword: schoolPassword,
        ),
      );

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

  /// Die Klassen und Personen eines geöffneten Shares als Auswahlliste.
  ///
  /// Im Share ist eine Klasse schlicht ihr Kürzel und eine Person ein Objekt mit
  /// `id` und `name` – beides wird hier so zurückgegeben, wie es in der
  /// Oberfläche angezeigt und angeklickt wird. Die IDs sind die des Shares, nicht
  /// die später vergebenen `import-…`-IDs: Die Auswahl bezieht sich auf das, was
  /// man sieht.
  static ({
    List<String> classes,
    List<({String id, String name})> persons,
  }) selectableItems(Map<String, dynamic> payload) {
    final SyncPayload data = _readPayload(payload);
    final List<String> classes = <String>[];
    final List<({String id, String name})> persons =
        <({String id, String name})>[];

    for (final SyncPart part in data.parts) {
      if (part.key.endsWith('classes')) {
        for (final Object item in part.items) {
          final String? short = classNameOf(item);
          if (short == null || classes.contains(short)) continue;
          classes.add(short);
        }
      } else if (part.key.endsWith('persons')) {
        for (final Object item in part.items) {
          if (item is! Map) continue;
          final String name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          // Ohne `id` gibt es nichts anzuklicken – dann wäre der Eintrag eine
          // Zeile, deren Auswahl man nicht wieder loswird.
          final String id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          if (persons.any((({String id, String name}) p) => p.id == id)) continue;
          persons.add((id: id, name: name));
        }
      }
    }
    return (classes: classes, persons: persons);
  }

  /// Die Vorauswahl: **alles** auswählen.
  ///
  /// Wer einen Share öffnet, will ihn erst einmal sehen. Alles ausgewählt zu
  /// lassen ist deshalb der ehrliche Start – wer weniger braucht, klickt es ab.
  static ShareImportSelection selectAll(Map<String, dynamic> payload) {
    final ({
      List<String> classes,
      List<({String id, String name})> persons,
    }) items = selectableItems(payload);
    return ShareImportSelection(
      classIds: items.classes.toSet(),
      personIds: items.persons.map((({String id, String name}) p) => p.id).toSet(),
    );
  }

  /// Die Pläne, die ein Import für [selection] übernehmen würde.
  ///
  /// Für die Anzeige im Share: im Modus [ShareImportMode.original] sind das
  /// die Pläne des Shares, in den beiden Umbaumodierten wird kein Plan erzeugt.
  static int countPlansOf(
    Map<String, dynamic> payload,
    ShareImportSelection selection, {
    ShareImportMode mode = ShareImportMode.original,
  }) {
    if (!selection.includePlans || mode != ShareImportMode.original) return 0;
    return countContents(payload).plans;
  }

  /// Schreibt einen geöffneten Share in die lokalen Daten.
  ///
  /// Der Import ist **nicht destruktiv**: Vorhandene Klassen und Personen
  /// bleiben, die importierten kommen hinzu. Nur die Kürzel werden
  /// entkollidiert, damit eine importierte Klasse `7c` nicht die lokale
  /// Klasse `7c` überschreibt.
  ///
  /// [selection] bestimmt, **was** übernommen wird: einzelne Klassen, einzelne
  /// Personen und – über [ShareImportSelection.includePlans] – die
  /// zwischengespeicherten Pläne. Ohne [selection] wird alles übernommen.
  static Future<ShareImportResult> applyImport(
    SharedPreferences prefs,
    Map<String, dynamic> payload, {
    required ShareImportMode mode,
    required String displayName,
    ShareImportSelection? selection,
  }) async {
    final SyncPayload data = _readPayload(payload);
    final String scope = scopeSuffix(prefs);

    // Eine leere Auswahl ist kein Fehlklick, sondern eine Absicht – aber sie
    // darf auch nicht stillschweigend "alles" bedeuten. Sonst würde ein
    // abgeschalteter Plan-Schalter mit leeren Haken importieren.
    if (selection?.hasNothing ?? false) {
      throw const ShareException('nothingSelected');
    }

    // Die Kürzel, die es lokal schon gibt.
    final Set<String> usedShorts = (prefs.getStringList('${scope}classes') ??
            const <String>[])
        .map(classNameOfRaw)
        .whereType<String>()
        .toSet();

    final List<Map<String, dynamic>> newPersons = <Map<String, dynamic>>[];
    // Die App legt Klassen als **einfache Zeichenketten** ab
    // (`setStringList(key, ['8a'])`). Hier werden keine Objekte gebaut – das
    // ist seit der Umstellung auf [SyncPart.items] ohnehin nicht mehr möglich,
    // und ein Objekt mit `name`/`displayName` kennt die Klassenauswahl nicht.
    final List<String> newClasses = <String>[];
    final Map<String, String> classLabels = <String, String>{};
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
    List<String> coursesOf(Object person) {
      if (person is! Map) return const <String>[];
      return stringList(person['courses']);
    }

    Map<String, dynamic>? record(Object item) =>
        item is Map ? item.cast<String, dynamic>() : null;

    String field(Object item, String name) {
      final Map<String, dynamic>? r = record(item);
      return r?[name]?.toString() ?? '';
    }

    // Nur die **ausgewählten** Klassen, Personen und Pläne werden übernommen.
    // Ohne [selection] gilt „alles" – das hält die Aufrufer, die es vorher gab
    // und keine Auswahl kannten, auf demselben Stand.
    final Set<String> chosenClasses = selection?.classIds ?? const <String>{};
    final Set<String> chosenPersons = selection?.personIds ?? const <String>{};
    final bool takePlans = selection?.includePlans ?? true;
    final bool filterActive = selection != null;

    bool classWanted(String short) =>
        !filterActive || chosenClasses.contains(short);

    bool personWanted(Object item) {
      if (!filterActive) return true;
      final String id = field(item, 'id');
      return id.isNotEmpty && chosenPersons.contains(id);
    }

    switch (mode) {
      case ShareImportMode.original:
        // 1:1 übernehmen. Die fremden Klassennummern bleiben erhalten – das ist
        // der Sinn von "Original" – und die Personen behalten ihre Kurse.
        final Map<String, String> classMapping = <String, String>{};
        for (final SyncPart part in data.parts) {
          if (!part.key.endsWith('classes')) continue;
          for (final Object item in part.items) {
            final String short = classNameOf(item) ?? '';
            if (short.isEmpty || !classWanted(short)) continue;
            final String unique = nextShort(short);
            classMapping[short] = unique;
            // Die App legt Klassen als einfache Zeichenkette ab – ein Objekt
            // mit `name` und `displayName` kennt sie gar nicht.
            newClasses.add(unique);
          }
        }
        // Die Pläne kommen nur mit, wenn sie angefordert sind. Unverändert
        // übernehmen: In „Original" bleibt alles, wie es geteilt wurde.
        if (takePlans) {
          for (final SyncPart part in data.parts) {
            if (part.key.endsWith('offlineVPData')) {
              for (final Object item in part.items) {
                newPlans.add(SyncPayload.encodeItem(item));
              }
            }
          }
        }
        for (final SyncPart part in data.parts) {
          if (!part.key.endsWith('persons')) continue;
          for (final Object item in part.items) {
            final String name = field(item, 'name').trim();
            if (name.isEmpty || !personWanted(item)) continue;
            final String originalClass = field(item, 'classId');
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
        // **Alle** übernommenen Klassen und Personen werden zu Klassen: die
        // fremde Klasse `7c` bleibt `7c`, aus der Person `Hans` mit den Kursen
        // Deutsch und Mathe wird die Klasse `Hans`.
        //
        // Dabei werden **keine Pläne und keine zusätzlichen Klassen erzeugt**.
        // Vorher entstand je Kurs ein Plan „Hans – Deutsch", „Hans – Mathe" …
        // – eine Unmenge Zeilen in der Planliste, die nichts zeigten, was die
        // Kurse der Klasse nicht schon zeigen. Die Kurse hängen an der Klasse,
        // die aus der Person wurde; das genügt.
        final Set<String> seenClasses = <String>{};

        void addAsClass(String base) {
          final String name = base.trim();
          if (name.isEmpty || !seenClasses.add(name)) return;
          final String short = nextShort(name);
          newClasses.add(short);
          // Ein gekürztes Kürzel, das aus einem längeren Namen entstand, bekommt
          // den vollen Namen als Anzeigename – sonst steht in der Klassenliste
          // nur „Hans Sch…" und niemand weiß mehr, wer das war.
          if (name != short) classLabels[short] = name;
        }

        for (final SyncPart part in data.parts) {
          if (part.key.endsWith('classes')) {
            // Eine Klasse ist bei der App schlicht ein Name – es gibt kein
            // `displayName` an diesem Eintrag, das Kürzel **ist** der Name.
            for (final Object item in part.items) {
              final String short = classNameOf(item) ?? '';
              if (!classWanted(short)) continue;
              addAsClass(short);
            }
          } else if (part.key.endsWith('persons')) {
            for (final Object item in part.items) {
              if (!personWanted(item)) continue;
              addAsClass(field(item, 'name'));
            }
          }
        }

      case ShareImportMode.persons:
        // Aus jeder übernommenen Klasse und jeder übernommenen Person wird ein
        // Name – und zu jedem gehört eine eigene Klasse.
        //
        // Aus den gespeicherten Plänen werden **keine** Namen gezogen. Der Name
        // eines Plans („Vertretungsplan für Hans Schneider", „Plan von 2025")
        // ist keine Person; als Person in der App zu stehen half niemandem und
        // füllte nur die Liste.
        final Set<String> seen = <String>{};
        void addAsPerson(String rawName, List<String> courses) {
          final String name = rawName.trim();
          if (name.isEmpty || !seen.add(name)) return;
          final String short = nextShort(name);
          newClasses.add(short);
          classLabels[short] = name;
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
            for (final Object item in part.items) {
              if (!personWanted(item)) continue;
              addAsPerson(field(item, 'name'), coursesOf(item));
            }
          } else if (part.key.endsWith('classes')) {
            // Eine Klasse ist bei der App schlicht ein Name – es gibt kein
            // `displayName` an diesem Eintrag.
            for (final Object item in part.items) {
              final String short = classNameOf(item) ?? '';
              if (!classWanted(short)) continue;
              addAsPerson(short, const <String>[]);
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
      for (final String name in newClasses) {
        if (!merged.contains(name)) merged.add(name);
      }
      await prefs.setStringList('${scope}classes', merged);

      // `classNames` ist eine **Karte** `{classId: eigenerName}`
      // (`VPlanAPI._decodeClassNames`) – keine Liste, kein Objekt je Klasse.
      final Map<String, dynamic> names =
          (prefs.getString('${scope}classNames') != null)
              ? Map<String, dynamic>.of(
                  (jsonDecode(prefs.getString('${scope}classNames')!) as Map)
                      .cast<String, dynamic>(),
                )
              : <String, dynamic>{};
      for (final String short in newClasses) {
        final String label = classLabels[short] ?? short;
        if (label.isNotEmpty && label != short) names[short] = label;
      }
      if (names.isNotEmpty) {
        await prefs.setString('${scope}classNames', jsonEncode(names));
      }
    }
    if (newPersons.isNotEmpty) {
      // Über den Sync-Leser, nicht über `getStringList`: `persons` wird von
      // `VPlanAPI` als JSON-Zeichenkette gespeichert, weil es Objekte
      // enthält. Ein `getStringList` darauf wirft einen TypeError – und der
      // Import bricht genau dann ab, wenn er eigentlich Personen übertragen
      // sollte, also genau dann, wenn er gebraucht wird.
      final List<String> merged = <String>[
        ...SyncDataReader.readLines(prefs, '${scope}persons'),
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
  /// Der Klassenname eines Eintrags – beide Formen annehmend.
  ///
  /// Die App speichert Klassen als **einfache Zeichenketten**
  /// (`setStringList(key, ['8a'])`), nicht als Objekte. Ein alter Share oder ein
  /// Bestand aus einer früheren App-Version kann beides enthalten, deshalb wird
  /// hier nicht auf eine Form bestanden.
  static String? classNameOf(Object item) {
    if (item is String) return item.isEmpty ? null : item;
    if (item is! Map) return null;
    final String name = item['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    final String? plain = item['value']?.toString();
    return (plain == null || plain.isEmpty) ? null : plain;
  }

  /// Dasselbe für den rohen JSON-String aus `SharedPreferences`.
  static String? classNameOfRaw(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is String) return decoded.isEmpty ? null : decoded;
      if (decoded is Map) return classNameOf(decoded);
    } catch (_) {
      // Kein JSON – dann ist es ein gewöhnlicher Klassenname wie `8a`.
      return raw.isEmpty ? null : raw;
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

/// Verschlüsselt einen Share-Inhalt – läuft in einem **eigenen Isolate**.
///
/// PBKDF2 mit 120 000 Runden ist in reinem Dart teuer: Jede Hülle braucht
/// eine eigene Ableitung, ein Share ohne Passwort also zwei. Auf dem
/// UI-Thread blockiert das die Oberfläche für gut eine Sekunde – und weil
/// dann kein einziger Frame gezeichnet wird, wirkt eine Ladeanzeige wie
/// eingefroren, statt sich zu bewegen. Deshalb wird hier gearbeitet, ohne
/// dass der Bildschirm stillsteht.
///
/// Aufgerufen über [compute]; deshalb eine Top-Level-Funktion und keine
/// Methode: `compute` braucht etwas, das in einen anderen Isolate geschickt
/// werden kann.
Map<String, dynamic> _sealShare(
  ({
    String username,
    String? sharePassword,
    String schoolPassword,
    Map<String, dynamic> payload,
  }) request,
) {
  final Map<String, dynamic> envelopes = <String, dynamic>{};
  final String? sharePassword = request.sharePassword;
  if (sharePassword != null && sharePassword.trim().isNotEmpty) {
    envelopes[ShareSlot.byPassword.id] = PayloadCrypto.encryptJson(
      ShareManager._keyFor(
        request.username,
        Passphrase.normalize(sharePassword),
      ),
      request.payload,
      salt: ShareManager.keyDomain,
    );
  } else {
    envelopes[ShareSlot.byUsername.id] = PayloadCrypto.encryptJson(
      ShareManager._keyFor(request.username, ''),
      request.payload,
      salt: ShareManager.keyDomain,
    );
    envelopes[ShareSlot.bySchool.id] = PayloadCrypto.encryptJson(
      ShareManager._keyFor(request.username, request.schoolPassword),
      request.payload,
      salt: ShareManager.keyDomain,
    );
  }
  return envelopes;
}

/// Entschlüsselt einen Share – ebenfalls in einem eigenen Isolate, aus
/// demselben Grund wie [_sealShare]. Wird von [ShareManager.unlockAsync]
/// aufgerufen.
Map<String, dynamic> _openShare(
  ({
    ShareRecord record,
    String username,
    String? sharePassword,
    String? schoolPassword,
  }) request,
) =>
    ShareManager.unlock(
      request.record,
      request.username,
      sharePassword: request.sharePassword,
      schoolPassword: request.schoolPassword,
    );

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
