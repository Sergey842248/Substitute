import 'package:substitute/models/Button.dart';
import 'package:substitute/models/ListPage.dart';
import 'package:substitute/pages/dashboard/settings/Lessons.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:convert';

import 'package:page_transition/page_transition.dart';

import '../../models/swipe_page_transition.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/PlanModePreferences.dart';

import '../dashboard/settings/VPlanLogin.dart';

import '../../models/ListItem.dart';
import '../../models/LoadingProcess.dart';

import './LessonPreview.dart';
import './Plan.dart';

class VPlan extends StatefulWidget {
  const VPlan({Key? key}) : super(key: key);

  @override
  _VPlanState createState() => _VPlanState();
}

class _VPlanState extends State<VPlan> with RouteAware {
  List<String> classes = [];
  List<Map<String, dynamic>> persons = [];
  bool hidePersons = false;
  final listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    getClasses();

    // Einmalig nach dem ersten Aufbau sicherstellen, dass die
    // „Nächste Stunde“-Vorschauen beim App-Start wirklich frisch geladen
    // werden – auch wenn die Hintergrund-Aktualisierung bereits vor dem
    // Anlegen der Klassen-Widgets durchgelaufen ist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) vplanBackgroundRefresh.value++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Route? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  void didPopNext() {
    // Die VPlan-Übersicht ist wieder sichtbar (z.B. nach dem Hinzufügen einer
    // Klasse/Kurse oder dem Zurückwechseln eines Tabs): Die „Nächste Stunde“-
    // Vorschauen neu laden, damit die tatsächlich nächste Stunde angezeigt
    // wird und nicht mehr fälschlich „Wochenende“.
    vplanBackgroundRefresh.value++;
    // Auch die Personen erneut laden: Name, Klasse und Kursauswahl (sowie die
    // Vorschau-Einstellung) können sich in den Einstellungen geändert haben.
    _reloadPersons();
    super.didPopNext();
  }

  /// Lädt die gespeicherten Personen neu und zeichnet den Personenbereich
  /// anschließend neu – nur, wenn sich tatsächlich etwas geändert hat.
  Future<void> _reloadPersons() async {
    final List<Map<String, dynamic>> loaded = await VPlanAPI().getPersons();
    if (!mounted) return;
    if (jsonEncode(loaded) == jsonEncode(persons)) return;
    setState(() {
      persons = loaded;
    });
  }

  @override
  void didPush() {
    // Erstes Erscheinen (ggf. App-Start): Vorschauen frisch laden.
    vplanBackgroundRefresh.value++;
    super.didPush();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void getClasses() async {
    classes = [];

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    List<String>? prefClasses =
        prefs.getStringList(SchoolStorage.scopedKey(prefs, 'classes'));
    if (prefClasses == null) {
      prefClasses = [];
    }

    final listState = listKey.currentState;
    if (listState != null) {
      for (int i = 0; i < prefClasses.length; i++) {
        listState.insertItem(i);
        classes.add(prefClasses[i]);
      }
    } else {
      classes.addAll(prefClasses);
    }

    // One-time migration: older versions stored 'hidePersons' with a default
    // of OFF. Reset any stored value once so the new default applies.
    if (!(prefs
            .getBool(SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated')) ??
        false)) {
      await prefs.remove(SchoolStorage.scopedKey(prefs, 'hidePersons'));
      await prefs.setBool(
          SchoolStorage.scopedKey(prefs, 'hidePersonsMigrated'), true);
    }
    hidePersons =
        prefs.getBool(SchoolStorage.scopedKey(prefs, 'hidePersons')) ?? false;
    persons = await VPlanAPI().getPersons();
    if (!mounted) return;
    setState(() {});

    String? username =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

    if (classes.length == 0 && (username == null || username == '')) {
      if (!mounted) return;
      // Ohne Zugangsdaten direkt zur Anmeldeseite navigieren, statt einen
      // Dialog anzuzeigen – so kommt man ohne Zugangsdaten nicht in die App.
      Navigator.push(
        context,
        SwipePageTransition(
          type: PageTransitionType.rightToLeft,
          child: VPlanLogin(blockBack: true),
        ),
      );
    }
  }

  Widget _personsSection() {
    // Persons section can be hidden in the plan settings
    if (hidePersons) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(
                AppLocalizations.of(context)!.persons,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: _openAddPerson,
              icon: Icon(Icons.person_add_alt_1_rounded),
              tooltip: AppLocalizations.of(context)!.addPerson,
            ),
          ],
        ),
        ...persons.map((person) {
          return PersonWidget(
            person: person,
            onDelete: () => _deletePerson(person),
            openContainer: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: Scaffold(
                  body: Plan(
                    classId: person['classId'],
                    person: person,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Fragt vor dem Löschen einer Person nach, damit sie nicht versehentlich
  /// verloren geht. Erst nach einer Bestätigung wird sie tatsächlich entfernt.
  Future<void> _deletePerson(Map<String, dynamic> person) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.deletePersonTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: Text(
          l10n.deletePersonMessage(
            person['name']?.toString() ?? person['id']?.toString() ?? '',
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.deleteAction,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await VPlanAPI().deletePerson(person['id']);
    setState(() {
      persons.remove(person);
    });
  }

  /// Fragt vor dem Löschen einer Klasse nach, damit sie nicht versehentlich
  /// verloren geht. Erst nach einer Bestätigung wird sie tatsächlich entfernt.
  Future<void> _deleteClass(int index) async {
    if (index < 0 || index >= classes.length) return;
    final String classId = classes[index];
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String className = await VPlanAPI().getClassName(classId) ?? classId;
    if (!mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.deleteClassTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: Text(
          l10n.deleteClassMessage(className),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.deleteAction,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Nach dem Dialog kann sich die Liste nicht verändert haben, da währenddessen
    // keine weiteren Aktionen möglich waren.
    final int currentIndex = classes.indexOf(classId);
    if (currentIndex == -1) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? newClasses =
        prefs.getStringList(SchoolStorage.scopedKey(prefs, 'classes'));
    if (newClasses == null) {
      newClasses = [];
    }
    newClasses.remove(classId);
    prefs.setStringList(
        SchoolStorage.scopedKey(prefs, 'classes'), newClasses);
    // Auch die gespeicherten Kurs-Auswahlen und den
    // benutzerdefinierten Namen der Klasse zurücksetzen,
    // damit eine später erneut hinzugefügte Klasse wieder
    // mit allen Kursen startet.
    await VPlanAPI().removeHiddenCoursesForClass(classId);
    await VPlanAPI().removeClassName(classId);
    if (!mounted) return;

    listKey.currentState!.removeItem(
      currentIndex,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: ListItem(
          onClick: () {},
          title: Text(
            classId,
            style: TextStyle(
              fontSize: 19,
            ),
          ),
        ),
      ),
    );
    classes.removeAt(currentIndex);
  }

  Future<void> _openAddPerson() async {
    final VPlanAPI vplanAPI = VPlanAPI();

    // Step 1: Pick a class for the new person
    final completer = Completer<String?>();
    await Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: SelectClass(
            personMode: true,
            pop: (className) {
              if (!completer.isCompleted) completer.complete(className);
            },
            favs: [],
          ),
        ),
      ),
    ).then((_) {
      // If the user left the class selection without picking one, abort
      if (!completer.isCompleted) completer.complete(null);
    });
    final String? className = await completer.future;
    if (className == null || !mounted) return;

    // Step 2: Enter the person's name
    // Ohne Eingabe wird der Name der gewählten Klasse verwendet.
    final String classFallbackHint =
        await VPlanAPI().getClassName(className) ?? className;
    final TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.personName,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: classFallbackHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;

    // Ohne eingegebenen Namen wird der Klassenname verwendet – ist der schon
    // vergeben, bekommt die Person " (1)", " (2)" … angehängt.
    final String personName = await _resolvePersonName(name, className);
    if (!mounted) return;

    // Step 3: Choose the courses to show for this person
    final person = {
      'id': '${AppClock.now().millisecondsSinceEpoch}',
      'name': personName,
      'classId': className,
      'courses': <String>[],
    };
    await Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: PersonCourses(
            classId: className,
            person: person,
            isNew: true,
          ),
        ),
      ),
    );

    persons = await vplanAPI.getPersons();
    if (mounted) setState(() {});
  }

  /// Ermittelt den Namen einer **neu angelegten** Person: den eingegebenen
  /// Namen, sonst den Namen der Klasse (bzw. deren selbst vergebener
  /// Anzeigename).
  ///
  /// Nur beim Anlegen wird ein Suffix vergeben, und nur wenn es in derselben
  /// Klasse bereits eine Person mit diesem Namen gibt: Dann wird " (1)",
  /// " (2)" … angehängt. Derselbe Name in einer anderen Klasse bleibt
  /// unverändert.
  Future<String> _resolvePersonName(String? entered, String classId) async {
    final String typed = (entered ?? '').trim();
    final String base = typed.isNotEmpty
        ? typed
        : await VPlanAPI().getClassName(classId) ?? classId;

    final List<Map<String, dynamic>> persons = await VPlanAPI().getPersons();
    return VPlanAPI.uniquePersonName(
      base,
      persons
          .where(
              (Map<String, dynamic> p) => p['classId']?.toString() == classId)
          .map((Map<String, dynamic> p) => p['name']?.toString() ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _personsSection(),
            const SizedBox(height: 2),
            ListItem(
              margin: 5,
              title: Text(
                AppLocalizations.of(context)!.selectClass,
                style: TextStyle(
                  fontSize: 19,
                ),
              ),
              onClick: () => Navigator.push(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: SelectClass(
                    pop: (String classId) {
                      listKey.currentState!.insertItem(classes.length);
                      classes.add(classId);
                    },
                    favs: classes,
                  ),
                ),
              ),
            ),
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Scrollbar(
                radius: Radius.circular(100),
                child: AnimatedList(
                  padding: EdgeInsets.zero,
                  physics: BouncingScrollPhysics(),
                  key: listKey,
                  initialItemCount: classes.length,
                  itemBuilder: (context, index, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: ClassWidget(
                      classId: classes[index],
                      classIndex: index,
                      onDelete: () => _deleteClass(index),
                      openContainer: () => Navigator.push(
                        context,
                        SwipePageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: Plan(
                            classId: classes[index],
                          ),
                        ),
                      ),
                    ), // closes ClassWidget
                  ), // closes SizeTransition
                ), // closes AnimatedList
              ), // closes Scrollbar
            ), // closes the height Container
          ], // closes Column's children
        ), // closes Column
      ), // closes SingleChildScrollView
    ); // closes outer Container
  }
}

