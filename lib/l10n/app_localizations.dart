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

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light or dark, and what the navigation bar shows'**
  String get appearanceSubtitle;

  /// No description provided for @appearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// No description provided for @appearanceThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dark is the default. Light is easier on the eyes in daylight.'**
  String get appearanceThemeSubtitle;

  /// No description provided for @appearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceThemeDark;

  /// No description provided for @appearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceThemeLight;

  /// No description provided for @appearanceShowSyncTab.
  ///
  /// In en, this message translates to:
  /// **'Show sync menu in the bar'**
  String get appearanceShowSyncTab;

  /// No description provided for @appearanceShowSyncTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off it stays reachable – switch it back on under Settings → Appearance.'**
  String get appearanceShowSyncTabSubtitle;

  /// No description provided for @appearanceNavBar.
  ///
  /// In en, this message translates to:
  /// **'Navigation bar'**
  String get appearanceNavBar;

  /// No description provided for @appearanceNavBarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which entries sit at the bottom'**
  String get appearanceNavBarSubtitle;

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

  /// No description provided for @roomPlan.
  ///
  /// In en, this message translates to:
  /// **'Room plan'**
  String get roomPlan;

  /// No description provided for @roomPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the schedule of a room'**
  String get roomPlanSubtitle;

  /// No description provided for @selectRoom.
  ///
  /// In en, this message translates to:
  /// **'Select room'**
  String get selectRoom;

  /// No description provided for @noLessonsInRoom.
  ///
  /// In en, this message translates to:
  /// **'No lessons in this room'**
  String get noLessonsInRoom;

  /// No description provided for @noPlanForThisDay.
  ///
  /// In en, this message translates to:
  /// **'No substitution plan available for this day.'**
  String get noPlanForThisDay;

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

  /// No description provided for @weekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get weekend;

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

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchTeachers.
  ///
  /// In en, this message translates to:
  /// **'Search Teachers'**
  String get searchTeachers;

  /// No description provided for @searchTeachersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search teacher abbreviations and view a teacher\'s substitution plan'**
  String get searchTeachersSubtitle;

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

  /// No description provided for @deleteClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete class?'**
  String get deleteClassTitle;

  /// No description provided for @deleteClassMessage.
  ///
  /// In en, this message translates to:
  /// **'The class \"{className}\" will be removed. This cannot be undone.'**
  String deleteClassMessage(String className);

  /// No description provided for @deletePersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete person?'**
  String get deletePersonTitle;

  /// No description provided for @deletePersonMessage.
  ///
  /// In en, this message translates to:
  /// **'The person \"{personName}\" will be removed. This cannot be undone.'**
  String deletePersonMessage(String personName);

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deleteSickEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get deleteSickEntryTitle;

  /// No description provided for @deleteSickEntryMessage.
  ///
  /// In en, this message translates to:
  /// **'The sick track entry for \"{classId}\" will be removed. This cannot be undone.'**
  String deleteSickEntryMessage(String classId);

  /// No description provided for @deleteLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete lesson time?'**
  String get deleteLessonTitle;

  /// No description provided for @deleteLessonMessage.
  ///
  /// In en, this message translates to:
  /// **'The {count}. lesson time will be removed. This cannot be undone.'**
  String deleteLessonMessage(int count);

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

  /// No description provided for @hidePreviewClasses.
  ///
  /// In en, this message translates to:
  /// **'Hide preview for classes'**
  String get hidePreviewClasses;

  /// No description provided for @hidePreviewClassesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the next lesson preview below the classes'**
  String get hidePreviewClassesSubtitle;

  /// No description provided for @hidePreviewPersons.
  ///
  /// In en, this message translates to:
  /// **'Hide preview for persons'**
  String get hidePreviewPersons;

  /// No description provided for @hidePreviewPersonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the next lesson preview below the persons'**
  String get hidePreviewPersonsSubtitle;

  /// No description provided for @hidePreview.
  ///
  /// In en, this message translates to:
  /// **'Hide preview'**
  String get hidePreview;

  /// No description provided for @showPreview.
  ///
  /// In en, this message translates to:
  /// **'Show preview'**
  String get showPreview;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backup;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export and import settings, classes, persons and cached substitution plans'**
  String get backupSubtitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get backupExport;

  /// No description provided for @backupExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share or save all settings as a file'**
  String get backupExportSubtitle;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get backupImport;

  /// No description provided for @backupImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read a previously exported file'**
  String get backupImportSubtitle;

  /// No description provided for @backupImportRestore.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get backupImportRestore;

  /// No description provided for @backupImportNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'Imported – the file did not contain any credentials.'**
  String get backupImportNoCredentials;

  /// No description provided for @backupExportSubject.
  ///
  /// In en, this message translates to:
  /// **'Substitute configuration'**
  String get backupExportSubject;

  /// No description provided for @backupExportText.
  ///
  /// In en, this message translates to:
  /// **'Substitute configuration (settings, classes, persons, credentials). It contains your password in plain text – please share it carefully.'**
  String get backupExportText;

  /// No description provided for @backupNote.
  ///
  /// In en, this message translates to:
  /// **'Settings, classes, persons, courses, room data and credentials are backed up. Only cached plans are left out. Note: the file contains your password in plain text. After importing, restarting the app is recommended.'**
  String get backupNote;

  /// No description provided for @backupCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contains credentials'**
  String get backupCredentialsTitle;

  /// No description provided for @backupCredentialsWarning.
  ///
  /// In en, this message translates to:
  /// **'The exported file contains your password in plain text. Only share it with people you trust – or share it without credentials.'**
  String get backupCredentialsWarning;

  /// No description provided for @backupCredentialsContinue.
  ///
  /// In en, this message translates to:
  /// **'With credentials'**
  String get backupCredentialsContinue;

  /// No description provided for @backupShareWithoutCredentials.
  ///
  /// In en, this message translates to:
  /// **'Share without credentials'**
  String get backupShareWithoutCredentials;

  /// No description provided for @backupExportTextWithoutCredentials.
  ///
  /// In en, this message translates to:
  /// **'Substitute configuration (settings, classes, persons) – without credentials.'**
  String get backupExportTextWithoutCredentials;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get backupImportTitle;

  /// No description provided for @backupImportQuestion.
  ///
  /// In en, this message translates to:
  /// **'Should the existing settings be replaced?'**
  String get backupImportQuestion;

  /// No description provided for @backupImportMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get backupImportMerge;

  /// No description provided for @backupImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get backupImportReplace;

  /// No description provided for @backupImportDone.
  ///
  /// In en, this message translates to:
  /// **'Import done: {applied} settings applied, {removed} removed.'**
  String backupImportDone(int applied, int removed);

  /// No description provided for @backupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read.'**
  String get backupImportFailed;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed.'**
  String get backupFailed;

  /// No description provided for @backupErrorForeign.
  ///
  /// In en, this message translates to:
  /// **'This file was not created by this app.'**
  String get backupErrorForeign;

  /// No description provided for @backupErrorFutureSchema.
  ///
  /// In en, this message translates to:
  /// **'The file was created by a newer version of the app.'**
  String get backupErrorFutureSchema;

  /// No description provided for @weekdayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// No description provided for @previewSettings.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewSettings;

  /// No description provided for @previewSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the next lesson preview'**
  String get previewSettingsSubtitle;

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

  /// No description provided for @renamePerson.
  ///
  /// In en, this message translates to:
  /// **'Rename person'**
  String get renamePerson;

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

  /// No description provided for @markSignatureDone.
  ///
  /// In en, this message translates to:
  /// **'Mark signature as done'**
  String get markSignatureDone;

  /// No description provided for @signatureDoneQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to mark the signature for {course} as done?'**
  String signatureDoneQuestion(String course);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get hour;

  /// No description provided for @fullDay.
  ///
  /// In en, this message translates to:
  /// **'Full day'**
  String get fullDay;

  /// No description provided for @fullDayMessage.
  ///
  /// In en, this message translates to:
  /// **'Show all lessons for this day without filtering by time.'**
  String get fullDayMessage;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a time'**
  String get selectTime;

  /// No description provided for @lessonTimes.
  ///
  /// In en, this message translates to:
  /// **'Lesson times'**
  String get lessonTimes;

  /// No description provided for @lessonTimesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually set the times for each lesson'**
  String get lessonTimesSubtitle;

  /// No description provided for @defaultPlanModePerson.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get defaultPlanModePerson;

  /// No description provided for @defaultPlanModePersonAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get defaultPlanModePersonAuto;

  /// No description provided for @defaultPlanModePersonAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show today, unless the school day is over'**
  String get defaultPlanModePersonAutoSubtitle;

  /// No description provided for @defaultPlanModePersonLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get defaultPlanModePersonLatest;

  /// No description provided for @defaultPlanModePersonLatestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show the latest available plan'**
  String get defaultPlanModePersonLatestSubtitle;

  /// No description provided for @defaultPlanModePersonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get defaultPlanModePersonToday;

  /// No description provided for @defaultPlanModePersonTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show only today\'s plan'**
  String get defaultPlanModePersonTodaySubtitle;

  /// No description provided for @defaultPlanModeClass.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get defaultPlanModeClass;

  /// No description provided for @defaultPlanModeClassAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get defaultPlanModeClassAuto;

  /// No description provided for @defaultPlanModeClassAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show today, unless the school day is over'**
  String get defaultPlanModeClassAutoSubtitle;

  /// No description provided for @defaultPlanModeClassLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get defaultPlanModeClassLatest;

  /// No description provided for @defaultPlanModeClassLatestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show the latest available plan'**
  String get defaultPlanModeClassLatestSubtitle;

  /// No description provided for @defaultPlanModeClassToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get defaultPlanModeClassToday;

  /// No description provided for @defaultPlanModeClassTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show only today\'s plan'**
  String get defaultPlanModeClassTodaySubtitle;

  /// No description provided for @defaultPlanModePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get defaultPlanModePreview;

  /// No description provided for @defaultPlanModePreviewAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get defaultPlanModePreviewAuto;

  /// No description provided for @defaultPlanModePreviewAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show today, unless the school day is over'**
  String get defaultPlanModePreviewAutoSubtitle;

  /// No description provided for @defaultPlanModePreviewLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get defaultPlanModePreviewLatest;

  /// No description provided for @defaultPlanModePreviewLatestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show the latest available plan'**
  String get defaultPlanModePreviewLatestSubtitle;

  /// No description provided for @defaultPlanModePreviewToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get defaultPlanModePreviewToday;

  /// No description provided for @defaultPlanModePreviewTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show only today\'s plan'**
  String get defaultPlanModePreviewTodaySubtitle;

  /// No description provided for @defaultPlanModePreviewClass.
  ///
  /// In en, this message translates to:
  /// **'Preview of classes'**
  String get defaultPlanModePreviewClass;

  /// No description provided for @defaultPlanModePreviewClassAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get defaultPlanModePreviewClassAuto;

  /// No description provided for @defaultPlanModePreviewClassAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show today, unless the school day is over'**
  String get defaultPlanModePreviewClassAutoSubtitle;

  /// No description provided for @defaultPlanModePreviewClassLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get defaultPlanModePreviewClassLatest;

  /// No description provided for @defaultPlanModePreviewClassLatestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show the latest available plan'**
  String get defaultPlanModePreviewClassLatestSubtitle;

  /// No description provided for @defaultPlanModePreviewClassToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get defaultPlanModePreviewClassToday;

  /// No description provided for @defaultPlanModePreviewClassTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show only today\'s plan'**
  String get defaultPlanModePreviewClassTodaySubtitle;

  /// No description provided for @defaultPlanModePreviewPerson.
  ///
  /// In en, this message translates to:
  /// **'Preview of persons'**
  String get defaultPlanModePreviewPerson;

  /// No description provided for @defaultPlanModePreviewPersonAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get defaultPlanModePreviewPersonAuto;

  /// No description provided for @defaultPlanModePreviewPersonAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show today, unless the school day is over'**
  String get defaultPlanModePreviewPersonAutoSubtitle;

  /// No description provided for @defaultPlanModePreviewPersonLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get defaultPlanModePreviewPersonLatest;

  /// No description provided for @defaultPlanModePreviewPersonLatestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show the latest available plan'**
  String get defaultPlanModePreviewPersonLatestSubtitle;

  /// No description provided for @defaultPlanModePreviewPersonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get defaultPlanModePreviewPersonToday;

  /// No description provided for @defaultPlanModePreviewPersonTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always show only today\'s plan'**
  String get defaultPlanModePreviewPersonTodaySubtitle;

  /// No description provided for @defaultPlanModePreviewEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Default plan mode'**
  String get defaultPlanModePreviewEntryTitle;

  /// No description provided for @defaultPlanModePreviewEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Separately for persons, classes and their previews'**
  String get defaultPlanModePreviewEntrySubtitle;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep classes, persons and plans in sync across your devices'**
  String get syncSubtitle;

  /// No description provided for @syncShareHub.
  ///
  /// In en, this message translates to:
  /// **'Sync & Share'**
  String get syncShareHub;

  /// No description provided for @syncShareHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep data in step across your devices and share it with others'**
  String get syncShareHubSubtitle;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncServerRunning.
  ///
  /// In en, this message translates to:
  /// **'Server is running'**
  String get syncServerRunning;

  /// No description provided for @syncServerStopped.
  ///
  /// In en, this message translates to:
  /// **'Server is stopped'**
  String get syncServerStopped;

  /// No description provided for @syncServerCheck.
  ///
  /// In en, this message translates to:
  /// **'Check server'**
  String get syncServerCheck;

  /// No description provided for @syncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No sync server configured'**
  String get syncNotConfigured;

  /// No description provided for @syncStart.
  ///
  /// In en, this message translates to:
  /// **'Start sync'**
  String get syncStart;

  /// No description provided for @syncStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generates a code of ten words that connects your devices'**
  String get syncStartSubtitle;

  /// No description provided for @syncJoin.
  ///
  /// In en, this message translates to:
  /// **'Join a sync'**
  String get syncJoin;

  /// No description provided for @syncJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the ten words of an existing sync on another device'**
  String get syncJoinSubtitle;

  /// No description provided for @syncPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Sync code'**
  String get syncPassphrase;

  /// No description provided for @syncPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Ten words, e.g. blue sky river seven'**
  String get syncPassphraseHint;

  /// No description provided for @syncPassphraseGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate new code'**
  String get syncPassphraseGenerate;

  /// No description provided for @syncPassphraseCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get syncPassphraseCopy;

  /// No description provided for @syncPassphraseCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to the clipboard'**
  String get syncPassphraseCopied;

  /// No description provided for @syncPassphraseUnknownWord.
  ///
  /// In en, this message translates to:
  /// **'These words are not in the list: {words}'**
  String syncPassphraseUnknownWord(Object words);

  /// No description provided for @syncPassphraseTooFewWords.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least three words'**
  String get syncPassphraseTooFewWords;

  /// No description provided for @syncPassphraseEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a code'**
  String get syncPassphraseEmpty;

  /// No description provided for @syncSettingsToggle.
  ///
  /// In en, this message translates to:
  /// **'Include settings'**
  String get syncSettingsToggle;

  /// No description provided for @syncSettingsToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, settings stay on each device and are not transferred'**
  String get syncSettingsToggleSubtitle;

  /// No description provided for @syncSettingsNote.
  ///
  /// In en, this message translates to:
  /// **'Classes, persons, courses and plans are always included. The school password is never transferred.'**
  String get syncSettingsNote;

  /// No description provided for @syncSettingsNotePlain.
  ///
  /// In en, this message translates to:
  /// **'Klassen, Personen, Kurse und Pläne werden immer übertragen. Das Schulpasswort niemals.'**
  String get syncSettingsNotePlain;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get syncNever;

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {when}'**
  String syncLastSync(Object when);

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Synchronising…'**
  String get syncInProgress;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Sync done. {changes} changes from {devices} devices.'**
  String syncDone(Object changes, Object devices);

  /// No description provided for @syncDoneNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Sync done. Everything is up to date.'**
  String get syncDoneNoChanges;

  /// No description provided for @syncAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync'**
  String get syncAutoTitle;

  /// No description provided for @syncAutoOn.
  ///
  /// In en, this message translates to:
  /// **'Runs by itself: at start, when you return to the app, and then every {minutes} minutes.'**
  String syncAutoOn(Object minutes);

  /// No description provided for @syncAutoLast.
  ///
  /// In en, this message translates to:
  /// **'Last automatic: {when}'**
  String syncAutoLast(Object when);

  /// No description provided for @syncAutoNever.
  ///
  /// In en, this message translates to:
  /// **'Has not run automatically yet.'**
  String get syncAutoNever;

  /// No description provided for @syncPeerCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices in this chain (including this one)'**
  String syncPeerCount(Object count);

  /// No description provided for @syncAutoFailing.
  ///
  /// In en, this message translates to:
  /// **'{count} failed attempts in a row – the server is contacted less often until it works again.'**
  String syncAutoFailing(Object count);

  /// No description provided for @syncPayloadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries are being transferred'**
  String syncPayloadCount(Object count);

  /// No description provided for @syncPayloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to transfer yet. Sync can only bring data once another device has some.'**
  String get syncPayloadEmpty;

  /// No description provided for @syncAloneNote.
  ///
  /// In en, this message translates to:
  /// **'This device is alone in the sync. Data is uploaded, but none comes back – that is not a failure.'**
  String get syncAloneNote;

  /// No description provided for @syncDoneAlone.
  ///
  /// In en, this message translates to:
  /// **'Sync done. Your data was uploaded, but no other device has joined this sync yet.'**
  String get syncDoneAlone;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {reason}'**
  String syncFailed(Object reason);

  /// No description provided for @syncLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave sync'**
  String get syncLeave;

  /// No description provided for @syncLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the sync?'**
  String get syncLeaveConfirmTitle;

  /// No description provided for @syncLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device. It will only stop being kept in sync with the other devices.'**
  String get syncLeaveConfirm;

  /// No description provided for @syncLeaveDone.
  ///
  /// In en, this message translates to:
  /// **'You have left the sync. Your data is still on this device.'**
  String get syncLeaveDone;

  /// No description provided for @syncLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached. The sync has been ended on this device anyway.'**
  String get syncLeaveFailed;

  /// No description provided for @syncDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices in this sync'**
  String get syncDevices;

  /// No description provided for @syncDevicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other device has joined this sync yet'**
  String get syncDevicesEmpty;

  /// No description provided for @syncDeviceThisOne.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncDeviceThisOne;

  /// No description provided for @syncDeviceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get syncDeviceUnknown;

  /// No description provided for @syncDeleteChain.
  ///
  /// In en, this message translates to:
  /// **'Delete sync completely'**
  String get syncDeleteChain;

  /// No description provided for @syncDeleteChainConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the whole sync?'**
  String get syncDeleteChainConfirmTitle;

  /// No description provided for @syncDeleteChainConfirm.
  ///
  /// In en, this message translates to:
  /// **'The sync code is deleted on the server. Other devices keep their data but can no longer sync.'**
  String get syncDeleteChainConfirm;

  /// No description provided for @syncDeleteChainDone.
  ///
  /// In en, this message translates to:
  /// **'The sync has been deleted on the server.'**
  String get syncDeleteChainDone;

  /// No description provided for @syncResume.
  ///
  /// In en, this message translates to:
  /// **'Sync again'**
  String get syncResume;

  /// No description provided for @syncResumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue the sync you left earlier'**
  String get syncResumeSubtitle;

  /// No description provided for @syncRestart.
  ///
  /// In en, this message translates to:
  /// **'Start a new sync'**
  String get syncRestart;

  /// No description provided for @syncRestartConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get syncRestartConfirmTitle;

  /// No description provided for @syncRestartConfirm.
  ///
  /// In en, this message translates to:
  /// **'This device leaves the current sync. Your data stays. You get a new code.'**
  String get syncRestartConfirm;

  /// No description provided for @syncErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'The sync server could not be reached'**
  String get syncErrorNetwork;

  /// No description provided for @syncErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The sync server took too long to answer'**
  String get syncErrorTimeout;

  /// No description provided for @syncErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This sync code is unknown – check the words and try again'**
  String get syncErrorNotFound;

  /// No description provided for @syncErrorWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong code – or the data was changed on the way'**
  String get syncErrorWrongPassphrase;

  /// No description provided for @syncErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this request'**
  String get syncErrorForbidden;

  /// No description provided for @syncErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again in a minute'**
  String get syncErrorTooManyRequests;

  /// No description provided for @syncErrorConflict.
  ///
  /// In en, this message translates to:
  /// **'This sync is full, or too many shares exist'**
  String get syncErrorConflict;

  /// No description provided for @syncErrorServerError.
  ///
  /// In en, this message translates to:
  /// **'The sync server has a problem'**
  String get syncErrorServerError;

  /// No description provided for @syncErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The data is too large for the server'**
  String get syncErrorTooLarge;

  /// No description provided for @syncErrorInvalidShare.
  ///
  /// In en, this message translates to:
  /// **'This share is not allowed'**
  String get syncErrorInvalidShare;

  /// No description provided for @syncErrorForeignApp.
  ///
  /// In en, this message translates to:
  /// **'These data were not created by Substitute'**
  String get syncErrorForeignApp;

  /// No description provided for @syncErrorFutureSchema.
  ///
  /// In en, this message translates to:
  /// **'These data come from a newer version of the app'**
  String get syncErrorFutureSchema;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'My shares'**
  String get shareTitle;

  /// No description provided for @shareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share selected classes and persons with other teachers'**
  String get shareSubtitle;

  /// No description provided for @shareCreate.
  ///
  /// In en, this message translates to:
  /// **'New share'**
  String get shareCreate;

  /// No description provided for @shareCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what should be visible to others'**
  String get shareCreateSubtitle;

  /// No description provided for @shareEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit share'**
  String get shareEdit;

  /// No description provided for @shareEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shares yet. Create one to give other teachers your classes and persons.'**
  String get shareEmpty;

  /// No description provided for @shareUsername.
  ///
  /// In en, this message translates to:
  /// **'My username'**
  String get shareUsername;

  /// No description provided for @shareUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ten words that colleagues enter to open your shares'**
  String get shareUsernameSubtitle;

  /// No description provided for @shareUsernameRegenerate.
  ///
  /// In en, this message translates to:
  /// **'New username'**
  String get shareUsernameRegenerate;

  /// No description provided for @shareUsernameRegenerateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'New username?'**
  String get shareUsernameRegenerateConfirmTitle;

  /// No description provided for @shareUsernameRegenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'All existing shares move to the new username. Colleagues who saved the old one have to enter the new one.'**
  String get shareUsernameRegenerateConfirm;

  /// No description provided for @shareDisplayName.
  ///
  /// In en, this message translates to:
  /// **'My display name'**
  String get shareDisplayName;

  /// No description provided for @shareDisplayNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown in the search menu of your school'**
  String get shareDisplayNameSubtitle;

  /// No description provided for @shareLabel.
  ///
  /// In en, this message translates to:
  /// **'Name of the share'**
  String get shareLabel;

  /// No description provided for @shareLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. substitution plans autumn'**
  String get shareLabelHint;

  /// No description provided for @shareSearchable.
  ///
  /// In en, this message translates to:
  /// **'Show in the search menu'**
  String get shareSearchable;

  /// No description provided for @shareSearchableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Colleagues of your school can find you and choose from your shares'**
  String get shareSearchableSubtitle;

  /// No description provided for @shareGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global share'**
  String get shareGlobal;

  /// No description provided for @shareGlobalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Also usable by teachers of other schools, who know your username'**
  String get shareGlobalSubtitle;

  /// No description provided for @sharePassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get sharePassword;

  /// No description provided for @sharePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protects the share – even against people who have the school credentials'**
  String get sharePasswordSubtitle;

  /// No description provided for @sharePasswordGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate password'**
  String get sharePasswordGenerate;

  /// No description provided for @sharePasswordOwn.
  ///
  /// In en, this message translates to:
  /// **'Your own password'**
  String get sharePasswordOwn;

  /// No description provided for @sharePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Ten words, e.g. red moon water nine'**
  String get sharePasswordHint;

  /// No description provided for @sharePasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'This share has a password. Enter it to open.'**
  String get sharePasswordRequired;

  /// No description provided for @shareSelectWhat.
  ///
  /// In en, this message translates to:
  /// **'What should be shared?'**
  String get shareSelectWhat;

  /// No description provided for @shareSelectClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get shareSelectClasses;

  /// No description provided for @shareSelectPersons.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get shareSelectPersons;

  /// No description provided for @shareSelectEverything.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get shareSelectEverything;

  /// No description provided for @shareSelectNothing.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get shareSelectNothing;

  /// No description provided for @shareIncludeSettings.
  ///
  /// In en, this message translates to:
  /// **'Include settings'**
  String get shareIncludeSettings;

  /// No description provided for @shareIncludeSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share display settings as well'**
  String get shareIncludeSettingsSubtitle;

  /// No description provided for @shareIncludePlans.
  ///
  /// In en, this message translates to:
  /// **'Include saved plans'**
  String get shareIncludePlans;

  /// No description provided for @shareIncludePlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the substitution plans stored on this device'**
  String get shareIncludePlansSubtitle;

  /// No description provided for @shareIncludeHistory.
  ///
  /// In en, this message translates to:
  /// **'Include plans from the past'**
  String get shareIncludeHistory;

  /// No description provided for @shareIncludeHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Otherwise only the last {days} days are shared'**
  String shareIncludeHistorySubtitle(Object days);

  /// No description provided for @shareSelectNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one class or person'**
  String get shareSelectNothingSelected;

  /// No description provided for @sharePublished.
  ///
  /// In en, this message translates to:
  /// **'Share created'**
  String get sharePublished;

  /// No description provided for @shareUpdated.
  ///
  /// In en, this message translates to:
  /// **'Share updated'**
  String get shareUpdated;

  /// No description provided for @shareDeleted.
  ///
  /// In en, this message translates to:
  /// **'Share deleted'**
  String get shareDeleted;

  /// No description provided for @sharePasswordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password saved on this device'**
  String get sharePasswordSaved;

  /// No description provided for @shareDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this share?'**
  String get shareDeleteConfirmTitle;

  /// No description provided for @shareDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Nobody can open it any more. Data already imported by others stay on their devices.'**
  String get shareDeleteConfirm;

  /// No description provided for @shareGlobalNote.
  ///
  /// In en, this message translates to:
  /// **'A global share can be opened by teachers of any school who know your username. It does not appear in their search menu.'**
  String get shareGlobalNote;

  /// No description provided for @shareBrowse.
  ///
  /// In en, this message translates to:
  /// **'Find shares'**
  String get shareBrowse;

  /// No description provided for @shareBrowseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what colleagues of your school have shared'**
  String get shareBrowseSubtitle;

  /// No description provided for @shareBrowseEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody in your school has shared anything yet'**
  String get shareBrowseEmpty;

  /// No description provided for @shareBrowseEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'As soon as a colleague marks a share as searchable, it appears here.'**
  String get shareBrowseEmptySubtitle;

  /// No description provided for @shareBrowseLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your school number first'**
  String get shareBrowseLoginRequired;

  /// No description provided for @shareBrowseLoginRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shares can only be found within your own school. That is why signing in is required.'**
  String get shareBrowseLoginRequiredSubtitle;

  /// No description provided for @shareBrowseEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get shareBrowseEnterUsername;

  /// No description provided for @shareBrowseEnterUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Know the ten words of a colleague? Enter them here to open their share directly.'**
  String get shareBrowseEnterUsernameSubtitle;

  /// No description provided for @shareBrowseGlobalOnly.
  ///
  /// In en, this message translates to:
  /// **'This share is global – it can also be opened by teachers of other schools.'**
  String get shareBrowseGlobalOnly;

  /// No description provided for @shareOf.
  ///
  /// In en, this message translates to:
  /// **'Shares of {name}'**
  String shareOf(Object name);

  /// No description provided for @shareContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get shareContents;

  /// No description provided for @shareContentsClasses.
  ///
  /// In en, this message translates to:
  /// **'{count} classes'**
  String shareContentsClasses(Object count);

  /// No description provided for @shareContentsPersons.
  ///
  /// In en, this message translates to:
  /// **'{count} persons'**
  String shareContentsPersons(Object count);

  /// No description provided for @shareContentsPlans.
  ///
  /// In en, this message translates to:
  /// **'{count} plans'**
  String shareContentsPlans(Object count);

  /// No description provided for @shareSelectItems.
  ///
  /// In en, this message translates to:
  /// **'What do you want to import?'**
  String get shareSelectItems;

  /// No description provided for @shareImportModeTitle.
  ///
  /// In en, this message translates to:
  /// **'How should it be imported?'**
  String get shareImportModeTitle;

  /// No description provided for @shareImportMode.
  ///
  /// In en, this message translates to:
  /// **'Import as'**
  String get shareImportMode;

  /// No description provided for @shareImportModeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get shareImportModeOriginal;

  /// No description provided for @shareImportModeOriginalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exactly as shared: classes, persons and courses stay as they are'**
  String get shareImportModeOriginalSubtitle;

  /// No description provided for @shareImportModePlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get shareImportModePlans;

  /// No description provided for @shareImportModePlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every person becomes a plan with their courses'**
  String get shareImportModePlansSubtitle;

  /// No description provided for @shareImportModePersons.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get shareImportModePersons;

  /// No description provided for @shareImportModePersonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only the names are taken over as persons'**
  String get shareImportModePersonsSubtitle;

  /// No description provided for @shareImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get shareImport;

  /// No description provided for @shareImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported from {name}: {persons} persons, {classes} classes, {plans} plans'**
  String shareImportDone(
      Object classes, Object name, Object persons, Object plans);

  /// No description provided for @shareNothingToImport.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get shareNothingToImport;

  /// No description provided for @shareNameBlocked.
  ///
  /// In en, this message translates to:
  /// **'This name is not allowed. Please choose another one.'**
  String get shareNameBlocked;

  /// No description provided for @shareNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least two characters'**
  String get shareNameTooShort;

  /// No description provided for @shareNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'This name is too long'**
  String get shareNameTooLong;

  /// No description provided for @shareNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get shareNameEmpty;

  /// No description provided for @shareErrorNoUsername.
  ///
  /// In en, this message translates to:
  /// **'No username has been created yet'**
  String get shareErrorNoUsername;

  /// No description provided for @shareErrorNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select what should be shared'**
  String get shareErrorNothingSelected;

  /// No description provided for @shareErrorWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'This share could not be opened – wrong code or wrong school number?'**
  String get shareErrorWrongCredentials;

  /// No description provided for @shareErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'These data could not be read'**
  String get shareErrorUnreadable;

  /// No description provided for @shareDemoNoShares.
  ///
  /// In en, this message translates to:
  /// **'Nobody has shared anything yet'**
  String get shareDemoNoShares;

  /// No description provided for @shareDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete share'**
  String get shareDelete;
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
