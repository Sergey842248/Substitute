import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @credentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get credentials;

  /// No description provided for @credentialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'stundenplan24 credentials'**
  String get credentialsSubtitle;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications for substitution plan'**
  String get notificationsSubtitle;

  /// No description provided for @setTeacherAbbreviations.
  ///
  /// In en, this message translates to:
  /// **'Set Teacher abbreviations'**
  String get setTeacherAbbreviations;

  /// No description provided for @setTeacherAbbreviationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace teacher abbreviations with Real ones'**
  String get setTeacherAbbreviationsSubtitle;

  /// No description provided for @developerOptions.
  ///
  /// In en, this message translates to:
  /// **'Developer options'**
  String get developerOptions;

  /// No description provided for @developerOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change Settings meant for developers'**
  String get developerOptionsSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change the language of the app'**
  String get languageSubtitle;

  /// No description provided for @freeRoomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Free rooms - {time}'**
  String freeRoomsTitle(Object time);

  /// No description provided for @vplanStudents.
  ///
  /// In en, this message translates to:
  /// **'vplan students'**
  String get vplanStudents;

  /// No description provided for @vplanTeachers.
  ///
  /// In en, this message translates to:
  /// **'vplan teachers'**
  String get vplanTeachers;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'dashboard'**
  String get dashboard;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get appTitle;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// No description provided for @newVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'A new version ({version}) is available. Just download it and open the file to install it.'**
  String newVersionMessage(String version);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @appInfo.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfo;

  /// No description provided for @mainDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Main-Developer: '**
  String get mainDeveloper;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'Sergey842248'**
  String get developerName;

  /// No description provided for @formerDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Former Developer: '**
  String get formerDeveloper;

  /// No description provided for @formerDeveloperName.
  ///
  /// In en, this message translates to:
  /// **'Oskar'**
  String get formerDeveloperName;

  /// No description provided for @openIssue.
  ///
  /// In en, this message translates to:
  /// **'Open Issue'**
  String get openIssue;

  /// No description provided for @github.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get github;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'version: {version}'**
  String version(String version);

  /// No description provided for @findFreeRoom.
  ///
  /// In en, this message translates to:
  /// **'Find free room'**
  String get findFreeRoom;

  /// No description provided for @findFreeRoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find a room which isn\'t occupied for a specific time'**
  String get findFreeRoomSubtitle;

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// No description provided for @analysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get an analysis of the substitution plan'**
  String get analysisSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'More Settings to personalize your experience'**
  String get settingsSubtitle;

  /// No description provided for @addNewClass.
  ///
  /// In en, this message translates to:
  /// **'Add a new class'**
  String get addNewClass;

  /// No description provided for @dontForgetCredentials.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget your credentials!'**
  String get dontForgetCredentials;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @selectClass.
  ///
  /// In en, this message translates to:
  /// **'Select a class'**
  String get selectClass;

  /// No description provided for @noNextLessonFound.
  ///
  /// In en, this message translates to:
  /// **'No next lesson found'**
  String get noNextLessonFound;

  /// No description provided for @nextHour.
  ///
  /// In en, this message translates to:
  /// **'next hour'**
  String get nextHour;

  /// No description provided for @room.
  ///
  /// In en, this message translates to:
  /// **'Room {room}'**
  String room(String room);

  /// No description provided for @classSelection.
  ///
  /// In en, this message translates to:
  /// **'Class selection'**
  String get classSelection;

  /// No description provided for @selectClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Select class'**
  String get selectClassTitle;

  /// No description provided for @usernamePasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Username or password incorrect!'**
  String get usernamePasswordWrong;

  /// No description provided for @wrongSchoolNumber.
  ///
  /// In en, this message translates to:
  /// **'Wrong schoolnumber!\n\nor no substitution plan available!'**
  String get wrongSchoolNumber;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @noSubstitutionPlan.
  ///
  /// In en, this message translates to:
  /// **'no substitution plan'**
  String get noSubstitutionPlan;

  /// No description provided for @wrongSchoolNumberAlt.
  ///
  /// In en, this message translates to:
  /// **'Wrong school-number or no substitution plan available'**
  String get wrongSchoolNumberAlt;

  /// No description provided for @noNetworkConnection.
  ///
  /// In en, this message translates to:
  /// **'No Network connection'**
  String get noNetworkConnection;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @courses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get courses;

  /// No description provided for @noAdditionalInformation.
  ///
  /// In en, this message translates to:
  /// **'No additional information available'**
  String get noAdditionalInformation;

  /// No description provided for @searchTeachers.
  ///
  /// In en, this message translates to:
  /// **'Search Teachers'**
  String get searchTeachers;

  /// No description provided for @teacherAbbreviationHint.
  ///
  /// In en, this message translates to:
  /// **'Teacher abbreviation (like \"AB\")'**
  String get teacherAbbreviationHint;

  /// No description provided for @selectedDate.
  ///
  /// In en, this message translates to:
  /// **'Selected Date: {day}.{month}.{year}'**
  String selectedDate(String day, String month, String year);

  /// No description provided for @see.
  ///
  /// In en, this message translates to:
  /// **'See'**
  String get see;

  /// No description provided for @scanningTeacherAbbreviations.
  ///
  /// In en, this message translates to:
  /// **'Scanning all Teacher abbreviations...'**
  String get scanningTeacherAbbreviations;

  /// No description provided for @noTeachersFound.
  ///
  /// In en, this message translates to:
  /// **'No teachers found'**
  String get noTeachersFound;

  /// No description provided for @noFavoriteClassesFound.
  ///
  /// In en, this message translates to:
  /// **'No favorite classes found.'**
  String get noFavoriteClassesFound;

  /// No description provided for @addClassToFavoritesForAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Please add a class to your favorites to see the analysis.'**
  String get addClassToFavoritesForAnalysis;

  /// No description provided for @nameClass.
  ///
  /// In en, this message translates to:
  /// **'Name the class'**
  String get nameClass;

  /// No description provided for @renameClass.
  ///
  /// In en, this message translates to:
  /// **'Rename class'**
  String get renameClass;

  /// No description provided for @classNameHint.
  ///
  /// In en, this message translates to:
  /// **'Custom name (optional)'**
  String get classNameHint;

  /// No description provided for @couldNotLoadVPlanData.
  ///
  /// In en, this message translates to:
  /// **'Could not load VPlan data.'**
  String get couldNotLoadVPlanData;

  /// No description provided for @noDataForAnalysisAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data for analysis available.'**
  String get noDataForAnalysisAvailable;

  /// No description provided for @teacherLabel.
  ///
  /// In en, this message translates to:
  /// **'Teacher: {name}'**
  String teacherLabel(String name);

  /// No description provided for @lessonDetails.
  ///
  /// In en, this message translates to:
  /// **'{count}. Hour: {lesson} in Room: {place}'**
  String lessonDetails(String count, String lesson, String place);

  /// No description provided for @loadingData.
  ///
  /// In en, this message translates to:
  /// **'Loading data...'**
  String get loadingData;

  /// No description provided for @loadingSubstitutionPlan.
  ///
  /// In en, this message translates to:
  /// **'Loading substitution plan...'**
  String get loadingSubstitutionPlan;

  /// No description provided for @substitutionPlanLoaded.
  ///
  /// In en, this message translates to:
  /// **'Substitution plan loaded'**
  String get substitutionPlanLoaded;

  /// No description provided for @noSubstitutionPlanToday.
  ///
  /// In en, this message translates to:
  /// **'No Substitution plan available for today.'**
  String get noSubstitutionPlanToday;

  /// No description provided for @noSubstitutionPlanTomorrow.
  ///
  /// In en, this message translates to:
  /// **'No Substitution plan available for tomorrow.'**
  String get noSubstitutionPlanTomorrow;

  /// No description provided for @browsingPlan.
  ///
  /// In en, this message translates to:
  /// **'Browsing plan...'**
  String get browsingPlan;

  /// No description provided for @analysingRooms.
  ///
  /// In en, this message translates to:
  /// **'Analysing Rooms...'**
  String get analysingRooms;

  /// No description provided for @checkRoom.
  ///
  /// In en, this message translates to:
  /// **'Check room {room}...'**
  String checkRoom(String room);

  /// No description provided for @lessonsInThisRoom.
  ///
  /// In en, this message translates to:
  /// **'Lessons in this room'**
  String get lessonsInThisRoom;

  /// No description provided for @todayNoLessonsInThisRoom.
  ///
  /// In en, this message translates to:
  /// **'Today no lessons in this room'**
  String get todayNoLessonsInThisRoom;

  /// No description provided for @chooseTimeAndDay.
  ///
  /// In en, this message translates to:
  /// **'Choose time and day'**
  String get chooseTimeAndDay;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @processCanTakeSeconds.
  ///
  /// In en, this message translates to:
  /// **'This process can take a few seconds!'**
  String get processCanTakeSeconds;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'loading...'**
  String get loading;

  /// No description provided for @classesFromTeacher.
  ///
  /// In en, this message translates to:
  /// **'Classes from {teacherName} - {displayDate}'**
  String classesFromTeacher(String teacherName, String displayDate);

  /// No description provided for @settingsCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get settingsCredentials;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsSetTeacherAbbreviations.
  ///
  /// In en, this message translates to:
  /// **'Set Teacher abbreviations'**
  String get settingsSetTeacherAbbreviations;

  /// No description provided for @realName.
  ///
  /// In en, this message translates to:
  /// **'Real name'**
  String get realName;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get saved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @schoolNumber.
  ///
  /// In en, this message translates to:
  /// **'School-number'**
  String get schoolNumber;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @selfHost.
  ///
  /// In en, this message translates to:
  /// **'Your own URL'**
  String get selfHost;

  /// No description provided for @useSelfHost.
  ///
  /// In en, this message translates to:
  /// **'or use your own URL'**
  String get useSelfHost;

  /// No description provided for @useLogin.
  ///
  /// In en, this message translates to:
  /// **'or use official Login'**
  String get useLogin;

  /// No description provided for @shareCreds.
  ///
  /// In en, this message translates to:
  /// **'Share credentials'**
  String get shareCreds;

  /// No description provided for @credsSaved.
  ///
  /// In en, this message translates to:
  /// **'Credentials saved!'**
  String get credsSaved;

  /// No description provided for @loadPlanAuto.
  ///
  /// In en, this message translates to:
  /// **'Load Substitution plan automatically'**
  String get loadPlanAuto;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @smartNotifs.
  ///
  /// In en, this message translates to:
  /// **'Smart notifications'**
  String get smartNotifs;

  /// No description provided for @prefClasses.
  ///
  /// In en, this message translates to:
  /// **'Preferred classes'**
  String get prefClasses;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @callInterv.
  ///
  /// In en, this message translates to:
  /// **'Call interval'**
  String get callInterv;

  /// No description provided for @interv.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interv;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @onlyRemOnChange.
  ///
  /// In en, this message translates to:
  /// **'Only remind when lesson changes'**
  String get onlyRemOnChange;

  /// No description provided for @shareTeacherName.
  ///
  /// In en, this message translates to:
  /// **'Share teacher name'**
  String get shareTeacherName;

  /// No description provided for @showLessonTimes.
  ///
  /// In en, this message translates to:
  /// **'Show lesson times'**
  String get showLessonTimes;

  /// No description provided for @showLessonTimesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show times of individual lessons in the substitution plan'**
  String get showLessonTimesSubtitle;

  /// No description provided for @hideLessonTimes.
  ///
  /// In en, this message translates to:
  /// **'Hide lesson times'**
  String get hideLessonTimes;

  /// No description provided for @hideLessonTimesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide times for individual lessons in the plan'**
  String get hideLessonTimesSubtitle;

  /// No description provided for @planSettings.
  ///
  /// In en, this message translates to:
  /// **'Plan Settings'**
  String get planSettings;

  /// No description provided for @planSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Settings for the substitution plan'**
  String get planSettingsSubtitle;

  /// No description provided for @hideTeacher.
  ///
  /// In en, this message translates to:
  /// **'Hide Teacher'**
  String get hideTeacher;

  /// No description provided for @hideTeacherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide teacher names in the substitution plan'**
  String get hideTeacherSubtitle;

  /// No description provided for @hidePersons.
  ///
  /// In en, this message translates to:
  /// **'Hide Persons'**
  String get hidePersons;

  /// No description provided for @hidePersonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the persons section'**
  String get hidePersonsSubtitle;

  /// No description provided for @persons.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get persons;

  /// No description provided for @noPersonsYet.
  ///
  /// In en, this message translates to:
  /// **'No persons yet. Add a person to show only the courses you want.'**
  String get noPersonsYet;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add Person'**
  String get addPerson;

  /// No description provided for @personName.
  ///
  /// In en, this message translates to:
  /// **'Person\'s name'**
  String get personName;

  /// No description provided for @enterPersonName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name for the person.'**
  String get enterPersonName;

  /// No description provided for @savePerson.
  ///
  /// In en, this message translates to:
  /// **'Save Person'**
  String get savePerson;

  /// No description provided for @selectPersonClass.
  ///
  /// In en, this message translates to:
  /// **'Select a class for the new person'**
  String get selectPersonClass;

  /// No description provided for @coursesFor.
  ///
  /// In en, this message translates to:
  /// **'Courses for {name}'**
  String coursesFor(String name);

  /// No description provided for @sickTrack.
  ///
  /// In en, this message translates to:
  /// **'Sick-Track'**
  String get sickTrack;

  /// No description provided for @sickTrackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track missed lessons and get signatures for them'**
  String get sickTrackSubtitle;

  /// No description provided for @sickTrackAdd.
  ///
  /// In en, this message translates to:
  /// **'Add sick period'**
  String get sickTrackAdd;

  /// No description provided for @selectClassOrPerson.
  ///
  /// In en, this message translates to:
  /// **'Select class or person'**
  String get selectClassOrPerson;

  /// No description provided for @selectClassOrPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved class or person to track'**
  String get selectClassOrPersonHint;

  /// No description provided for @anotherClass.
  ///
  /// In en, this message translates to:
  /// **'Another class'**
  String get anotherClass;

  /// No description provided for @selectCourses.
  ///
  /// In en, this message translates to:
  /// **'Select courses'**
  String get selectCourses;

  /// No description provided for @selectSickDays.
  ///
  /// In en, this message translates to:
  /// **'Select sick days'**
  String get selectSickDays;

  /// No description provided for @sickDays.
  ///
  /// In en, this message translates to:
  /// **'Sick days'**
  String get sickDays;

  /// No description provided for @addDay.
  ///
  /// In en, this message translates to:
  /// **'Add day'**
  String get addDay;

  /// No description provided for @noSickDaysSelected.
  ///
  /// In en, this message translates to:
  /// **'No days selected'**
  String get noSickDaysSelected;

  /// No description provided for @missedLessons.
  ///
  /// In en, this message translates to:
  /// **'Missed lessons'**
  String get missedLessons;

  /// No description provided for @noMissedLessons.
  ///
  /// In en, this message translates to:
  /// **'No missed lessons'**
  String get noMissedLessons;

  /// No description provided for @noSickTrackEntries.
  ///
  /// In en, this message translates to:
  /// **'No sick periods yet. Add one to see which lessons you missed.'**
  String get noSickTrackEntries;

  /// No description provided for @getSignature.
  ///
  /// In en, this message translates to:
  /// **'Get signature'**
  String get getSignature;

  /// No description provided for @missedLesson.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count}. hour · {course}'**
  String missedLesson(String date, String count, String course);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