class ClassWidget extends StatefulWidget {
  const ClassWidget({
    Key? key,
    required this.classId,
    required this.classIndex,
    required this.onDelete,
    required this.openContainer,
  }) : super(key: key);

  final String classId;
  final int classIndex;
  final Function() onDelete;
  final Function openContainer;

  @override
  State<ClassWidget> createState() => _ClassWidgetState();
}

class _ClassWidgetState extends State<ClassWidget> {
  Map<String, dynamic> nextLesson = previewLoading;
  String? customName;
  bool hideLessonTimes = true;

  /// Vorschau für diese Klasse ausgeblendet? (spezifische Einstellung der
  /// Klasse, sonst die globale Einstellung aus den Plan-Einstellungen)
  bool previewHidden = false;
  String _defaultPlanMode = 'auto';

  Future<void> _loadCustomName() async {
    String? name = await VPlanAPI().getClassName(widget.classId);
    if (mounted && name != customName) {
      setState(() {
        customName = name;
      });
    }
  }

  Future<void> _renameClass() async {
    final TextEditingController nameController =
        TextEditingController(text: customName ?? widget.classId);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.renameClass,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.classNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    await VPlanAPI().setClassName(widget.classId, newName);
    if (mounted) {
      setState(() {
        customName = newName.isEmpty ? null : newName;
      });
    }
  }

