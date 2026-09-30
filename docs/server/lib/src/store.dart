import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Dauerhafter Speicher für den Sync- und Share-Server.
///
/// Bewusst dateibasiert und abhängigkeitsfrei: Der Server ist ein einzelner
/// Prozess auf einem kleinen Ubuntu-Server, es gibt keinen zweiten Knoten und
/// keine Verfügbarkeitsanforderung über Sekunden hinaus. Ein JSON-Datei je
/// Bereich mit atomarem Schreiben (Schreiben in eine temporäre Datei, dann
/// `rename`) reicht dafür vollkommen aus und lässt sich im Notfall mit `cat`
/// und `jq` inspizieren.
///
/// **Der Server ist blind:** Er speichert die verschlüsselten Hüllen der App
/// unverändert. Namen und Schulnummern stehen im Klartext in den Metadaten,
/// weil das Suchverzeichnis sie sonst nicht liefern könnte – die eigentlichen
/// Pläne, Personen und Einstellungen sind aber für niemanden lesbar, auch
/// nicht für den Betreiber des Servers.
class Store {
  Store(this.root) {
    _chains = _Section(root, 'chains');
    _shares = _Section(root, 'shares');
  }

  /// Das Datenverzeichnis. Heißt bewusst nicht `directory`, weil es bereits
  /// eine Methode [directory] für das Suchverzeichnis gibt.
  final Directory root;

  late final _Section _chains;
  late final _Section _shares;

  /// Öffnet (und legt bei Bedarf an) das Datenverzeichnis.
  Future<void> open() async {
    await _chains.open();
    await _shares.open();
  }

  // ------------------------------------------------------------ Sync-Ketten

  /// Alle Snapshots einer Sync-Kette, älteste zuerst.
  List<Map<String, dynamic>> chain(String chainId) {
    final List<Map<String, dynamic>> snapshots = _read(_chains, chainId);
    snapshots.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['updatedAt'] as String).compareTo(b['updatedAt'] as String));
    return snapshots;
  }

  /// Legt den Snapshot eines Geräts an oder ersetzt ihn. Pro Gerät existiert
  /// immer nur ein Snapshot – sonst würde die Kette unbegrenzt wachsen.
  Future<void> putChainSnapshot(
    String chainId,
    Map<String, dynamic> snapshot,
  ) async {
    final List<Map<String, dynamic>> snapshots = _read(_chains, chainId);
    final String deviceId = snapshot['deviceId']?.toString() ?? '';
    snapshots.removeWhere(
        (Map<String, dynamic> s) => s['deviceId']?.toString() == deviceId);
    snapshots.add(snapshot);
    await _write(_chains, chainId, snapshots);
  }

  /// Nimmt ein einzelnes Gerät aus der Kette, ohne dass die Daten auf dem
  /// Gerät selbst verloren gehen: Der Server löscht nur den Snapshot.
  Future<bool> deleteChainSnapshot(String chainId, String deviceId) async {
    final List<Map<String, dynamic>> snapshots = _read(_chains, chainId);
    final int before = snapshots.length;
    snapshots.removeWhere(
        (Map<String, dynamic> s) => s['deviceId']?.toString() == deviceId);
    if (snapshots.length == before) return false;
    await _write(_chains, chainId, snapshots);
    return true;
  }

  /// Löscht eine Sync-Kette samt aller Snapshots.
  Future<bool> deleteChain(String chainId) async =>
      _delete(_chains, chainId);

  // ----------------------------------------------------------------- Shares

  /// Ein Share anhand seiner ID. `null`, wenn es nicht (mehr) existiert.
  Map<String, dynamic>? share(String shareId) {
    final List<Map<String, dynamic>> all = _read(_shares, shareId);
    if (all.isEmpty) return null;
    return all.first;
  }

  /// Legt einen Share an oder ersetzt ihn.
  Future<void> putShare(Map<String, dynamic> share) async {
    await _write(_shares, share['id']?.toString() ?? '',
        <Map<String, dynamic>>[share]);
  }

  Future<bool> deleteShare(String shareId) async => _delete(_shares, shareId);

  /// Alle Shares, die in das Suchverzeichnis einer Schulnummer gehören.
  ///
  /// Das Verzeichnis enthält **ausschließlich** Shares derselben
  /// Schulnummer. Ein "globaler" Share bleibt auffindbar, wird aber nicht in
  /// das Verzeichnis fremder Schulen aufgenommen – global heißt, dass ihn
  /// jeder per Nutzername verwenden kann, nicht dass er überall
  /// hineinprominent wird.
  List<Map<String, dynamic>> directory(String schoolNumber) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final File file in _shares.files) {
      for (final Map<String, dynamic> share in _readFile(file)) {
        final Object? owner = share['owner'];
        if (owner is! Map) continue;
        if (owner['schoolNumber']?.toString() != schoolNumber) continue;
        if (share['searchable'] != true) continue;
        result.add(share);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------- Internes

  /// Lädt einen Bereich neu von der Platte. Für Tests und für einen externen
  /// Eingriff nützlich.
  Future<void> reload() async {
    await _chains.open();
    await _shares.open();
  }

  static List<Map<String, dynamic>> _read(_Section section, String id) {
    final File? file = section.files
        .where((File f) => f.path.endsWith('/${_safe(id)}.json'))
        .firstOrNull;
    if (file == null || !file.existsSync()) return <Map<String, dynamic>>[];
    return _readFile(file);
  }

  static List<Map<String, dynamic>> _readFile(File file) {
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      // Eine beschädigte Datei darf den ganzen Server nicht lahmlegen: Der
      // Bereich gilt dann als leer und wird beim nächsten Schreiben ersetzt.
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _write(
    _Section section,
    String id,
    List<Map<String, dynamic>> records,
  ) async {
    if (id.isEmpty) return;
    final File target = File('${section.directory.path}/${_safe(id)}.json');
    final File temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(records), flush: true);
    await temporary.rename(target.path);
  }

  static Future<bool> _delete(_Section section, String id) async {
    final File file = File('${section.directory.path}/${_safe(id)}.json');
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  /// Ein Bezeichner, der als Dateiname taugt. Die IDs der App sind bereits
  /// base64url-kodierte Digests, aber eine ID darf niemals aus dem Dateisystem
  /// ausbrechen (`../`).
  static String _safe(String id) {
    final String cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (cleaned.isEmpty) return 'invalid';
    return cleaned.length <= 120 ? cleaned : cleaned.substring(0, 120);
  }
}

/// Alle Dateien eines Bereichs.
class _Section {
  _Section(this.root, this.name);

  final Directory root;
  final String name;

  late final Directory directory;

  List<File> get files => directory
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList();

  Future<void> open() async {
    directory = Directory('${root.path}/$name');
    await directory.create(recursive: true);
  }
}
