import 'dart:async';

import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/l10n/app_localizations.dart';
import 'package:substitute/pages/vplan/Plan.dart';
import 'package:substitute/pages/vplan/VPlan.dart';
import 'package:substitute/pages/vplan/VPlanAPI.dart';
import 'package:substitute/services/AppClock.dart';
import 'package:substitute/services/ClassNames.dart';
import 'package:substitute/services/NativeScreens.dart';
import 'package:substitute/services/SchoolStorage.dart';

import '../../models/swipe_page_transition.dart';

/// Die Verbindung der **nativen** Plan-Übersicht zu den Daten in Dart.
///
/// ## Warum das hier ist und nicht in [VPlan]
///
/// Auf iOS ist die Plan-Übersicht ein Bildschirm aus `UIKit`
/// (`PlanOverviewScreen`). Er kennt keine Klassen und keine Personen – er
/// bekommt sie von hier, als schlanke Karten aus Text.
///
/// [VPlan] bleibt trotzdem da, und zwar für Android und im Web, wo es die
/// Übersicht **selbst** zeichnet. Beide Wege lesen dieselben Stellen – den
/// Speicher und `VPlanAPI` – und deshalb können sie nicht auseinanderlaufen.
///
/// ## Der Rückweg
///
/// Tippt oder wischt jemand auf der nativen Seite, kommt hier eine Aktion an
/// ([handle]): „öffne die Klasse", „lösche die Person". Hier wird entschieden,
/// was das bedeutet – und hier wird es getan.
///
/// ## Warum das Löschen **ohne** Dialog hier passiert
///
/// Weil der Dialog **nativ** ist. Er wird auf der nativen Seite gezeigt, mit
/// dem Namen der Sache und einem roten Knopf – so wie iOS es überall tut.
///
/// Die Bestätigung ist damit nicht in Dart, und das ist genau richtig: Sie ist
/// eine Frage an den Menschen, und die stellt das System, nicht die Logik.
/// Dart bekommt danach nur noch den Befehl, die Person zu löschen – eine
/// Tatsache, keine Frage.
class PlanNativeBridge {
  const PlanNativeBridge._();

  /// Setzt den Zuhörer für die Tipps der nativen Bildschirme.
  ///
  /// Es wird **einmal** beim Start gerufen und nicht von jedem Bildschirm für
  /// sich – siehe [NativeScreens.onAction].
  static void install() {
    NativeScreens.onAction(handle);
  }

  // ---------------------------------------------------------- Werte senden

  /// Liest Klassen und Personen und schickt sie nach oben.
  ///
  /// ## Warum hier **kein** Warten auf die Vorschau
  ///
  /// Die Vorschau braucht das VPlan-XML und damit ein Netz. Die Klassen und die
  /// Namen stehen im Speicher und sind sofort da.
  ///
  /// Es wird deshalb nur geschickt, was **sofort** da ist, und die Übersicht
  /// bekommt ihre Zeilen sofort. Die Vorschau steht ohnehin in Flutter – sie ist
  /// der Grund, warum die Zeilen dort so dünn sind (siehe
  /// `PlanOverviewScreen`).
  static Future<void> publishPlan() async {
    if (!NativeScreens.isSupported) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> classes = prefs.getStringList(
            SchoolStorage.scopedKey(prefs, 'classes')) ??
        <String>[];

    // Die Anzeigenamen kommen aus `VPlanAPI`, nicht aus dem Kürzel: Wer einer
    // Klasse einen Namen gegeben hat, sieht diesen Namen – sonst stünde in der
    // Liste „8a", während der Plan drinnen „Klasse 8b" heißt.
    final Map<String, String> anzeigenamen = await VPlanAPI().getClassNames();
    final List<Map<String, dynamic>> persons = await VPlanAPI().getPersons();

    // Ob die Personen überhaupt gezeigt werden, ist eine **Einstellung**, und
    // sie wird hier gelesen und nicht etwa auf der nativen Seite entschieden: Es
    // gibt nur eine Quelle dafür (`SchoolStorage.scopedKey`).
    final bool versteckt =
        prefs.getBool(SchoolStorage.scopedKey(prefs, 'hidePersons')) ?? false;

    NativeScreens.publish(NativeScreen.plan, <String, dynamic>{
      'classes': classes
          .map((String id) => <String, dynamic>{
                'id': id,
                'name': anzeigenamen[id] ?? id,
              })
          .toList(),
      'persons': persons
          .map((Map<String, dynamic> person) => <String, dynamic>{
                'id': person['id']?.toString() ?? '',
                'name': person['name']?.toString() ?? '',
                'classId': person['classId']?.toString() ?? '',
              })
          .toList(),
      'hidePersons': versteckt,
    });
  }

