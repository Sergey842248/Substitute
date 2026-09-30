/// Größen- und Mengenbegrenzungen des Servers.
///
/// Der Server nimmt ausschließlich verschlüsselte Blobs entgegen. Ein Blödsinn
/// oder ein Angreifer darf aber keinen unendlichen Speicher auffüllen können,
/// deshalb sind Obergrenzen Pflicht – und zwar groß genug, damit ein
/// Schuljahr an gespeicherten Plänen bequem hineinpasst.
class Limits {
  const Limits._();

  /// Größter JSON-Body, den der Server annimmt (16 MiB). Ein Share mehrerer
  /// Personen und Wochen Pläne bleibt darunter.
  static const int maxBodyBytes = 16 * 1024 * 1024;

  /// Höchstzahl an Geräten in einer Sync-Kette. Mehr Geräte sind in einem
  /// Schulbetrieb nicht zu erwarten; die Grenze schützt zugleich davor, dass
  /// jemand eine Kette als beliebigen Speicher missbraucht.
  static const int maxDevicesPerChain = 12;

  /// Höchstzahl an Shares pro Nutzername.
  static const int maxSharesPerUser = 50;

  /// Höchstzahl an Shares in einem Schulverzeichnis-Antwort.
  static const int maxDirectoryEntries = 500;

  /// Obergrenzen für Textfelder, die der Server im Klartext speichert.
  static const int maxUsernameLength = 60;
  static const int maxDisplayNameLength = 40;
  static const int maxLabelLength = 60;
  static const int maxDeviceNameLength = 60;

  /// Nach dieser Zeit ohne Änderung räumt der Server verwaiste Shares auf.
  /// Der Nutzer kann seinen Share jederzeit neu veröffentlichen.
  static const Duration shareIdleTimeout = Duration(days: 180);

  /// Anfragen pro Minute und IP-Adresse, je nach Endpunkt.
  static const int readRequestsPerMinute = 120;
  static const int writeRequestsPerMinute = 30;
}

/// Einfache Token-Schubfach-Drosselung pro IP-Adresse.
///
/// Bewusst im Speicher und nicht in einer Datei: Der Server ist ein einzelner
/// Prozess, ein Neustart setzt die Zähler zurück, und das ist genau richtig –
/// nach einem Neustart soll niemand sofort wieder gesperrt werden.
class RateLimiter {
  RateLimiter({
    this.window = const Duration(minutes: 1),
    this.maxEntries = 10000,
  });

  final Duration window;
  final int maxEntries;
  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  /// true, wenn die Anfrage durchgelassen wird. [writes] wählt das strengere
  /// Limit für schreibende Endpunkte.
  bool allow(String identity, {required bool writes}) {
    final int limit = writes ? Limits.writeRequestsPerMinute : Limits.readRequestsPerMinute;
    final DateTime now = DateTime.now();
    _evict(now);
    final _Bucket bucket = _buckets.putIfAbsent(
        identity, () => _Bucket(windowEnd: now.add(window)));
    return bucket.take(now, limit, window);
  }

  /// Entfernt abgelaufene Schubfächer, damit die Map nicht unbegrenzt wächst
  /// (sonst wäre jeder Besuch einer fremden IP ein dauerhafter Eintrag).
  void _evict(DateTime now) {
    if (_buckets.length < maxEntries) return;
    _buckets.removeWhere((String _, _Bucket bucket) => bucket.windowEnd.isBefore(now));
  }
}

class _Bucket {
  _Bucket({required this.windowEnd});

  DateTime windowEnd;
  int used = 0;

  bool take(DateTime now, int limit, Duration window) {
    if (windowEnd.isBefore(now)) {
      windowEnd = now.add(window);
      used = 0;
    }
    if (used >= limit) return false;
    used++;
    return true;
  }
}
