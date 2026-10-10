/// Hilfsfunktionen rund um die Kalenderwoche des Vertretungsplans.

/// Der Montag der Woche, in der [date] liegt.
///
/// Der Vertretungsplan beginnt immer am Montag – der Samstag wird
/// mitgezählt, weil an manchen Schulen (Gesamtschulen) auch samstags
/// Unterricht stattfindet. Der Sonntag gehört nicht zur Schulwoche.
DateTime startOfSchoolWeek(DateTime date) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  // `weekday` zählt ab 1 (Montag). Sonntag (7) muss auf 7 gerechnet
  // werden, damit daraus ebenfalls der Montag davor wird.
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Der Samstag der Woche, in der [date] liegt (siehe
/// [startOfSchoolWeek]).
DateTime endOfSchoolWeek(DateTime date) =>
    startOfSchoolWeek(date).add(const Duration(days: 5));

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