  /// Schickt die Texte des Sync-Bildschirms nach oben.
  ///
  /// ## Warum hier **nur** die Texte
  ///
  /// Weil die Texte übersetzt sind und die Zeichen nicht. Ein Text „Teilen" ist
  /// in beiden Sprachen etwas anderes und gehört deshalb hierher; das Zeichen
  /// daneben ist eine Frage des Aussehens und gehört auf die native Seite.
  ///
  /// ## Warum die **Reihenfolge** hier feststeht
  ///
  /// Weil sie Absicht ist: erst die eigenen Geräte, dann das Teilen mit anderen,
  /// dann deren Angebote. Ein Weg von „mir" über „uns" zu „den anderen" – und
  /// dieselbe Reihenfolge wie in `SyncShareHub.eintraege`. Sie wird hier
  /// ausgeschrieben statt von dort gelesen, weil diese Liste an einem Ort stehen
  /// muss: Zwei Listen, deren Reihenfolge auseinanderläuft, wären auf Android
  /// eine Sache und auf iOS eine andere.
  ///
  /// Die `id` ist der Schlüssel, an dem die native Seite ihren Weg findet – sie
  /// ist **englisch** und ohne Punkte, weil sie ein Schlüssel in Quelltext ist
  /// und nicht etwas, was jemand liest.
  static void publishSync(AppLocalizations l10n) {
    if (!NativeScreens.isSupported) return;
    NativeScreens.publish(NativeScreen.sync, <String, dynamic>{
      'entries': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'sync',
          'title': l10n.sync,
          'subtitle': l10n.syncSubtitle,
        },
        <String, dynamic>{
          'id': 'share',
          'title': l10n.share,
          'subtitle': l10n.shareSubtitle,
        },
        <String, dynamic>{
          'id': 'browse',
          'title': l10n.shareBrowse,
          'subtitle': l10n.shareBrowseSubtitle,
        },
      ],
    });
  }

  // ------------------------------------------------------ Aktionen entgegen

  /// Nimmt eine Aktion der nativen Seite entgegen und erledigt sie.
  ///
  /// ## Warum hier kein Bildschirm gezeigt wird
  ///
  /// Weil die Maschine, über die das kommt, **keinen sichtbaren Bildschirm**
  /// hat: Sie rechnet im Hintergrund (`NativeScreenEngine`). Ein `showDialog`
  /// oder ein `Navigator.push` von hier aus hätte keinen Bildschirm, in dem
  /// etwas erscheinen könnte – der Aufruf ginge ins Leere und nichts würde
  /// passieren.
  ///
  /// Deshalb gibt es hier nur zwei Sorten:
  ///
  /// * Dinge, die **keinen** Bildschirm brauchen – löschen. Das kann hier
  ///   geschehen, weil der Dialog schon da war.
  /// * Dinge, die einen Bildschirm brauchen – eine Klasse hinzufügen, eine
  ///   Person anlegen. Die öffnet die native Seite **selbst**
  ///   (`PlanWerkzeugRoute`), und hier passiert nichts.
  ///
  /// Der Unterschied ist nicht technisch, sondern inhaltlich: Hinzufügen heißt
  /// tippen, und tippen braucht einen Bildschirm – und den kann nur die Seite
  /// öffnen, die einen Bildschirm hat.
  static void handle(
    NativeScreen screen,
    String action,
    Map<String, dynamic> args,
  ) {
    switch (screen) {
      case NativeScreen.plan:
        unawaited(_handlePlan(action, args));
      case NativeScreen.sync:
        // Braucht nichts von hier: Der Sync-Bildschirm öffnet seine eigenen
        // Bildschirme selbst (`SyncRoute`), weil der Weg von einer Zeile zu
        // ihrem Bildschirm eine Entscheidung der Oberfläche ist.
        break;
    }
  }

  static Future<void> _handlePlan(
    String action,
    Map<String, dynamic> args,
  ) async {
    final String id = args['id']?.toString() ?? '';

    switch (action) {
      case 'openClass':
      case 'openPerson':
        // Die native Seite öffnet den Plan. Hier wird nichts getan – siehe die
        // Beschreibung am Anfang.
        break;

      case 'deleteClass':
        if (id.isNotEmpty) {
          await klasseLoeschen(id);
          await publishPlan();
        }

      case 'deletePerson':
        if (id.isNotEmpty) {
          await VPlanAPI().deletePerson(id);
          await publishPlan();
        }

      case 'needsData':
        await publishPlan();
    }
  }

  // --------------------------------------------------------------- Löschen

  /// Nimmt eine Klasse aus der Liste – **ohne** zu fragen.
  ///
  /// Gefragt hat die native Seite schon, mit dem Namen der Klasse und einem
  /// roten Knopf. Hier wird nur noch getan, was dort beschlossen wurde.
  ///
  /// ## Warum der Kurs-Zustand mit weggeräumt wird
  ///
  /// Weil eine später wieder hinzugefügte Klasse sonst **anders** wäre als eine
  /// neue: Sie hätte die alten Ausblendungen, würde Kurse zeigen, die man nie
  /// gesehen hat, und andere ausblenden, die man sehen will. Dieselbe Reihenfolge
  /// wie in `_VPlanState._deleteClass` – und aus demselben Grund.
  static Future<void> klasseLoeschen(String classId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String schluessel = SchoolStorage.scopedKey(prefs, 'classes');
    List<String> neu = prefs.getStringList(schluessel) ?? <String>[];
    neu.remove(classId);
    await prefs.setStringList(schluessel, ClassNames.sortiert(neu));

    await VPlanAPI().removeHiddenCoursesForClass(classId);
    await VPlanAPI().removeClassName(classId);
  }
}

