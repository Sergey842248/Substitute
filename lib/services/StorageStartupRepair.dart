import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/ListOrderRepair.dart';
import 'package:substitute/services/sync/SyncKeys.dart';

/// Das Ergebnis eines Durchgangs, für eine Meldung im Log.
///
/// Ein stiller Reparaturvorgang ist schwer zu finden: Wenn eine Liste plötzlich
/// sortiert ist, sollte irgendwo stehen, dass das beim Start passiert ist –
/// und nicht, dass es niemand gemacht hat.
class StartupRepairReport {
  const StartupRepairReport({
    required this.formsFixed,
    required this.listsReordered,
  });

  /// Speicherwerte, die in die erwartete Form gebracht wurden.
  final int formsFixed;

  /// Listen, die in die richtige Reihenfolge gebracht wurden.
  final int listsReordered;

  /// true, wenn nichts zu tun war.
  bool get isEmpty => formsFixed == 0 && listsReordered == 0;

  @override
  String toString() => isEmpty
      ? 'nichts zu reparieren'
      : '$formsFixed Speicherwerte, $listsReordered Listen';
}

/// Was beim Start der App in Ordnung gebracht wird – und was dabei herauskam.
///
/// Zwei Durchgänge, aus zwei verschiedenen Anlässen:
///
/// 1. **Form** – ein Sync, der einen Bestandteil in der falschen Form
///    zurückgeschrieben hat, macht die App *dauerhaft* unstartbar. `VPlanAPI`
///    liest dieselben Schlüssel mit typisierten Gettern, und die werfen bei
///    falschem Typ einen `TypeError`, statt `null` zu liefern. Genau das ist
///    geschehen: `persons` stand als `StringList` da, `getString` warf, `runApp`
///    wurde nie erreicht.
///
/// 2. **Ordnung** – Klassenlisten folgen seit dem Update der menschlichen
///    Lesart (`06.2` vor `11`), Pläne dem Datum. Die Listen, die **vorher**
///    geschrieben wurden, sind davon nicht berührt.
///
/// ## Warum in einer eigenen Funktion und nicht in `main()`
///
/// `main()` ist in einem Widget-Test nicht aufrufbar – es macht `runApp` und
/// beendet damit den Test. Steht der Ablauf hier, lässt er sich prüfen, und
/// `main()` bekommt genau einen Aufruf. Das ist der Grund, nicht die
/// Sauberkeit.
///
/// ## Warum bei jedem Start und nicht einmalig
///
/// Beide Durchgänge prüfen vor dem Schreiben und tun bei bereits richtigen
/// Werten nichts. Ein einmaliges Merkmal wäre nur eine zusätzliche Stelle, an
/// der etwas falsch sein kann – und es würde die App daran hindern, sich selbst
/// zu heilen, wenn ein Fehler eingebaut wird, der wieder etwas verschiebt.
class StorageStartupRepair {
  const StorageStartupRepair._();

  /// Bringt Form und Ordnung in Ordnung. Beide Durchgänge sind idempotent.
  static Future<StartupRepairReport> run(SharedPreferences prefs) async =>
      StartupRepairReport(
        formsFixed: await StorageHealer.healAll(prefs),
        listsReordered: await ListOrderRepair.repairAll(prefs),
      );
}
