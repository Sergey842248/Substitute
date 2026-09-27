import 'package:substitute/l10n/app_localizations.dart';

/// Kürzel des Wochentags in der jeweiligen Sprache – z.B. "So" (Deutsch)
/// bzw. "Sun" (Englisch).
///
/// Bewusst über eigene Übersetzungen und nicht über [DateFormat]/intl: In der
/// App wird `initializeDateFormatting` nicht aufgerufen, localized
/// `DateFormat`-Muster wären daher nicht verlässlich verfügbar.
String weekdayShort(AppLocalizations l10n, DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return l10n.weekdayShortMon;
    case DateTime.tuesday:
      return l10n.weekdayShortTue;
    case DateTime.wednesday:
      return l10n.weekdayShortWed;
    case DateTime.thursday:
      return l10n.weekdayShortThu;
    case DateTime.friday:
      return l10n.weekdayShortFri;
    case DateTime.saturday:
      return l10n.weekdayShortSat;
    case DateTime.sunday:
    default:
      return l10n.weekdayShortSun;
  }
}

/// Datum mit Wochentagskürzel, z.B. "So, 27.09.2026".
String dateWithWeekday(AppLocalizations l10n, DateTime date, String formatted) =>
    '${weekdayShort(l10n, date)}, $formatted';