  /// Aktualisiert die „Nächste Stunde“-Vorschau. Zuerst wird offline (ohne
  /// Netzwerkwarten) die zuletzt bekannte Vorschau angezeigt, anschließend
  /// werden im Hintergrund frische Daten geholt und die Vorschau nur ersetzt,
  /// wenn sich tatsächlich etwas geändert hat – es wird nie eine
  /// Ladeanimation gezeigt.
  ///
  /// [forceRefresh] == true lädt frisch vom Server, andernfalls werden
  /// (ohne Ladezeit) die lokal gespeicherten Daten verwendet.
  getData({bool silent = false, bool forceRefresh = false}) async {
    final Map<String, dynamic> oldNextLesson = nextLesson;
    final bool oldPreviewHidden = previewHidden;
    final VPlanAPI vplanAPI = VPlanAPI();

    void refreshIfChanged() {
      // Auch ein geänderter Sichtbarkeitszustand muss neu gezeichnet werden,
      // sonst bleibt eine ein-/ausgeblendete Vorschau veraltet stehen.
      if (silent &&
          mapEquals(oldNextLesson, nextLesson) &&
          oldPreviewHidden == previewHidden) {
        return;
      }
      if (mounted) setState(() {});
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
      _defaultPlanMode = await PlanModePreferences.readPreviewClass(prefs);
    } catch (_) {
      hideLessonTimes = true;
    }
    final bool hidden = await vplanAPI.isPreviewHiddenForClass(widget.classId);

    // Vorschau ausgeblendet: es gibt nichts zu berechnen bzw. zwischen-
    // zuspeichern – ein bereits berechneter Cache bleibt aber erhalten, damit
    // sie nach dem Einblenden sofort wieder vorliegt.
    if (hidden) {
      previewHidden = true;
      nextLesson = oldNextLesson;
      refreshIfChanged();
      return;
    }
    previewHidden = false;

    List<String> hiddenCourses = [];
    try {
      hiddenCourses = await vplanAPI.getHiddenCourses(widget.classId);
    } catch (_) {
      hiddenCourses = [];
    }

    dynamic vplan;
    try {
      vplan = forceRefresh
          ? await vplanAPI
              .getLessonsForToday(widget.classId, forceRefresh: true)
          : await vplanAPI.getCachedLessonsForToday(widget.classId);
    } catch (_) {
      refreshIfChanged();
      return;
    }
    if (vplan is! Map || vplan['data'] is! List) {
      refreshIfChanged();
      return;
    }

    nextLesson = await computeNextLesson(
      plan: vplan,
      mode: _defaultPlanMode,
      classId: widget.classId,
      isHidden: (lesson) => vplanAPI.isLessonHidden(lesson, hiddenCourses),
      allowNextDay: forceRefresh,
      vplanAPI: vplanAPI,
    );

    // Hat die frische Berechnung keine *konkrete* nächste Stunde ergeben
    // (z.B. weil die nächste Stunde an einem späteren Tag liegt, dessen Plan
    // noch nicht geholt wurde, oder weil gerade eine Lücke im Plan ist),
    // dann zeigen wir weiterhin die zuvor bekannte (gecachete) Vorschau an
    // und überschreiben den Cache nicht mit diesem nichtssagenden Ergebnis.
    // Erst wenn der Plan tatsächlich neu geladen wurde und eine echte
    // nächste Stunde liefert, wird die Anzeige ersetzt.
    final bool hasNewLesson = nextLesson.containsKey('lesson');
    final bool hadOldLesson = oldNextLesson.containsKey('lesson');
    if (!forceRefresh && !hasNewLesson && hadOldLesson) {
      nextLesson = oldNextLesson;
      refreshIfChanged();
      return;
    }

    // Zuletzt berechnete Vorschau speichern, damit sie beim nächsten Öffnen
    // sofort (ohne Ladezeit) angezeigt wird.
    saveNextLesson(widget.classId, nextLesson);
    refreshIfChanged();
  }