/// Eine Klasse zur Übersicht hinzufügen.
///
/// Zeigt [SelectClass] und sonst nichts.
///
/// Wird geöffnet über `PlanWerkzeugRoute` in Swift – also von der nativen
/// Plan-Übersicht aus, und **nicht** über den Kanal.
///
/// ## Warum der Bildschirm nicht selbst weitergeht
///
/// [SelectClass] hängt an die Stelle von sich die **Kursauswahl** – deshalb steht
/// hier kein `Navigator.pop`, wenn die Klasse gewählt wurde. Ein Pop von hier
/// würde den Bildschirm mitten in diesem Übergang wegnehmen, und die Kurswahl
/// hinge in der Leere.
///
/// Stattdessen wird nur geschickt: [PlanNativeBridge.publishPlan] holt die
/// Klassen neu, und die native Übersicht zeigt sie an.
class KlasseHinzufuegen extends StatefulWidget {
  const KlasseHinzufuegen({super.key});

  @override
  State<KlasseHinzufuegen> createState() => _KlasseHinzufuegenState();
}

class _KlasseHinzufuegenState extends State<KlasseHinzufuegen> {
  /// Die Klassen, die schon da sind – damit [SelectClass] sie anhaken kann.
  List<String> _haben = <String>[];

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> drin = prefs.getStringList(
            SchoolStorage.scopedKey(prefs, 'classes')) ??
        <String>[];
    if (!mounted) return;
    setState(() => _haben = drin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectClass(
        favs: _haben,
        pop: (String _) => unawaited(PlanNativeBridge.publishPlan()),
      ),
    );
  }
}

/// Eine Person zur Übersicht hinzufügen.
///
/// Drei Schritte, in derselben Reihenfolge wie in `_VPlanState._openAddPerson`:
/// Klasse wählen, Name eingeben, Kurse wählen.
///
/// ## Warum der Bildschirm **selbst** den Ablauf startet
///
/// Weil er sonst eine leere Seite wäre, die auf einen Knopfdruck von aussen
/// wartet – und niemand ist da, der drücken könnte. Er wird über
/// `PlanWerkzeugRoute` geöffnet, und das kommt aus einer Bildschirmreihe, in der
/// es nichts zu drücken gibt.
///
/// Deshalb startet der Ablauf **nach dem ersten Bild** (`addPostFrameCallback`):
/// `Navigator` ist in `initState` noch nicht bereit, und ein `push` dort geht
/// entweder in die Leere oder wirft.
class PersonHinzufuegen extends StatefulWidget {
  const PersonHinzufuegen({super.key});

  @override
  State<PersonHinzufuegen> createState() => _PersonHinzufuegenState();
}

