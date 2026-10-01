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
  String get deleteClassTitle => 'Klasse löschen?';

  @override
  String deleteClassMessage(String className) {
    return 'Die Klasse \"$className\" wird entfernt. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deletePersonTitle => 'Person löschen?';

  @override
  String deletePersonMessage(String personName) {
    return 'Die Person \"$personName\" wird entfernt. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteAction => 'Löschen';

  @override
  String get deleteSickEntryTitle => 'Eintrag löschen?';

  @override
  String deleteSickEntryMessage(String classId) {
    return 'Der Krankheitseintrag für \"$classId\" wird entfernt. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteLessonTitle => 'Unterrichtszeit löschen?';

  @override
  String deleteLessonMessage(int count) {
    return 'Die $count. Unterrichtszeit wird entfernt. Das kann nicht rückgängig gemacht werden.';
  }

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
  String get hidePreviewClasses => 'Vorschau bei Klassen ausblenden';

  @override
  String get hidePreviewClassesSubtitle =>
      'Die „Nächste Stunde“-Vorschau unterhalb der Klassen ausblenden';

  @override
  String get hidePreviewPersons => 'Vorschau bei Personen ausblenden';

  @override
  String get hidePreviewPersonsSubtitle =>
      'Die „Nächste Stunde“-Vorschau unterhalb der Personen ausblenden';

  @override
  String get hidePreview => 'Vorschau ausblenden';

  @override
  String get showPreview => 'Vorschau anzeigen';

  @override
  String get backup => 'Sichern & Wiederherstellen';

  @override
  String get backupSubtitle =>
      'Einstellungen, Klassen, Personen und gespeicherte Vertretungspläne exportieren und importieren';

  @override
  String get backupExport => 'Konfiguration exportieren';

  @override
  String get backupExportSubtitle =>
      'Alle Einstellungen als Datei teilen oder speichern';

  @override
  String get backupImport => 'Konfiguration importieren';

  @override
  String get backupImportSubtitle => 'Eine zuvor exportierte Datei einlesen';

  @override
  String get backupImportRestore => 'Konfiguration importieren';

  @override
  String get backupImportNoCredentials =>
      'Importiert – die Datei enthielt keine Zugangsdaten.';

  @override
  String get backupExportSubject => 'Konfiguration von Substitute';

  @override
  String get backupExportText =>
      'Konfiguration von Substitute (Einstellungen, Klassen, Personen, Zugangsdaten). Enthält das Passwort im Klartext – bitte vorsichtig weitergeben.';

  @override
  String get backupNote =>
      'Gesichert werden Einstellungen, Klassen, Personen, Kurse und Zugangsdaten. Nur zwischengespeicherte Pläne sind nicht enthalten. Achtung: Die Datei enthält das Passwort im Klartext. Nach dem Import empfiehlt es sich, die App neu zu starten.';

  @override
  String get backupCredentialsTitle => 'Zugangsdaten enthalten';

  @override
  String get backupCredentialsWarning =>
      'Die Exportdatei enthält dein Passwort im Klartext. Teile sie nur mit Personen, denen du vertraust – oder teile sie ohne Zugangsdaten.';

  @override
  String get backupCredentialsContinue => 'Mit Zugangsdaten';

  @override
  String get backupShareWithoutCredentials => 'Ohne Zugangsdaten teilen';

  @override
  String get backupExportTextWithoutCredentials =>
      'Konfiguration von Substitute (Einstellungen, Klassen, Personen) – ohne Zugangsdaten.';

  @override
  String get backupImportTitle => 'Konfiguration importieren';

  @override
  String get backupImportQuestion =>
      'Sollen die vorhandenen Einstellungen ersetzt werden?';

  @override
  String get backupImportMerge => 'Ergänzen';

  @override
  String get backupImportReplace => 'Ersetzen';

  @override
  String backupImportDone(int applied, int removed) {
    return 'Import fertig: $applied Einstellungen übernommen, $removed entfernt.';
  }

  @override
  String get backupImportFailed => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get backupFailed => 'Der Export ist fehlgeschlagen.';

  @override
  String get backupErrorForeign => 'Diese Datei stammt nicht aus dieser App.';

  @override
  String get backupErrorFutureSchema =>
      'Die Datei wurde mit einer neueren App-Version erstellt.';

  @override
  String get weekdayShortMon => 'Mo';

  @override
  String get weekdayShortTue => 'Di';

  @override
  String get weekdayShortWed => 'Mi';

  @override
  String get weekdayShortThu => 'Do';

  @override
  String get weekdayShortFri => 'Fr';

  @override
  String get weekdayShortSat => 'Sa';

  @override
  String get weekdayShortSun => 'So';

  @override
  String get previewSettings => 'Vorschau';

  @override
  String get previewSettingsSubtitle =>
      'Die „Nächste Stunde“-Vorschau ein- und ausblenden';

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
  String get renamePerson => 'Person umbenennen';

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

  @override
  String get defaultPlanModePerson => 'Personen';

  @override
  String get defaultPlanModePersonAuto => 'Automatisch';

  @override
  String get defaultPlanModePersonAutoSubtitle =>
      'Zeige heute, außer der Schultag ist vorbei';

  @override
  String get defaultPlanModePersonLatest => 'Neueste';

  @override
  String get defaultPlanModePersonLatestSubtitle =>
      'Immer den neuesten verfügbaren Plan anzeigen';

  @override
  String get defaultPlanModePersonToday => 'Heute';

  @override
  String get defaultPlanModePersonTodaySubtitle =>
      'Immer nur den heutigen Plan anzeigen';

  @override
  String get defaultPlanModeClass => 'Klassen';

  @override
  String get defaultPlanModeClassAuto => 'Automatisch';

  @override
  String get defaultPlanModeClassAutoSubtitle =>
      'Zeige heute, außer der Schultag ist vorbei';

  @override
  String get defaultPlanModeClassLatest => 'Neueste';

  @override
  String get defaultPlanModeClassLatestSubtitle =>
      'Immer den neuesten verfügbaren Plan anzeigen';

  @override
  String get defaultPlanModeClassToday => 'Heute';

  @override
  String get defaultPlanModeClassTodaySubtitle =>
      'Immer nur den heutigen Plan anzeigen';

  @override
  String get defaultPlanModePreview => 'Vorschau';

  @override
  String get defaultPlanModePreviewAuto => 'Automatisch';

  @override
  String get defaultPlanModePreviewAutoSubtitle =>
      'Zeige heute, außer der Schultag ist vorbei';

  @override
  String get defaultPlanModePreviewLatest => 'Neueste';

  @override
  String get defaultPlanModePreviewLatestSubtitle =>
      'Immer den neuesten verfügbaren Plan anzeigen';

  @override
  String get defaultPlanModePreviewToday => 'Heute';

  @override
  String get defaultPlanModePreviewTodaySubtitle =>
      'Immer nur den heutigen Plan anzeigen';

  @override
  String get defaultPlanModePreviewClass => 'Vorschau der Klassen';

  @override
  String get defaultPlanModePreviewClassAuto => 'Automatisch';

  @override
  String get defaultPlanModePreviewClassAutoSubtitle =>
      'Zeige heute, außer der Schultag ist vorbei';

  @override
  String get defaultPlanModePreviewClassLatest => 'Neueste';

  @override
  String get defaultPlanModePreviewClassLatestSubtitle =>
      'Immer den neuesten verfügbaren Plan anzeigen';

  @override
  String get defaultPlanModePreviewClassToday => 'Heute';

  @override
  String get defaultPlanModePreviewClassTodaySubtitle =>
      'Immer nur den heutigen Plan anzeigen';

  @override
  String get defaultPlanModePreviewPerson => 'Vorschau der Personen';

  @override
  String get defaultPlanModePreviewPersonAuto => 'Automatisch';

  @override
  String get defaultPlanModePreviewPersonAutoSubtitle =>
      'Zeige heute, außer der Schultag ist vorbei';

  @override
  String get defaultPlanModePreviewPersonLatest => 'Neueste';

  @override
  String get defaultPlanModePreviewPersonLatestSubtitle =>
      'Immer den neuesten verfügbaren Plan anzeigen';

  @override
  String get defaultPlanModePreviewPersonToday => 'Heute';

  @override
  String get defaultPlanModePreviewPersonTodaySubtitle =>
      'Immer nur den heutigen Plan anzeigen';

  @override
  String get defaultPlanModePreviewEntryTitle => 'Standard-Planmodus';

  @override
  String get defaultPlanModePreviewEntrySubtitle =>
      'Getrennt für Personen, Klassen und deren Vorschauen';

  @override
  String get sync => 'Sync';

  @override
  String get syncSubtitle =>
      'Klassen, Personen und Pläne über mehrere Geräte gleich halten';

  @override
  String get syncShareHub => 'Sync & Share';

  @override
  String get syncShareHubSubtitle =>
      'Daten zwischen deinen Geräten abgleichen und mit anderen teilen';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncServerRunning => 'Server läuft';

  @override
  String get syncServerStopped => 'Server ist gestoppt';

  @override
  String get syncServerCheck => 'Server prüfen';

  @override
  String get syncNotConfigured => 'Kein Sync-Server eingetragen';

  @override
  String get syncStart => 'Sync starten';

  @override
  String get syncStartSubtitle =>
      'Erzeugt einen Code aus zehn Wörtern, der deine Geräte verbindet';

  @override
  String get syncJoin => 'Sync beitreten';

  @override
  String get syncJoinSubtitle =>
      'Auf einem anderen Gerät die zehn Wörter eines bestehenden Syncs eingeben';

  @override
  String get syncPassphrase => 'Sync-Code';

  @override
  String get syncPassphraseHint => 'Zehn Wörter, z.B. blue sky river seven';

  @override
  String get syncPassphraseGenerate => 'Neuen Code erzeugen';

  @override
  String get syncPassphraseCopy => 'Code kopieren';

  @override
  String get syncPassphraseCopied => 'Code in die Zwischenablage kopiert';

  @override
  String syncPassphraseUnknownWord(Object words) {
    return 'Diese Wörter stehen nicht in der Liste: $words';
  }

  @override
  String get syncPassphraseTooFewWords =>
      'Bitte mindestens drei Wörter eingeben';

  @override
  String get syncPassphraseEmpty => 'Bitte einen Code eingeben';

  @override
  String get syncSettingsToggle => 'Einstellungen mit übertragen';

  @override
  String get syncSettingsToggleSubtitle =>
      'Ausgeschaltet bleiben die Einstellungen auf jedem Gerät und werden nicht übernommen';

  @override
  String get syncSettingsNote =>
      'Klassen, Personen, Kurse und Pläne werden immer übertragen. Das Schulpasswort niemals.';

  @override
  String get syncSettingsNotePlain =>
      'Klassen, Personen, Kurse und Pläne werden immer übertragen. Das Schulpasswort niemals.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncNever => 'Noch nie synchronisiert';

  @override
  String syncLastSync(Object when) {
    return 'Letzter Sync: $when';
  }

  @override
  String get syncInProgress => 'Wird synchronisiert …';

  @override
  String syncDone(Object changes, Object devices) {
    return 'Sync fertig. $changes Änderungen von $devices Geräten.';
  }

  @override
  String get syncDoneNoChanges => 'Sync fertig. Alles ist aktuell.';

  @override
  String get syncAutoTitle => 'Automatisch synchronisiert';

  @override
  String syncAutoOn(Object minutes) {
    return 'Läuft von selbst: beim Start, beim Zurückkommen in die App und danach alle $minutes Minuten.';
  }

  @override
  String syncAutoLast(Object when) {
    return 'Zuletzt automatisch: $when';
  }

  @override
  String get syncAutoNever => 'Noch nicht automatisch gelaufen.';

  @override
  String syncPeerCount(Object count) {
    return '$count Geräte in dieser Kette (mit diesem)';
  }

  @override
  String syncAutoFailing(Object count) {
    return '$count Fehlversuche in Folge – der Server wird seltener angesprochen, bis es wieder klappt.';
  }

  @override
  String syncPayloadCount(Object count) {
    return '$count Einträge werden übertragen';
  }

  @override
  String get syncPayloadEmpty =>
      'Hier ist noch nichts zum Übertragen. Sync kann erst Daten bringen, wenn auf einem anderen Gerät welche vorhanden sind.';

  @override
  String get syncAloneNote =>
      'Dieses Gerät ist allein im Sync. Es werden Daten hochgeladen, aber es kommen keine zurück – das ist kein Fehler.';

  @override
  String get syncDoneAlone =>
      'Sync fertig. Deine Daten wurden übertragen, aber noch kein anderes Gerät ist diesem Sync beigetreten.';

  @override
  String syncFailed(Object reason) {
    return 'Sync fehlgeschlagen: $reason';
  }

  @override
  String get syncLeave => 'Sync verlassen';

  @override
  String get syncLeaveConfirmTitle => 'Sync verlassen?';

  @override
  String get syncLeaveConfirm =>
      'Deine Daten bleiben auf diesem Gerät. Sie werden nur nicht mehr mit den anderen Geräten abgeglichen.';

  @override
  String get syncLeaveDone =>
      'Du hast den Sync verlassen. Deine Daten sind weiterhin auf diesem Gerät.';

  @override
  String get syncLeaveFailed =>
      'Der Server war nicht erreichbar. Der Sync wurde auf diesem Gerät trotzdem beendet.';

  @override
  String get syncDevices => 'Geräte in diesem Sync';

  @override
  String get syncDevicesEmpty =>
      'Noch kein anderes Gerät ist diesem Sync beigetreten';

  @override
  String get syncDeviceThisOne => 'Dieses Gerät';

  @override
  String get syncDeviceUnknown => 'Unbekanntes Gerät';

  @override
  String get syncDeleteChain => 'Sync vollständig löschen';

  @override
  String get syncDeleteChainConfirmTitle => 'Den ganzen Sync löschen?';

  @override
  String get syncDeleteChainConfirm =>
      'Der Sync-Code wird vom Server gelöscht. Andere Geräte behalten ihre Daten, können aber nicht mehr synchronisieren.';

  @override
  String get syncDeleteChainDone => 'Der Sync wurde auf dem Server gelöscht.';

  @override
  String get syncResume => 'Weiter synchronisieren';

  @override
  String get syncResumeSubtitle =>
      'Den Sync fortsetzen, den du früher verlassen hast';

  @override
  String get syncRestart => 'Neuen Sync starten';

  @override
  String get syncRestartConfirmTitle => 'Neu beginnen?';

  @override
  String get syncRestartConfirm =>
      'Dieses Gerät verlässt den aktuellen Sync. Deine Daten bleiben. Du bekommst einen neuen Code.';

  @override
  String get syncErrorNetwork => 'Der Sync-Server war nicht erreichbar';

  @override
  String get syncErrorTimeout => 'Der Sync-Server hat zu lange gebraucht';

  @override
  String get syncErrorNotFound =>
      'Dieser Sync-Code ist unbekannt – bitte die Wörter prüfen';

  @override
  String get syncErrorWrongPassphrase =>
      'Falscher Code – oder die Daten wurden unterwegs verändert';

  @override
  String get syncErrorForbidden => 'Der Server hat die Anfrage abgelehnt';

  @override
  String get syncErrorTooManyRequests =>
      'Zu viele Anfragen. Bitte in einer Minute erneut versuchen';

  @override
  String get syncErrorConflict =>
      'Dieser Sync ist voll, oder es gibt zu viele Shares';

  @override
  String get syncErrorServerError => 'Der Sync-Server hat ein Problem';

  @override
  String get syncErrorTooLarge => 'Die Daten sind zu groß für den Server';

  @override
  String get syncErrorInvalidShare => 'Dieser Share ist nicht erlaubt';

  @override
  String get syncErrorForeignApp => 'Diese Daten stammen nicht aus Substitute';

  @override
  String get syncErrorFutureSchema =>
      'Diese Daten stammen aus einer neueren Version der App';

  @override
  String get share => 'Teilen';

  @override
  String get shareTitle => 'Meine Shares';

  @override
  String get shareSubtitle =>
      'Ausgewählte Klassen und Personen mit anderen Kolleginnen und Kollegen teilen';

  @override
  String get shareCreate => 'Neuer Share';

  @override
  String get shareCreateSubtitle =>
      'Auswählen, was für andere sichtbar sein soll';

  @override
  String get shareEdit => 'Share bearbeiten';

  @override
  String get shareEmpty =>
      'Noch keine Shares. Lege einen an, um anderen deine Klassen und Personen zu geben.';

  @override
  String get shareUsername => 'Mein Nutzername';

  @override
  String get shareUsernameSubtitle =>
      'Zehn Wörter, die Kolleginnen und Kollegen eingeben, um deine Shares zu öffnen';

  @override
  String get shareUsernameRegenerate => 'Neuer Nutzername';

  @override
  String get shareUsernameRegenerateConfirmTitle => 'Neuer Nutzername?';

  @override
  String get shareUsernameRegenerateConfirm =>
      'Alle Shares wandern auf den neuen Nutzernamen. Wer den alten gespeichert hat, muss den neuen eingeben.';

  @override
  String get shareDisplayName => 'Mein Anzeigename';

  @override
  String get shareDisplayNameSubtitle =>
      'Wird im Suchmenü deiner Schule angezeigt';

  @override
  String get shareLabel => 'Name des Shares';

  @override
  String get shareLabelHint => 'z.B. Vertretungspläne Herbst';

  @override
  String get shareSearchable => 'Im Suchmenü anzeigen';

  @override
  String get shareSearchableSubtitle =>
      'Kolleginnen und Kollegen deiner Schule können dich finden und aus deinen Shares auswählen';

  @override
  String get shareGlobal => 'Globaler Share';

  @override
  String get shareGlobalSubtitle =>
      'Auch von Lehrkräften anderer Schulen nutzbar, die deinen Nutzernamen kennen';

  @override
  String get sharePassword => 'Passwort';

  @override
  String get sharePasswordSubtitle =>
      'Schützt den Share – auch vor Menschen mit den Schulzugangsdaten';

  @override
  String get sharePasswordGenerate => 'Passwort erzeugen';

  @override
  String get sharePasswordOwn => 'Dein eigenes Passwort';

  @override
  String get sharePasswordHint => 'Zehn Wörter, z.B. red moon water nine';

  @override
  String get sharePasswordRequired =>
      'Dieser Share hat ein Passwort. Gib es ein, um ihn zu öffnen.';

  @override
  String get shareSelectWhat => 'Was soll geteilt werden?';

  @override
  String get shareSelectClasses => 'Klassen';

  @override
  String get shareSelectPersons => 'Personen';

  @override
  String get shareSelectEverything => 'Alle auswählen';

  @override
  String get shareSelectNothing => 'Keine auswählen';

  @override
  String get shareIncludeSettings => 'Einstellungen mitteilen';

  @override
  String get shareIncludeSettingsSubtitle =>
      'Auch die Anzeigeeinstellungen teilen';

  @override
  String get shareIncludePlans => 'Gespeicherte Pläne mitteilen';

  @override
  String get shareIncludePlansSubtitle =>
      'Die auf diesem Gerät gespeicherten Vertretungspläne teilen';

  @override
  String get shareIncludeHistory => 'Pläne aus der Vergangenheit mitteilen';

  @override
  String shareIncludeHistorySubtitle(Object days) {
    return 'Sonst werden nur die letzten $days Tage geteilt';
  }

  @override
  String get shareSelectNothingSelected =>
      'Bitte mindestens eine Klasse oder Person auswählen';

  @override
  String get sharePublished => 'Share erstellt';

  @override
  String get shareUpdated => 'Share aktualisiert';

  @override
  String get shareDeleted => 'Share gelöscht';

  @override
  String get sharePasswordSaved => 'Passwort auf diesem Gerät gespeichert';

  @override
  String get shareDeleteConfirmTitle => 'Diesen Share löschen?';

  @override
  String get shareDeleteConfirm =>
      'Niemand kann ihn mehr öffnen. Bereits importierte Daten bleiben bei anderen auf ihren Geräten.';

  @override
  String get shareGlobalNote =>
      'Ein globaler Share kann von Lehrkräften jeder Schule geöffnet werden, die den Nutzernamen kennen. In deren Suchmenü erscheint er nicht.';

  @override
  String get shareBrowse => 'Shares finden';

  @override
  String get shareBrowseSubtitle =>
      'Sieh, was Kolleginnen und Kollegen deiner Schule geteilt haben';

  @override
  String get shareBrowseEmpty =>
      'In deiner Schule hat noch niemand etwas geteilt';

  @override
  String get shareBrowseEmptySubtitle =>
      'Sobald jemand einen Share als suchbar markiert, erscheint er hier.';

  @override
  String get shareBrowseLoginRequired =>
      'Melde dich zuerst mit deiner Schulnummer an';

  @override
  String get shareBrowseLoginRequiredSubtitle =>
      'Shares werden nur innerhalb der eigenen Schule gefunden. Deshalb ist die Anmeldung nötig.';

  @override
  String get shareBrowseEnterUsername => 'Nutzernamen eingeben';

  @override
  String get shareBrowseEnterUsernameSubtitle =>
      'Du kennst die zehn Wörter einer Kollegin oder eines Kollegen? Gib sie hier ein, um den Share direkt zu öffnen.';

  @override
  String get shareBrowseGlobalOnly =>
      'Dieser Share ist global – er kann auch von Lehrkräften anderer Schulen geöffnet werden.';

  @override
  String shareOf(Object name) {
    return 'Shares von $name';
  }

  @override
  String get shareContents => 'Inhalt';

  @override
  String shareContentsClasses(Object count) {
    return '$count Klassen';
  }

  @override
  String shareContentsPersons(Object count) {
    return '$count Personen';
  }

  @override
  String shareContentsPlans(Object count) {
    return '$count Pläne';
  }

  @override
  String get shareSelectItems => 'Was möchtest du übernehmen?';

  @override
  String get shareImportModeTitle => 'Wie soll es übernommen werden?';

  @override
  String get shareImportMode => 'Übernehmen als';

  @override
  String get shareImportModeOriginal => 'Original';

  @override
  String get shareImportModeOriginalSubtitle =>
      'Genau wie geteilt: Klassen, Personen und Kurse bleiben, wie sie sind';

  @override
  String get shareImportModePlans => 'Pläne';

  @override
  String get shareImportModePlansSubtitle =>
      'Jede Person wird zu einem Plan mit ihren Kursen';

  @override
  String get shareImportModePersons => 'Personen';

  @override
  String get shareImportModePersonsSubtitle =>
      'Es werden nur die Namen als Personen übernommen';

  @override
  String get shareImport => 'Übernehmen';

  @override
  String shareImportDone(
      Object classes, Object name, Object persons, Object plans) {
    return 'Übernommen von $name: $persons Personen, $classes Klassen, $plans Pläne';
  }

  @override
  String get shareNothingToImport => 'Nichts ausgewählt';

  @override
  String get shareNameBlocked =>
      'Dieser Name ist nicht erlaubt. Bitte wähle einen anderen.';

  @override
  String get shareNameTooShort => 'Bitte mindestens zwei Zeichen eingeben';

  @override
  String get shareNameTooLong => 'Dieser Name ist zu lang';

  @override
  String get shareNameEmpty => 'Bitte einen Namen eingeben';

  @override
  String get shareErrorNoUsername => 'Es wurde noch kein Nutzername erzeugt';

  @override
  String get shareErrorNothingSelected =>
      'Bitte auswählen, was geteilt werden soll';

  @override
  String get shareErrorWrongCredentials =>
      'Dieser Share ließ sich nicht öffnen – falscher Code oder falsche Schulnummer?';

  @override
  String get shareErrorUnreadable => 'Diese Daten konnten nicht gelesen werden';

  @override
  String get shareDemoNoShares => 'Es hat noch niemand etwas geteilt';

  @override
  String get shareDelete => 'Share löschen';
}
