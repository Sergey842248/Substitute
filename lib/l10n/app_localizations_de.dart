// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settings => 'Einstellungen';

  @override
  String get credentials => 'Anmeldeinformationen';

  @override
  String get credentialsSubtitle => 'stundenplan24 Anmeldeinformationen';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsSubtitle =>
      'Benachrichtigungen für den Vertretungsplan';

  @override
  String get setTeacherAbbreviations => 'Lehrerkürzel festlegen';

  @override
  String get setTeacherAbbreviationsSubtitle =>
      'Lehrerkürzel durch echte Namen ersetzen';

  @override
  String get developerOptions => 'Entwickleroptionen';

  @override
  String get developerOptionsSubtitle => 'Einstellungen für Entwickler ändern';

  @override
  String get language => 'Sprache';

  @override
  String get languageSubtitle => 'Sprache der App ändern';

  @override
  String freeRoomsTitle(Object time) {
    return 'Freie Räume - $time';
  }

  @override
  String get vplanStudents => 'Vertretungsplan Schüler';

  @override
  String get vplanTeachers => 'Vertretungsplan Lehrer';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get appTitle => 'Substitute';

  @override
  String get newVersionAvailable => 'Neue Version verfügbar';

  @override
  String newVersionMessage(String version) {
    return 'Eine neue Version ($version) ist verfügbar. Lade sie herunter und öffne die Datei um sie zu installieren.';
  }

  @override
  String get later => 'Später';

  @override
  String get download => 'Herunterladen';

  @override
  String get appInfo => 'App Info';

  @override
  String get mainDeveloper => 'Hauptentwickler: ';

  @override
  String get developerName => 'Sergey842248';

  @override
  String get formerDeveloper => 'Ehemaliger Entwickler: ';

  @override
  String get formerDeveloperName => 'Oskar';

  @override
  String get openIssue => 'Issue öffnen';

  @override
  String get github => 'GitHub';

  @override
  String version(String version) {
    return 'Version: $version';
  }

  @override
  String get findFreeRoom => 'Freien Raum finden';

  @override
  String get findFreeRoomSubtitle =>
      'Einen Raum finden, der zu einer bestimmten Zeit nicht belegt ist';

  @override
  String get roomPlan => 'Raumplan';

  @override
  String get roomPlanSubtitle => 'Stundenplan eines Raums anzeigen';

  @override
  String get selectRoom => 'Raum auswählen';

  @override
  String get noLessonsInRoom => 'Keine Stunden in diesem Raum';

  @override
  String get noPlanForThisDay =>
      'Kein Vertretungsplan für diesen Tag verfügbar.';

  @override
  String get analysis => 'Analyse';

  @override
  String get analysisSubtitle => 'Eine Analyse des Vertretungsplans erhalten';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSubtitle =>
      'Weitere Einstellungen zur Personalisierung Ihrer Erfahrung';

  @override
  String get addNewClass => 'Neue Klasse hinzufügen';

  @override
  String get dontForgetCredentials => 'Vergiss deine Anmeldedaten nicht!';

  @override
  String get add => 'Hinzufügen';

  @override
  String get selectClass => 'Klasse auswählen';

  @override
  String get noNextLessonFound => 'Keine nächste Stunde gefunden';

  @override
  String get nextHour => 'nächste Stunde';

  @override
  String get weekend => 'Wochenende';

  @override
  String room(String room) {
    return 'Raum $room';
  }

  @override
  String get classSelection => 'Klassenauswahl';

  @override
  String get selectClassTitle => 'Klasse auswählen';

  @override
  String get usernamePasswordWrong => 'Benutzername oder Passwort falsch!';

  @override
  String get wrongSchoolNumber =>
      'Falsche Schulnummer!\n\noder kein Vertretungsplan verfügbar!';

  @override
  String get noInternetConnection => 'Keine Internetverbindung';

  @override
  String get noSubstitutionPlan => 'kein Vertretungsplan';

  @override
  String get wrongSchoolNumberAlt =>
      'Falsche Schulnummer oder kein Vertretungsplan verfügbar';

  @override
  String get noNetworkConnection => 'Keine Netzwerkverbindung';

  @override
  String get week => 'Woche';

  @override
  String get close => 'Schließen';

  @override
  String get courses => 'Kurse';

  @override
  String get noAdditionalInformation =>
      'Keine zusätzlichen Informationen verfügbar';

  @override
  String get search => 'Suche';

  @override
  String get searchTeachers => 'Lehrer suchen';

  @override
  String get searchTeachersSubtitle =>
      'Lehrerkürzel durchsuchen und den Vertretungsplan eines Lehrers ansehen';

  @override
  String get teacherAbbreviationHint => 'Lehrerkürzel (z.B. \"AB\")';

  @override
  String selectedDate(String day, String month, String year) {
    return 'Ausgewähltes Datum: $day.$month.$year';
  }

  @override
  String get see => 'Ansehen';

  @override
  String get scanningTeacherAbbreviations => 'Scanne alle Lehrerkürzel...';

  @override
  String get noTeachersFound => 'Keine Lehrer gefunden';

  @override
  String get noFavoriteClassesFound => 'Keine Lieblingsklassen gefunden.';

  @override
  String get addClassToFavoritesForAnalysis =>
      'Bitte füge eine Klasse zu deinen Favoriten hinzu, um die Analyse zu sehen.';

  @override
  String get nameClass => 'Klasse benennen';

  @override
  String get renameClass => 'Klasse umbenennen';

  @override
  String get classNameHint => 'Benutzerdefinierter Name (optional)';

  @override
  String get couldNotLoadVPlanData =>
      'VPlan-Daten konnten nicht geladen werden.';

  @override
  String get noDataForAnalysisAvailable => 'Keine Daten für Analyse verfügbar.';

  @override
  String teacherLabel(String name) {
    return 'Lehrer: $name';
  }

  @override
  String lessonDetails(String count, String lesson, String place) {
    return '$count. Stunde: $lesson im Raum: $place';
  }

  @override
  String get loadingData => 'Lade Daten...';

  @override
  String get loadingSubstitutionPlan => 'Lade Vertretungsplan...';

  @override
  String get substitutionPlanLoaded => 'Vertretungsplan geladen';

  @override
  String get noSubstitutionPlanToday =>
      'Kein Vertretungsplan für heute verfügbar.';

  @override
  String get noSubstitutionPlanTomorrow =>
      'Kein Vertretungsplan für morgen verfügbar.';

  @override
  String get browsingPlan => 'Durchsuche Plan...';

  @override
  String get analysingRooms => 'Analysiere Räume...';

  @override
  String checkRoom(String room) {
    return 'Überprüfe Raum $room...';
  }

  @override
  String get lessonsInThisRoom => 'Stunden in diesem Raum';

  @override
  String get todayNoLessonsInThisRoom => 'Heute keine Stunden in diesem Raum';

  @override
  String get chooseTimeAndDay => 'Zeit und Tag wählen';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get processCanTakeSeconds =>
      'Dieser Vorgang kann einige Sekunden dauern!';

  @override
  String get loading => 'lade...';

  @override
  String classesFromTeacher(String teacherName, String displayDate) {
    return 'Klassen von $teacherName - $displayDate';
  }

  @override
  String get settingsCredentials => 'Anmeldeinformationen';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsSetTeacherAbbreviations => 'Lehrerkürzel festlegen';

  @override
  String get realName => 'Echter Name';

  @override
  String get saved => 'Fertig!';

  @override
  String get save => 'Speichern';

  @override
  String get schoolNumber => 'Schulnummer';

  @override
  String get username => 'Benutzername';

  @override
  String get password => 'Passwort';

  @override
  String get selfHost => 'Eigene URL';

  @override
  String get useSelfHost => 'oder nutze deine eigene URL';

  @override
  String get useLogin => 'oder nutze den offiziellen Login';

  @override
  String get shareCreds => 'Zugangsdaten teilen';

  @override
  String get credsSaved => 'Zugangsdaten gespeichert!';

  @override
  String get loadPlanAuto => 'Vertretungsplan im Hintergrund laden';

  @override
  String get general => 'Allgemein';

  @override
  String get smartNotifs => 'Intelligente Benachrichtigungen';

  @override
  String get prefClasses => 'Bevorzugte Klassen';

  @override
  String get other => 'Andere';

  @override
  String get callInterv => 'Abrufintervall';

  @override
  String get interv => 'Intervall';

  @override
  String get minutes => 'Minuten';

  @override
  String get hours => 'Stunden';

  @override
  String get onlyRemOnChange => 'Nur bei Änderung benachrichtigen';

  @override
  String get shareTeacherName => 'Lehrernamen teilen';

  @override
  String get showLessonTimes => 'Stundenzeiten anzeigen';

  @override
  String get showLessonTimesSubtitle =>
      'Zeiten der einzelnen Stunden im Vertretungsplan anzeigen';

  @override
  String get hideLessonTimes => 'Stundenzeiten ausblenden';

  @override
  String get hideLessonTimesSubtitle =>
      'Zeiten der einzelnen Stunden im Vertretungsplan ausblenden';

  @override
  String get planSettings => 'Plan-Einstellungen';

  @override
  String get planSettingsSubtitle => 'Einstellungen für den Vertretungsplan';

  @override
  String get hideTeacher => 'Lehrer ausblenden';

  @override
  String get hideTeacherSubtitle => 'Lehrernamen im Vertretungsplan ausblenden';

  @override
  String get hidePersons => 'Personen ausblenden';

  @override
  String get hidePersonsSubtitle => 'Den Personenbereich ausblenden';

  @override
  String get persons => 'Personen';

  @override
  String get noPersonsYet =>
      'Noch keine Personen. Füge eine Person hinzu, um nur die gewünschten Kurse anzuzeigen.';

  @override
  String get addPerson => 'Person hinzufügen';

  @override
  String get personName => 'Name der Person';

  @override
  String get enterPersonName => 'Bitte gib einen Namen für die Person ein.';

  @override
  String get savePerson => 'Person speichern';

  @override
  String get selectPersonClass => 'Wähle eine Klasse für die neue Person';

  @override
  String coursesFor(String name) {
    return 'Kurse für $name';
  }

  @override
  String get sickTrack => 'Krankheitstracker';

  @override
  String get sickTrackSubtitle =>
      'Verpasste Stunden verfolgen und Unterschriften holen';

  @override
  String get sickTrackAdd => 'Krankheitszeitraum hinzufügen';

  @override
  String get selectClassOrPerson => 'Klasse oder Person auswählen';

  @override
  String get selectClassOrPersonHint =>
      'Wähle eine gespeicherte Klasse oder Person zum Verfolgen';

  @override
  String get anotherClass => 'Andere Klasse';

  @override
  String get selectCourses => 'Kurse auswählen';

  @override
  String get selectSickDays => 'Krankheitstage auswählen';

  @override
  String get sickDays => 'Krankheitstage';

  @override
  String get addDay => 'Tag hinzufügen';

  @override
  String get noSickDaysSelected => 'Keine Tage ausgewählt';

  @override
  String get missedLessons => 'Verpasste Stunden';

  @override
  String get noMissedLessons => 'Keine verpassten Stunden';

  @override
  String get noSickTrackEntries =>
      'Noch keine Krankheitszeiträume. Füge einen hinzu, um zu sehen, welche Stunden du verpasst hast.';

  @override
  String get getSignature => 'Unterschrift holen';

  @override
  String missedLesson(String date, String count, String course) {
    return '$date · $count. Stunde · $course';
  }

  @override
  String get markSignatureDone => 'Unterschrift als erledigt markieren';

  @override
  String signatureDoneQuestion(String course) {
    return 'Möchtest du die Unterschrift für $course als erledigt markieren?';
  }

  @override
  String get done => 'Erledigt';

  @override
  String get time => 'Zeit';

  @override
  String get hour => 'Stunde';

  @override
  String get fullDay => 'Ganzer Tag';

  @override
  String get fullDayMessage =>
      'Alle Stunden dieses Tages ohne Zeitfilter anzeigen.';

  @override
  String get selectDate => 'Tippen, um ein Datum zu wählen';

  @override
  String get selectTime => 'Tippen, um eine Uhrzeit zu wählen';

  @override
  String get lessonTimes => 'Stundenzeiten';

  @override
  String get lessonTimesSubtitle =>
      'Zeiten der einzelnen Unterrichtsstunden manuell einstellen';
}
