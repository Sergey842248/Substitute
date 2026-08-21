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
  String get persons => 'Persons';

  @override
  String get noPersonsYet =>
      'No persons yet. Add a person to show only the courses you want.';

  @override
  String get addPerson => 'Add Person';

  @override
  String get personName => 'Person\'s name';

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
}
