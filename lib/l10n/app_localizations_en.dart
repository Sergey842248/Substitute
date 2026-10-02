// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get credentials => 'Credentials';

  @override
  String get credentialsSubtitle => 'stundenplan24 credentials';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Notifications for substitution plan';

  @override
  String get setTeacherAbbreviations => 'Set Teacher abbreviations';

  @override
  String get setTeacherAbbreviationsSubtitle =>
      'Replace teacher abbreviations with Real ones';

  @override
  String get developerOptions => 'Developer options';

  @override
  String get developerOptionsSubtitle => 'Change Settings meant for developers';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSubtitle =>
      'Light or dark, and what the navigation bar shows';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeSubtitle =>
      'Dark is the default. Light is easier on the eyes in daylight.';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceShowSyncTab => 'Show sync menu in the bar';

  @override
  String get appearanceShowSyncTabSubtitle =>
      'When off it stays reachable – switch it back on under Settings → Appearance.';

  @override
  String get appearanceNavBar => 'Navigation bar';

  @override
  String get appearanceNavBarSubtitle => 'Which entries sit at the bottom';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Change the language of the app';

  @override
  String freeRoomsTitle(Object time) {
    return 'Free rooms - $time';
  }

  @override
  String get vplanStudents => 'vplan students';

  @override
  String get vplanTeachers => 'vplan teachers';

  @override
  String get dashboard => 'dashboard';

  @override
  String get appTitle => 'Substitute';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String newVersionMessage(String version) {
    return 'A new version ($version) is available. Just download it and open the file to install it.';
  }

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get appInfo => 'App Info';

  @override
  String get mainDeveloper => 'Main-Developer: ';

  @override
  String get developerName => 'Sergey842248';

  @override
  String get formerDeveloper => 'Former Developer: ';

  @override
  String get formerDeveloperName => 'Oskar';

  @override
  String get openIssue => 'Open Issue';

  @override
  String get github => 'GitHub';

  @override
  String version(String version) {
    return 'version: $version';
  }

  @override
  String get findFreeRoom => 'Find free room';

  @override
  String get findFreeRoomSubtitle =>
      'Find a room which isn\'t occupied for a specific time';

  @override
  String get roomPlan => 'Room plan';

  @override
  String get roomPlanSubtitle => 'View the schedule of a room';

  @override
  String get selectRoom => 'Select room';

  @override
  String get noLessonsInRoom => 'No lessons in this room';

  @override
  String get noPlanForThisDay => 'No substitution plan available for this day.';

  @override
  String get analysis => 'Analysis';

  @override
  String get analysisSubtitle => 'Get an analysis of the substitution plan';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'More Settings to personalize your experience';

  @override
  String get addNewClass => 'Add a new class';

  @override
  String get dontForgetCredentials => 'Don\'t forget your credentials!';

  @override
  String get add => 'Add';

  @override
  String get selectClass => 'Select a class';

  @override
  String get noNextLessonFound => 'No next lesson found';

  @override
  String get nextHour => 'next hour';

  @override
  String get weekend => 'Weekend';

  @override
  String room(String room) {
    return 'Room $room';
  }

  @override
  String get classSelection => 'Class selection';

  @override
  String get selectClassTitle => 'Select class';

  @override
  String get usernamePasswordWrong => 'Username or password incorrect!';

  @override
  String get wrongSchoolNumber =>
      'Wrong schoolnumber!\n\nor no substitution plan available!';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get noSubstitutionPlan => 'no substitution plan';

  @override
  String get wrongSchoolNumberAlt =>
      'Wrong school-number or no substitution plan available';

  @override
  String get noNetworkConnection => 'No Network connection';

  @override
  String get week => 'Week';

  @override
  String get close => 'Close';

  @override
  String get courses => 'Courses';

  @override
  String get noAdditionalInformation => 'No additional information available';

  @override
  String get search => 'Search';

  @override
  String get searchTeachers => 'Search Teachers';

  @override
  String get searchTeachersSubtitle =>
      'Search teacher abbreviations and view a teacher\'s substitution plan';

  @override
  String get teacherAbbreviationHint => 'Teacher abbreviation (like \"AB\")';

  @override
  String selectedDate(String day, String month, String year) {
    return 'Selected Date: $day.$month.$year';
  }

  @override
  String get see => 'See';

  @override
  String get scanningTeacherAbbreviations =>
      'Scanning all Teacher abbreviations...';

  @override
  String get noTeachersFound => 'No teachers found';

  @override
  String get noFavoriteClassesFound => 'No favorite classes found.';

  @override
  String get addClassToFavoritesForAnalysis =>
      'Please add a class to your favorites to see the analysis.';

  @override
  String get nameClass => 'Name the class';

  @override
  String get renameClass => 'Rename class';

  @override
  String get classNameHint => 'Custom name (optional)';

  @override
  String get deleteClassTitle => 'Delete class?';

  @override
  String deleteClassMessage(String className) {
    return 'The class \"$className\" will be removed. This cannot be undone.';
  }

  @override
  String get deletePersonTitle => 'Delete person?';

  @override
  String deletePersonMessage(String personName) {
    return 'The person \"$personName\" will be removed. This cannot be undone.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteSickEntryTitle => 'Delete entry?';

  @override
  String deleteSickEntryMessage(String classId) {
    return 'The sick track entry for \"$classId\" will be removed. This cannot be undone.';
  }

  @override
  String get deleteLessonTitle => 'Delete lesson time?';

  @override
  String deleteLessonMessage(int count) {
    return 'The $count. lesson time will be removed. This cannot be undone.';
  }

  @override
  String get couldNotLoadVPlanData => 'Could not load VPlan data.';

  @override
  String get noDataForAnalysisAvailable => 'No data for analysis available.';

  @override
  String teacherLabel(String name) {
    return 'Teacher: $name';
  }

  @override
  String lessonDetails(String count, String lesson, String place) {
    return '$count. Hour: $lesson in Room: $place';
  }

  @override
  String get loadingData => 'Loading data...';

  @override
  String get loadingSubstitutionPlan => 'Loading substitution plan...';

  @override
  String get substitutionPlanLoaded => 'Substitution plan loaded';

  @override
  String get noSubstitutionPlanToday =>
      'No Substitution plan available for today.';

  @override
  String get noSubstitutionPlanTomorrow =>
      'No Substitution plan available for tomorrow.';

  @override
  String get browsingPlan => 'Browsing plan...';

  @override
  String get analysingRooms => 'Analysing Rooms...';

  @override
  String checkRoom(String room) {
    return 'Check room $room...';
  }

  @override
  String get lessonsInThisRoom => 'Lessons in this room';

  @override
  String get todayNoLessonsInThisRoom => 'Today no lessons in this room';

  @override
  String get chooseTimeAndDay => 'Choose time and day';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get processCanTakeSeconds => 'This process can take a few seconds!';

  @override
  String get loading => 'loading...';

  @override
  String classesFromTeacher(String teacherName, String displayDate) {
    return 'Classes from $teacherName - $displayDate';
  }

  @override
  String get settingsCredentials => 'Credentials';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsSetTeacherAbbreviations => 'Set Teacher abbreviations';

  @override
  String get realName => 'Real name';

  @override
  String get saved => 'Saved!';

  @override
  String get save => 'Save';

  @override
  String get schoolNumber => 'School-number';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get selfHost => 'Your own URL';

  @override
  String get useSelfHost => 'or use your own URL';

  @override
  String get useLogin => 'or use official Login';

  @override
  String get shareCreds => 'Share credentials';

  @override
  String get credsSaved => 'Credentials saved!';

  @override
  String get loadPlanAuto => 'Load Substitution plan automatically';

  @override
  String get general => 'General';

  @override
  String get smartNotifs => 'Smart notifications';

  @override
  String get prefClasses => 'Preferred classes';

  @override
  String get other => 'Other';

  @override
  String get callInterv => 'Call interval';

  @override
  String get interv => 'Interval';

  @override
  String get minutes => 'Minutes';

  @override
  String get hours => 'Hours';

  @override
  String get onlyRemOnChange => 'Only remind when lesson changes';

  @override
  String get shareTeacherName => 'Share teacher name';

  @override
  String get showLessonTimes => 'Show lesson times';

  @override
  String get showLessonTimesSubtitle =>
      'Show times of individual lessons in the substitution plan';

  @override
  String get hideLessonTimes => 'Hide lesson times';

  @override
  String get hideLessonTimesSubtitle =>
      'Hide times for individual lessons in the plan';

  @override
  String get planSettings => 'Plan Settings';

  @override
  String get planSettingsSubtitle => 'Settings for the substitution plan';

  @override
  String get hideTeacher => 'Hide Teacher';

  @override
  String get hideTeacherSubtitle =>
      'Hide teacher names in the substitution plan';

  @override
  String get hidePersons => 'Hide Persons';

  @override
  String get hidePersonsSubtitle => 'Hide the persons section';

  @override
  String get hidePreviewClasses => 'Hide preview for classes';

  @override
  String get hidePreviewClassesSubtitle =>
      'Hide the next lesson preview below the classes';

  @override
  String get hidePreviewPersons => 'Hide preview for persons';

  @override
  String get hidePreviewPersonsSubtitle =>
      'Hide the next lesson preview below the persons';

  @override
  String get hidePreview => 'Hide preview';

  @override
  String get showPreview => 'Show preview';

  @override
  String get backup => 'Backup & Restore';

  @override
  String get backupSubtitle =>
      'Export and import settings, classes, persons and cached substitution plans';

  @override
  String get backupExport => 'Export configuration';

  @override
  String get backupExportSubtitle => 'Share or save all settings as a file';

  @override
  String get backupImport => 'Import configuration';

  @override
  String get backupImportSubtitle => 'Read a previously exported file';

  @override
  String get backupImportRestore => 'Import configuration';

  @override
  String get backupImportNoCredentials =>
      'Imported – the file did not contain any credentials.';

  @override
  String get backupExportSubject => 'Substitute configuration';

  @override
  String get backupExportText =>
      'Substitute configuration (settings, classes, persons, credentials). It contains your password in plain text – please share it carefully.';

  @override
  String get backupNote =>
      'Settings, classes, persons, courses, room data and credentials are backed up. Only cached plans are left out. Note: the file contains your password in plain text. After importing, restarting the app is recommended.';

  @override
  String get backupCredentialsTitle => 'Contains credentials';

  @override
  String get backupCredentialsWarning =>
      'The exported file contains your password in plain text. Only share it with people you trust – or share it without credentials.';

  @override
  String get backupCredentialsContinue => 'With credentials';

  @override
  String get backupShareWithoutCredentials => 'Share without credentials';

  @override
  String get backupExportTextWithoutCredentials =>
      'Substitute configuration (settings, classes, persons) – without credentials.';

  @override
  String get backupImportTitle => 'Import configuration';

  @override
  String get backupImportQuestion =>
      'Should the existing settings be replaced?';

  @override
  String get backupImportMerge => 'Merge';

  @override
  String get backupImportReplace => 'Replace';

  @override
  String backupImportDone(int applied, int removed) {
    return 'Import done: $applied settings applied, $removed removed.';
  }

  @override
  String get backupImportFailed => 'The file could not be read.';

  @override
  String get backupFailed => 'Export failed.';

  @override
  String get backupErrorForeign => 'This file was not created by this app.';

  @override
  String get backupErrorFutureSchema =>
      'The file was created by a newer version of the app.';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get previewSettings => 'Preview';

  @override
  String get previewSettingsSubtitle => 'Show or hide the next lesson preview';

  @override
  String get persons => 'Persons';

  @override
  String get noPersonsYet =>
      'No persons yet. Add a person to show only the courses you want.';

  @override
  String get addPerson => 'Add Person';

  @override
  String get personName => 'Person\'s name';

  @override
  String get renamePerson => 'Rename person';

  @override
  String get enterPersonName => 'Please enter a name for the person.';

  @override
  String get savePerson => 'Save Person';

  @override
  String get selectPersonClass => 'Select a class for the new person';

  @override
  String coursesFor(String name) {
    return 'Courses for $name';
  }

  @override
  String get sickTrack => 'Sick-Track';

  @override
  String get sickTrackSubtitle =>
      'Track missed lessons and get signatures for them';

  @override
  String get sickTrackAdd => 'Add sick period';

  @override
  String get selectClassOrPerson => 'Select class or person';

  @override
  String get selectClassOrPersonHint =>
      'Choose a saved class or person to track';

  @override
  String get anotherClass => 'Another class';

  @override
  String get selectCourses => 'Select courses';

  @override
  String get selectSickDays => 'Select sick days';

  @override
  String get sickDays => 'Sick days';

  @override
  String get addDay => 'Add day';

  @override
  String get noSickDaysSelected => 'No days selected';

  @override
  String get missedLessons => 'Missed lessons';

  @override
  String get noMissedLessons => 'No missed lessons';

  @override
  String get noSickTrackEntries =>
      'No sick periods yet. Add one to see which lessons you missed.';

  @override
  String get getSignature => 'Get signature';

  @override
  String missedLesson(String date, String count, String course) {
    return '$date · $count. hour · $course';
  }

  @override
  String get markSignatureDone => 'Mark signature as done';

  @override
  String signatureDoneQuestion(String course) {
    return 'Do you want to mark the signature for $course as done?';
  }

  @override
  String get done => 'Done';

  @override
  String get time => 'Time';

  @override
  String get hour => 'Hour';

  @override
  String get fullDay => 'Full day';

  @override
  String get fullDayMessage =>
      'Show all lessons for this day without filtering by time.';

  @override
  String get selectDate => 'Tap to select a date';

  @override
  String get selectTime => 'Tap to select a time';

  @override
  String get lessonTimes => 'Lesson times';

  @override
  String get lessonTimesSubtitle => 'Manually set the times for each lesson';

  @override
  String get defaultPlanModePerson => 'Persons';

  @override
  String get defaultPlanModePersonAuto => 'Auto';

  @override
  String get defaultPlanModePersonAutoSubtitle =>
      'Show today, unless the school day is over';

  @override
  String get defaultPlanModePersonLatest => 'Latest';

  @override
  String get defaultPlanModePersonLatestSubtitle =>
      'Always show the latest available plan';

  @override
  String get defaultPlanModePersonToday => 'Today';

  @override
  String get defaultPlanModePersonTodaySubtitle =>
      'Always show only today\'s plan';

  @override
  String get defaultPlanModeClass => 'Classes';

  @override
  String get defaultPlanModeClassAuto => 'Auto';

  @override
  String get defaultPlanModeClassAutoSubtitle =>
      'Show today, unless the school day is over';

  @override
  String get defaultPlanModeClassLatest => 'Latest';

  @override
  String get defaultPlanModeClassLatestSubtitle =>
      'Always show the latest available plan';

  @override
  String get defaultPlanModeClassToday => 'Today';

  @override
  String get defaultPlanModeClassTodaySubtitle =>
      'Always show only today\'s plan';

  @override
  String get defaultPlanModePreview => 'Preview';

  @override
  String get defaultPlanModePreviewAuto => 'Auto';

  @override
  String get defaultPlanModePreviewAutoSubtitle =>
      'Show today, unless the school day is over';

  @override
  String get defaultPlanModePreviewLatest => 'Latest';

  @override
  String get defaultPlanModePreviewLatestSubtitle =>
      'Always show the latest available plan';

  @override
  String get defaultPlanModePreviewToday => 'Today';

  @override
  String get defaultPlanModePreviewTodaySubtitle =>
      'Always show only today\'s plan';

  @override
  String get defaultPlanModePreviewClass => 'Preview of classes';

  @override
  String get defaultPlanModePreviewClassAuto => 'Auto';

  @override
  String get defaultPlanModePreviewClassAutoSubtitle =>
      'Show today, unless the school day is over';

  @override
  String get defaultPlanModePreviewClassLatest => 'Latest';

  @override
  String get defaultPlanModePreviewClassLatestSubtitle =>
      'Always show the latest available plan';

  @override
  String get defaultPlanModePreviewClassToday => 'Today';

  @override
  String get defaultPlanModePreviewClassTodaySubtitle =>
      'Always show only today\'s plan';

  @override
  String get defaultPlanModePreviewPerson => 'Preview of persons';

  @override
  String get defaultPlanModePreviewPersonAuto => 'Auto';

  @override
  String get defaultPlanModePreviewPersonAutoSubtitle =>
      'Show today, unless the school day is over';

  @override
  String get defaultPlanModePreviewPersonLatest => 'Latest';

  @override
  String get defaultPlanModePreviewPersonLatestSubtitle =>
      'Always show the latest available plan';

  @override
  String get defaultPlanModePreviewPersonToday => 'Today';

  @override
  String get defaultPlanModePreviewPersonTodaySubtitle =>
      'Always show only today\'s plan';

  @override
  String get defaultPlanModePreviewEntryTitle => 'Default plan mode';

  @override
  String get defaultPlanModePreviewEntrySubtitle =>
      'Separately for persons, classes and their previews';

  @override
  String get sync => 'Sync';

  @override
  String get syncSubtitle =>
      'Keep classes, persons and plans in sync across your devices';

  @override
  String get syncShareHub => 'Sync & Share';

  @override
  String get syncShareHubSubtitle =>
      'Keep data in step across your devices and share it with others';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncServerRunning => 'Server is running';

  @override
  String get syncServerStopped => 'Server is stopped';

  @override
  String get syncServerCheck => 'Check server';

  @override
  String get syncNotConfigured => 'No sync server configured';

  @override
  String get syncStart => 'Start sync';

  @override
  String get syncStartSubtitle =>
      'Generates a code of ten words that connects your devices';

  @override
  String get syncJoin => 'Join a sync';

  @override
  String get syncJoinSubtitle =>
      'Enter the ten words of an existing sync on another device';

  @override
  String get syncPassphrase => 'Sync code';

  @override
  String get syncPassphraseHint => 'Ten words, e.g. blue sky river seven';

  @override
  String get syncPassphraseGenerate => 'Generate new code';

  @override
  String get syncPassphraseCopy => 'Copy code';

  @override
  String get syncPassphraseCopied => 'Code copied to the clipboard';

  @override
  String syncPassphraseUnknownWord(Object words) {
    return 'These words are not in the list: $words';
  }

  @override
  String get syncPassphraseTooFewWords => 'Please enter at least three words';

  @override
  String get syncPassphraseEmpty => 'Please enter a code';

  @override
  String get syncSettingsToggle => 'Include settings';

  @override
  String get syncSettingsToggleSubtitle =>
      'When off, settings stay on each device and are not transferred';

  @override
  String get syncSettingsNote =>
      'Classes, persons, courses and plans are always included. The school password is never transferred.';

  @override
  String get syncSettingsNotePlain =>
      'Klassen, Personen, Kurse und Pläne werden immer übertragen. Das Schulpasswort niemals.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncNever => 'Never synced';

  @override
  String syncLastSync(Object when) {
    return 'Last sync: $when';
  }

  @override
  String get syncInProgress => 'Synchronising…';

  @override
  String syncDone(Object changes, Object devices) {
    return 'Sync done. $changes changes from $devices devices.';
  }

  @override
  String get syncDoneNoChanges => 'Sync done. Everything is up to date.';

  @override
  String get syncAutoTitle => 'Automatic sync';

  @override
  String syncAutoOn(Object minutes) {
    return 'Runs by itself: at start, when you return to the app, and then every $minutes minutes.';
  }

  @override
  String syncAutoLast(Object when) {
    return 'Last automatic: $when';
  }

  @override
  String get syncAutoNever => 'Has not run automatically yet.';

  @override
  String syncPeerCount(Object count) {
    return '$count devices in this chain (including this one)';
  }

  @override
  String syncAutoFailing(Object count) {
    return '$count failed attempts in a row – the server is contacted less often until it works again.';
  }

  @override
  String syncPayloadCount(Object count) {
    return '$count entries are being transferred';
  }

  @override
  String get syncPayloadEmpty =>
      'There is nothing to transfer yet. Sync can only bring data once another device has some.';

  @override
  String get syncAloneNote =>
      'This device is alone in the sync. Data is uploaded, but none comes back – that is not a failure.';

  @override
  String get syncDoneAlone =>
      'Sync done. Your data was uploaded, but no other device has joined this sync yet.';

  @override
  String syncFailed(Object reason) {
    return 'Sync failed: $reason';
  }

  @override
  String get syncLeave => 'Leave sync';

  @override
  String get syncLeaveConfirmTitle => 'Leave the sync?';

  @override
  String get syncLeaveConfirm =>
      'Your data stays on this device. It will only stop being kept in sync with the other devices.';

  @override
  String get syncLeaveDone =>
      'You have left the sync. Your data is still on this device.';

  @override
  String get syncLeaveFailed =>
      'The server could not be reached. The sync has been ended on this device anyway.';

  @override
  String get syncDevices => 'Devices in this sync';

  @override
  String get syncDevicesEmpty => 'No other device has joined this sync yet';

  @override
  String get syncDeviceThisOne => 'This device';

  @override
  String get syncDeviceUnknown => 'Unknown device';

  @override
  String get syncDeleteChain => 'Delete sync completely';

  @override
  String get syncDeleteChainConfirmTitle => 'Delete the whole sync?';

  @override
  String get syncDeleteChainConfirm =>
      'The sync code is deleted on the server. Other devices keep their data but can no longer sync.';

  @override
  String get syncDeleteChainDone => 'The sync has been deleted on the server.';

  @override
  String get syncResume => 'Sync again';

  @override
  String get syncResumeSubtitle => 'Continue the sync you left earlier';

  @override
  String get syncRestart => 'Start a new sync';

  @override
  String get syncRestartConfirmTitle => 'Start over?';

  @override
  String get syncRestartConfirm =>
      'This device leaves the current sync. Your data stays. You get a new code.';

  @override
  String get syncErrorNetwork => 'The sync server could not be reached';

  @override
  String get syncErrorTimeout => 'The sync server took too long to answer';

  @override
  String get syncErrorNotFound =>
      'This sync code is unknown – check the words and try again';

  @override
  String get syncErrorWrongPassphrase =>
      'Wrong code – or the data was changed on the way';

  @override
  String get syncErrorForbidden => 'The server rejected this request';

  @override
  String get syncErrorTooManyRequests =>
      'Too many requests. Please try again in a minute';

  @override
  String get syncErrorConflict => 'This sync is full, or too many shares exist';

  @override
  String get syncErrorServerError => 'The sync server has a problem';

  @override
  String get syncErrorTooLarge => 'The data is too large for the server';

  @override
  String get syncErrorInvalidShare => 'This share is not allowed';

  @override
  String get syncErrorForeignApp => 'These data were not created by Substitute';

  @override
  String get syncErrorFutureSchema =>
      'These data come from a newer version of the app';

  @override
  String get share => 'Share';

  @override
  String get shareTitle => 'My shares';

  @override
  String get shareSubtitle =>
      'Share selected classes and persons with other teachers';

  @override
  String get shareCreate => 'New share';

  @override
  String get shareCreateSubtitle => 'Choose what should be visible to others';

  @override
  String get shareEdit => 'Edit share';

  @override
  String get shareEmpty =>
      'No shares yet. Create one to give other teachers your classes and persons.';

  @override
  String get shareUsername => 'My username';

  @override
  String get shareUsernameSubtitle =>
      'Ten words that colleagues enter to open your shares';

  @override
  String get shareUsernameRegenerate => 'New username';

  @override
  String get shareUsernameRegenerateConfirmTitle => 'New username?';

  @override
  String get shareUsernameRegenerateConfirm =>
      'All existing shares move to the new username. Colleagues who saved the old one have to enter the new one.';

  @override
  String get shareDisplayName => 'My display name';

  @override
  String get shareDisplayNameSubtitle =>
      'Shown in the search menu of your school';

  @override
  String get shareLabel => 'Name of the share';

  @override
  String get shareLabelHint => 'e.g. substitution plans autumn';

  @override
  String get shareSearchable => 'Show in the search menu';

  @override
  String get shareSearchableSubtitle =>
      'Colleagues of your school can find you and choose from your shares';

  @override
  String get shareGlobal => 'Global share';

  @override
  String get shareGlobalSubtitle =>
      'Also usable by teachers of other schools, who know your username';

  @override
  String get sharePassword => 'Password';

  @override
  String get sharePasswordSubtitle =>
      'Protects the share – even against people who have the school credentials';

  @override
  String get sharePasswordGenerate => 'Generate password';

  @override
  String get sharePasswordOwn => 'Your own password';

  @override
  String get sharePasswordHint => 'Ten words, e.g. red moon water nine';

  @override
  String get sharePasswordRequired =>
      'This share has a password. Enter it to open.';

  @override
  String get shareSelectWhat => 'What should be shared?';

  @override
  String get shareSelectClasses => 'Classes';

  @override
  String get shareSelectPersons => 'Persons';

  @override
  String get shareSelectEverything => 'Select all';

  @override
  String get shareSelectNothing => 'Select none';

  @override
  String get shareIncludeSettings => 'Include settings';

  @override
  String get shareIncludeSettingsSubtitle => 'Share display settings as well';

  @override
  String get shareIncludePlans => 'Include saved plans';

  @override
  String get shareIncludePlansSubtitle =>
      'Share the substitution plans stored on this device';

  @override
  String get shareIncludeHistory => 'Include plans from the past';

  @override
  String shareIncludeHistorySubtitle(Object days) {
    return 'Otherwise only the last $days days are shared';
  }

  @override
  String get shareSelectNothingSelected =>
      'Please select at least one class or person';

  @override
  String get sharePublished => 'Share created';

  @override
  String get shareUpdated => 'Share updated';

  @override
  String get shareDeleted => 'Share deleted';

  @override
  String get sharePasswordSaved => 'Password saved on this device';

  @override
  String get shareDeleteConfirmTitle => 'Delete this share?';

  @override
  String get shareDeleteConfirm =>
      'Nobody can open it any more. Data already imported by others stay on their devices.';

  @override
  String get shareGlobalNote =>
      'A global share can be opened by teachers of any school who know your username. It does not appear in their search menu.';

  @override
  String get shareBrowse => 'Find shares';

  @override
  String get shareBrowseSubtitle =>
      'See what colleagues of your school have shared';

  @override
  String get shareBrowseEmpty =>
      'Nobody in your school has shared anything yet';

  @override
  String get shareBrowseEmptySubtitle =>
      'As soon as a colleague marks a share as searchable, it appears here.';

  @override
  String get shareBrowseLoginRequired =>
      'Sign in with your school number first';

  @override
  String get shareBrowseLoginRequiredSubtitle =>
      'Shares can only be found within your own school. That is why signing in is required.';

  @override
  String get shareBrowseEnterUsername => 'Enter a username';

  @override
  String get shareBrowseEnterUsernameSubtitle =>
      'Know the ten words of a colleague? Enter them here to open their share directly.';

  @override
  String get shareBrowseGlobalOnly =>
      'This share is global – it can also be opened by teachers of other schools.';

  @override
  String shareOf(Object name) {
    return 'Shares of $name';
  }

  @override
  String get shareContents => 'Contents';

  @override
  String shareContentsClasses(Object count) {
    return '$count classes';
  }

  @override
  String shareContentsPersons(Object count) {
    return '$count persons';
  }

  @override
  String shareContentsPlans(Object count) {
    return '$count plans';
  }

  @override
  String get shareSelectItems => 'What do you want to import?';

  @override
  String get shareImportModeTitle => 'How should it be imported?';

  @override
  String get shareImportMode => 'Import as';

  @override
  String get shareImportModeOriginal => 'Original';

  @override
  String get shareImportModeOriginalSubtitle =>
      'Exactly as shared: classes, persons and courses stay as they are';

  @override
  String get shareImportModePlans => 'Plans';

  @override
  String get shareImportModePlansSubtitle =>
      'Every person becomes a plan with their courses';

  @override
  String get shareImportModePersons => 'Persons';

  @override
  String get shareImportModePersonsSubtitle =>
      'Only the names are taken over as persons';

  @override
  String get shareImport => 'Import';

  @override
  String shareImportDone(
      Object classes, Object name, Object persons, Object plans) {
    return 'Imported from $name: $persons persons, $classes classes, $plans plans';
  }

  @override
  String get shareNothingToImport => 'Nothing selected';

  @override
  String get shareNameBlocked =>
      'This name is not allowed. Please choose another one.';

  @override
  String get shareNameTooShort => 'Please enter at least two characters';

  @override
  String get shareNameTooLong => 'This name is too long';

  @override
  String get shareNameEmpty => 'Please enter a name';

  @override
  String get shareErrorNoUsername => 'No username has been created yet';

  @override
  String get shareErrorNothingSelected => 'Please select what should be shared';

  @override
  String get shareErrorWrongCredentials =>
      'This share could not be opened – wrong code or wrong school number?';

  @override
  String get shareErrorUnreadable => 'These data could not be read';

  @override
  String get shareDemoNoShares => 'Nobody has shared anything yet';

  @override
  String get shareDelete => 'Delete share';
}