class _PersonHinzufuegenState extends State<PersonHinzufuegen> {
  /// Was im Namensfeld als Vorschlag steht.
  ///
  /// Gehört zum Ablauf und nicht zum Bildaufbau: Es ändert sich einmal, und eine
  /// Änderung würde sonst einen zweiten Aufbau des ganzen Bildschirms auslösen –
  /// mitten im Dialog.
  String _vorschlag = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_starten()));
  }

  Future<void> _starten() async {
    // Schritt 1: die Klasse.
    //
    // [SelectClass] schliesst sich selbst, sobald sich jemand für eine
    // entschieden hat – deshalb wird hier **nicht** noch einmal
    // zurückgesprungen, sondern das Ergebnis über einen [Completer] geholt.
    final Completer<String?> gewaehlt = Completer<String?>();
    unawaited(
      Navigator.push(
        context,
        SwipePageTransition(
          type: PageTransitionType.rightToLeft,
          child: Scaffold(
            body: SelectClass(
              personMode: true,
              favs: <String>[],
              pop: (String klasse) {
                if (!gewaehlt.isCompleted) gewaehlt.complete(klasse);
              },
            ),
          ),
        ),
      ).then((_) {
        // Ohne Auswahl abgebrochen: Dann ist der Bildschirm zurück, und ohne
        // diesen zweiten Schritt würde [gewaehlt] **nie** fertig – der Ablauf
        // stünde still, ohne dass irgendwo ein Fehler stünde.
        if (!gewaehlt.isCompleted) gewaehlt.complete(null);
      }),
    );

    final String? className = await gewaehlt.future;
    if (className == null || className.isEmpty || !mounted) return;

    // Schritt 2: der Name. Leer gelassen heisst „so heisst die Klasse" – dieselbe
    // Regel wie in `_resolvePersonName`.
    final String? eingegeben = await _frageNachName(className);
    if (eingegeben == null || !mounted) return;

    final VPlanAPI api = VPlanAPI();
    final String eintrag = eingegeben.trim();
    final String basis =
        eintrag.isNotEmpty ? eintrag : await api.getClassName(className) ?? className;
    final List<Map<String, dynamic>> alle = await api.getPersons();
    // `uniquePersonName` ist statisch – sie hängt an der Klasse und nicht an
    // einem Datensatz, denn sie vergleicht die Namen **aller** Personen.
    final String name = VPlanAPI.uniquePersonName(
      basis,
      alle
          .where((Map<String, dynamic> p) =>
              p['classId']?.toString() == className)
          .map((Map<String, dynamic> p) => p['name']?.toString() ?? ''),
    );

    // Schritt 3: die Kurse. `isNew: true` heisst: [PersonCourses] legt die
    // Person selbst an, sobald gespeichert wird – hier wird also **nicht**
    // noch einmal gespeichert.
    await Navigator.push(
      context,
      SwipePageTransition(
        type: PageTransitionType.rightToLeft,
        child: Scaffold(
          body: PersonCourses(
            classId: className,
            person: <String, dynamic>{
              'id': '${AppClock.now().millisecondsSinceEpoch}',
              'name': name,
              'classId': className,
              'courses': <String>[],
            },
            isNew: true,
          ),
        ),
      ),
    );

    await PlanNativeBridge.publishPlan();
    if (mounted) Navigator.of(context).pop();
  }

  /// Fragt nach dem Namen der neuen Person.
  ///
  /// ## Warum der Vorschlag **vorher** geholt wird
  ///
  /// Weil er ein `await` ist und `InputDecoration.hintText` keinen zulässt. Er
  /// steht deshalb in [_vorschlag]. Sonst stünde im Feld entweder gar nichts
  /// oder der Rohwert der Klasse, während [VPlan] dort den selbst vergebenen
  /// Anzeigenamen zeigt – zwei Bildschirme, die dasselbe Feld unterschiedlich
  /// füllen.
  Future<String?> _frageNachName(String className) async {
    _vorschlag = await VPlanAPI().getClassName(className) ?? className;
    if (!mounted) return null;

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController eingabe = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.personName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19),
        ),
        content: TextField(
          controller: eingabe,
          autofocus: true,
          decoration: InputDecoration(hintText: _vorschlag),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, eingabe.text.trim()),
            child: Text(
              l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Der Bildschirm zeigt **nichts**.
  ///
  /// Und das ist richtig: Er besteht aus drei Bildschirmen, die einer nach dem
  /// anderen **über** ihm aufgehen. Zwischen ihnen ist nichts zu sehen – ein
  /// Rahmen, ein Ladezeichen oder ein leerer Rand wären nur ein Bildschirm, der
  /// im Weg steht, während die eigentlichen Seiten daneben stehen.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}