  @override
  void initState() {
    super.initState();
    // Sofort (ohne Ladezeit und ohne await) die zuletzt gespeicherte
    // „Nächste Stunde“-Vorschau anzeigen – der allererste Frame zeigt also
    // bereits den letzten Stand.
    nextLesson = cachedNextLesson(widget.classId) ?? previewLoading;
    // 1) Lokale Vorschau (Cache) anzeigen.
    getData();
    // 2) Im Hintergrund frische Daten laden und – nur wenn nötig – ersetzen.
    getData(silent: true, forceRefresh: true);
    _loadCustomName();
    vplanBackgroundRefresh.addListener(_onBackgroundRefresh);
  }

  /// Reaktioniert auf den Hintergrund-Refresh beim App-Start: Die Vorschau
  /// wird im Hintergrund neu geladen, aber nur für diesen Favoriten neu
  /// gezeichnet, wenn sich die nächste Stunde / der Plan tatsächlich geändert
  /// hat.
  void _onBackgroundRefresh() {
    getData(silent: true, forceRefresh: true);
  }

  @override
  void dispose() {
    vplanBackgroundRefresh.removeListener(_onBackgroundRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 5, right: 5, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListItem(
            title: Text(
              customName ?? widget.classId,
              style: TextStyle(
                fontSize: 19,
              ),
            ),
            onClick: widget.openContainer,
            actionButton: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _renameClass,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                  tooltip: AppLocalizations.of(context)!.renameClass,
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            margin: 0,
            // Ohne Vorschau hat der Eintrag keinen Anschluss nach unten und
            // wird deshalb rundherum abgerundet.
            borderRadius: previewHidden
                ? BorderRadius.circular(25)
                : BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
          ),
          if (!previewHidden)
            LessonPreviewCard(
              nextLesson: nextLesson,
              onTap: () => widget.openContainer(),
              hideLessonTimes: hideLessonTimes,
            ),
        ],
      ),
    );
  }
}

