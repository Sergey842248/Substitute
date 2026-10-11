/// Hilfsfunktionen rund um die Kalenderwoche des Vertretungsplans.
///
/// **Wichtig für alle Datumsrechnungen hier:** Es wird ausschließlich mit dem
/// [DateTime]-Konstruktor gerechnet (`DateTime(jahr, monat, tag + n)`), niemals
/// mit `add(Duration(days: n))`.
///
/// Grund: `Duration(days: n)` addiert absolute Stunden. Führt der Weg über eine
/// Zeitumstellung – in Deutschland z.B. in der Nacht zum letzten Sonntag im
/// Oktober, wo die Uhr eine Stunde zurückgeht – kommt man nicht bei demselben
/// Uhrzeit des n-ten Tages an, sondern eine Stunde früher. Aus einem Montag
/// (19.10.2026, 00:00) wurde so der Sonntag 25.10.2026 um 23:00 – und aus dem
/// Sonntag rechnet [startOfSchoolWeek] wieder den Montag derselben Woche, also
/// den **19.10.** zurück. Die Wochen-Navigation blieb damit stecken.
library;

/// Der Montag der Woche, in der [date] liegt.
///
/// Der Vertretungsplan beginnt immer am Montag. Samstag und Sonntag gehören
/// nicht zur Schulwoche – an den allermeisten Schulen findet am Wochenende kein
/// Unterricht statt.
DateTime startOfSchoolWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// Der Freitag der Woche, in der [date] liegt (siehe [startOfSchoolWeek]).
DateTime endOfSchoolWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1) + 4);

/// Addiert [days] **Kalendertage** – ohne die Zeitverschiebung, die
/// `Duration(days: n)` über eine Zeitumstellung hinweg auslöst (siehe oben).
///
/// Das Ergebnis ist auf 00:00 Uhr normalisiert, weil für den Vertretungsplan
/// ausschließlich der Kalendertag zählt.
DateTime addSchoolDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Wandelt den von der API gelieferten Wochenwert (Kopf/Woche, z.B. "A",
/// "B", "A-Woche", "B-Woche" oder eine Kalenderwochen-Zahl) in eine
/// kompakte Anzeige um.
///
/// Die Woche darf NIEMALS lokal aus dem Datum berechnet werden, sondern muss
/// zwingend aus dem Plan des Servers kommen – nur der Server weiß, ob in
/// dieser Woche A- oder B-Unterricht ist.
String planWeekLabel(dynamic week) {
  final String w = (week?.toString() ?? '').trim();
  if (w.isEmpty) return '---';
  final String upper = w.toUpperCase();
  if (upper.startsWith('B') || upper == '2') return 'B';
  if (upper.startsWith('A') || upper == '1') return 'A';
  return w;
}