/// Eintrag einer Person in der VPlan-Übersicht inklusive der „Nächste
/// Stunde“-Vorschau der von der Person gewählten Kurse.
class PersonWidget extends StatefulWidget {
  const PersonWidget({
    Key? key,
    required this.person,
    required this.onDelete,
    required this.openContainer,
  }) : super(key: key);

  final Map<String, dynamic> person;
  final Function() onDelete;
  final Function openContainer;

  @override
  State<PersonWidget> createState() => _PersonWidgetState();
}

class _PersonWidgetState extends State<PersonWidget> {
  Map<String, dynamic> nextLesson = previewLoading;
  bool hideLessonTimes = true;

  /// Vorschau für diese Person ausgeblendet? (spezifische Einstellung der
  /// Person, sonst die globale Einstellung aus den Plan-Einstellungen).
  /// Startet mit dem Standard, damit bei Personen keine Vorschau kurz aufblitzt.
  bool previewHidden = VPlanAPI.defaultPreviewPersonsHidden;
  String _defaultPlanMode = 'auto';

  /// Kurse, die die Person beobachtet – nur deren Stunden erscheinen in der
  /// Vorschau.
  List<String> courses = [];

  String get _classId => widget.person['classId']?.toString() ?? '';
  String get _personId => widget.person['id']?.toString() ?? '';

  /// Benennt die Person um. Der Name wird dabei **immer unverändert**
  /// übernommen: Zwei Personen dürfen denselben Namen haben, auch in derselben
  /// Klasse. Ein Suffix wie " (1)" wird ausschließlich beim Anlegen vergeben.
  Future<void> _renamePerson() async {
    final TextEditingController nameController =
        TextEditingController(text: widget.person['name']?.toString() ?? '');
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.renamePerson,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.personName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, nameController.text.trim()),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;

    // Leerer Name -> Name der Klasse, sonst der eingegebene Name. Ohne
    // Suffix: Beim Umbenieren sind Doppelnamen ausdrücklich erlaubt.
    final String resolved = newName.isEmpty ? _classId : newName;

    if (_personId.isEmpty) {
      // Ohne ID lässt sich die Person nicht gezielt speichern – der Name im
      // Widget wird trotzdem aktualisiert, damit er direkt sichtbar ist.
      setState(() => widget.person['name'] = resolved);
      return;
    }

    await VPlanAPI().updatePersonName(_personId, resolved);
    if (!mounted) return;
    // Die Person-Map wird auch in der Liste der Übersicht gehalten – sie wird
    // hier direkt aktualisiert, damit die neue Anzeige sofort stimmt.
    setState(() => widget.person['name'] = resolved);
  }
  String get _cacheKey => nextLessonCacheKeyForPerson(_personId);

  List<String> _coursesOf(Map<String, dynamic> person) {
    final dynamic raw = person['courses'];
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  @override
  void initState() {
    super.initState();
    courses = _coursesOf(widget.person);
    nextLesson = cachedNextLesson(_cacheKey) ?? previewLoading;
    getData();
    getData(silent: true, forceRefresh: true);
    vplanBackgroundRefresh.addListener(_onBackgroundRefresh);
  }

  @override
  void didUpdateWidget(PersonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Die Kursauswahl kann sich in den Personen-Einstellungen geändert haben.
    final List<String> updated = _coursesOf(widget.person);
    if (!listEquals(updated, courses)) {
      courses = updated;
      getData();
    }
  }

  /// Lädt die „Nächste Stunde“-Vorschau der Person. Zuerst wird offline (ohne
  /// Netzwerkwarten) die zuletzt bekannte Vorschau angezeigt, anschließend
  /// werden im Hintergrund frische Daten geholt und die Vorschau nur ersetzt,
  /// wenn sich tatsächlich etwas geändert hat.
  getData({bool silent = false, bool forceRefresh = false}) async {
    final Map<String, dynamic> oldNextLesson = nextLesson;
    final bool oldPreviewHidden = previewHidden;
    final VPlanAPI vplanAPI = VPlanAPI();

    void refreshIfChanged() {
      // Auch ein geänderter Sichtbarkeitszustand muss neu gezeichnet werden,
      // sonst bleibt eine ein-/ausgeblendete Vorschau veraltet stehen.
      if (silent &&
          mapEquals(oldNextLesson, nextLesson) &&
          oldPreviewHidden == previewHidden) {
        return;
      }
      if (mounted) setState(() {});
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      hideLessonTimes =
          prefs.getBool(SchoolStorage.scopedKey(prefs, 'hideLessonTimes')) ??
              true;
      _defaultPlanMode = await PlanModePreferences.readPreviewPerson(prefs);
    } catch (_) {
      hideLessonTimes = true;
    }
    final bool hidden = await vplanAPI.isPreviewHiddenForPerson(_personId);

    /// Filtert die Einträge, die nicht in die Vorschau gehören. Wird unten
    /// passend zur Kursauswahl der Person (bzw. zur Klasse) gesetzt.
    late final bool Function(dynamic lesson) isLessonHidden;

    // Vorschau ausgeblendet: es gibt nichts zu berechnen – ein bereits
    // berechneter Cache bleibt aber erhalten, damit sie nach dem Einblenden
    // sofort wieder vorliegt.
    if (hidden) {
      previewHidden = true;
      nextLesson = oldNextLesson;
      refreshIfChanged();
      return;
    }
    previewHidden = false;

    dynamic vplan;
    try {
      vplan = forceRefresh
          ? await vplanAPI.getLessonsForToday(_classId, forceRefresh: true)
          : await vplanAPI.getCachedLessonsForToday(_classId);
    } catch (_) {
      refreshIfChanged();
      return;
    }
    if (vplan is! Map || vplan['data'] is! List) {
      refreshIfChanged();
      return;
    }

    // Nur die Kurse, die die Person beobachtet, kommen für die Vorschau in
    // Frage. Hat die Person keine Kurse ausgewählt, gilt dasselbe wie bei einer
    // Klasse ohne Auswahl: Es werden die Kurse der Klasse angezeigt, also
    // alles, was in den Klassen-Einstellungen nicht ausgeblendet wurde.
    List<String> classHiddenCourses = [];
    try {
      classHiddenCourses = await vplanAPI.getHiddenCourses(_classId);
    } catch (_) {
      classHiddenCourses = [];
    }
    isLessonHidden = (lesson) => !vplanAPI.isLessonVisibleForPerson(
          lesson,
          courses,
          classHiddenCourses,
        );

    nextLesson = await computeNextLesson(
      plan: vplan,
      mode: _defaultPlanMode,
      classId: _classId,
      isHidden: isLessonHidden,
      allowNextDay: forceRefresh,
      vplanAPI: vplanAPI,
    );

    // Keine konkrete nächste Stunde gefunden: die zuletzt bekannte Vorschau
    // beibehalten statt sie mit einem nichtssagenden Ergebnis zu ersetzen.
    final bool hasNewLesson = nextLesson.containsKey('lesson');
    final bool hadOldLesson = oldNextLesson.containsKey('lesson');
    if (!forceRefresh && !hasNewLesson && hadOldLesson) {
      nextLesson = oldNextLesson;
      refreshIfChanged();
      return;
    }

    saveNextLesson(_cacheKey, nextLesson);
    refreshIfChanged();
  }

  void _onBackgroundRefresh() {
    getData(silent: true, forceRefresh: true);
  }

  @override
  void dispose() {
    vplanBackgroundRefresh.removeListener(_onBackgroundRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 5, right: 5, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListItem(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.person['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _classId,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            actionButton: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _renamePerson,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                  tooltip: AppLocalizations.of(context)!.renamePerson,
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_rounded,
                    color: Theme.of(context).focusColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            onClick: widget.openContainer,
            padding: 7,
            // Ohne Vorschau hat der Eintrag keinen Anschluss nach unten und
            // wird deshalb rundherum abgerundet.
            borderRadius: previewHidden
                ? BorderRadius.circular(25)
                : BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
          ),
          if (!previewHidden)
            LessonPreviewCard(
              nextLesson: nextLesson,
              onTap: () => widget.openContainer(),
              hideLessonTimes: hideLessonTimes,
              // Bei einer Person ist der Kurs die entscheidende Angabe.
              showCourse: true,
            ),
        ],
      ),
    );
  }
}
class SelectClass extends StatefulWidget {
  const SelectClass({
    Key? key,
    required this.pop,
    required this.favs,
    this.personMode = false,
  }) : super(key: key);

  final Function pop;
  final List<String> favs;
  final bool personMode;

  @override
  State<SelectClass> createState() => _SelectClassState();
}

class _SelectClassState extends State<SelectClass> {
  dynamic classes = [];
  bool _loginPageOpened = false;

  /// Öffnet die Anmeldeseite direkt (statt eines Dialogs), wenn keine
  /// Zugangsdaten hinterlegt sind. Schützt vor doppeltem Öffnen, da
  /// getClasses() sowohl aus initState als auch aus didChangeDependencies
  /// aufgerufen wird.
  void _openLoginPage() {
    if (_loginPageOpened) return;
    _loginPageOpened = true;
    Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: VPlanLogin(blockBack: true),
      ),
    );
  }

  void getClasses() async {
    // Prüfe, ob Zugangsdaten vorhanden sind
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username =
        prefs.getString(SchoolStorage.scopedKey(prefs, 'vplanUsername'));

    if (!mounted) return;

    if (username == null || username == '') {
      // Ohne Zugangsdaten direkt zur Anmeldeseite navigieren, statt einen
      // Dialog anzuzeigen – so kommt man ohne Zugangsdaten nicht in die App.
      if (!mounted) return;
      _openLoginPage();
      return; // Stoppe weitere Ausführung wenn keine Zugangsdaten vorhanden sind
    }

    // Wenn Zugangsdaten vorhanden sind, lade die Klassen
    VPlanAPI vplanAPI = new VPlanAPI();
    classes = await vplanAPI.getClassList();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getClasses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh classes when returning from VPlanLogin with new credentials
    // This fixes the issue where classes load infinitely after adding credentials
    getClasses();
  }

  @override
  Widget build(BuildContext context) {
    if (classes.toString().contains('error')) {
      String errorText = '';
      Widget extraWidget = SizedBox();
      switch (classes['error']) {
        case '401':
          errorText = 'Der Benutzername oder das Passwort ist falsch!';
          extraWidget = Lottie.asset(
            'assets/animations/lock.json',
            height: 120,
          );
          break;
        case 'schoolnumber':
          errorText = 'Falsche Schulnummer!\n\noder Vertretungsplan verfügbar';
          extraWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Theme.of(context).colorScheme.surface,
            ),
            margin: EdgeInsets.only(
              left: MediaQuery.of(context).size.width * 0.37,
              right: MediaQuery.of(context).size.width * 0.37,
              bottom: 30,
            ),
            child: Center(
              child: Lottie.asset(
                'assets/animations/attention.json',
                height: 120,
                width: 120,
              ),
            ),
          );
          break;
        case 'no internet':
          errorText = 'No internet connection';
          extraWidget = Lottie.asset(
            'assets/animations/wifi.json',
            height: 120,
          );
          break;
        default:
          switch (classes['data']['error']) {
            case '401':
              errorText = 'Username or password incorrect!';
              extraWidget = Lottie.asset(
                'assets/animations/lock.json',
                height: 120,
              );
              break;
            case 'schoolnumber':
              errorText =
                  'Wrong schoolnumber!\n\nor no substitution plan available!';
              extraWidget = Lottie.asset(
                'assets/animations/attention.json',
                height: 120,
              );
              break;
            case 'no internet':
              errorText = 'No internet connection';
              extraWidget = Lottie.asset(
                'assets/animations/wifi.json',
                height: 120,
              );
              break;
          }
      }
      return ListPage(
        title: AppLocalizations.of(context)!.classSelection,
        actions: [
          IconButton(
            onPressed: () => getClasses(),
            icon: Icon(Icons.sync_rounded),
          ),
        ],
        children: [
          extraWidget,
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(left: 10, right: 10),
            child: Text(
              errorText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red.shade300,
              ),
            ),
          ),
          SizedBox(height: 30),
          Button(
            text: AppLocalizations.of(context)!.credentials,
            onPressed: () => Navigator.push(
              context,
              SwipePageTransition(
                type: PageTransitionType.rightToLeft,
                child: VPlanLogin(),
              ),
            ),
          ),
        ],
      );
    }
    return ListPage(
      title: AppLocalizations.of(context)!.selectClassTitle,
      children: [
        classes.length == 0
            ? Center(
                child: LoadingProcess(),
              )
            : SizedBox(),
        ...classes.map((className) {
          bool used = false;
          if (widget.favs.contains(className)) {
            used = true;
          }
          return ListItem(
            title: Text(
              className,
              style: TextStyle(
                fontSize: 19,
                fontWeight: used ? FontWeight.w600 : null,
                color: used ? Colors.black : null,
              ),
            ),
            actionButton: used
                ? IconButton(
                    icon: Icon(
                      Icons.check_rounded,
                      color: used ? Colors.black : null,
                    ),
                    onPressed: () {},
                  )
                : null,
            color: used ? Theme.of(context).indicatorColor : null,
            onClick: () async {
              if (widget.personMode) {
                // Person creation: only report the picked class
                this.widget.pop(className);
                Navigator.pop(context);
                return;
              }
              SharedPreferences instance =
                  await SharedPreferences.getInstance();
              List<String>? _classes = instance
                  .getStringList(SchoolStorage.scopedKey(instance, 'classes'));
              if (_classes == null) {
                _classes = [];
              }
              _classes.add(className);
              instance.setStringList(
                  SchoolStorage.scopedKey(instance, 'classes'), _classes);

              // Optional: ask for a custom name for the class
              final TextEditingController nameController =
                  TextEditingController(text: className);
              final String? customName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Text(
                    AppLocalizations.of(context)!.nameClass,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19),
                  ),
                  content: TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.classNameHint,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context)!.later,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, nameController.text.trim()),
                      child: Text(
                        AppLocalizations.of(context)!.save,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (customName != null &&
                  customName.isNotEmpty &&
                  customName != className) {
                await VPlanAPI().setClassName(className, customName);
              }

              // Hide all courses for the new class by default – unless we are
              // in demo mode, where every subject should be visible so the
              // substitution plan actually shows lessons.
              final vplanApi = VPlanAPI();
              await vplanApi.login();
              if (!vplanApi.isDemoMode) {
                final courses = await vplanApi.getCourses(className);
                if (courses.isNotEmpty) {
                  final allCourseIds = courses
                      .map((c) => c['course'] as String)
                      .where((c) => c != '---')
                      .toList();
                  await vplanApi.setHiddenCourses(className, allCourseIds);
                }
              }

              // Add the class to VPlan's list
              this.widget.pop(className);

              // Replace SelectClass with Courses so the user lands
              // directly on course selection. Popping Courses later
              // returns to VPlan.
              Navigator.pushReplacement(
                context,
                SwipePageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: Scaffold(
                    body: Courses(
                      classId: className,
                      updateCourses: () async {},
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
