import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/AppAppearance.dart';

/// Der Startbildschirm mit Animation.
///
/// ## Was hier läuft und warum gerade das
///
/// Gezeigt wird **das Logo, in Bewegung**: Der Kalender wird gezeichnet, und
/// in ihm dreht sich der Tauschring – die beiden Pfeile, die im Zeichen
/// „A ersetzt B" bedeuten. Genau das ist auch, was die App beim Start tut: Sie
/// lädt den Stand von gestern und macht daraus den von heute. Eine Animation,
/// die etwas anderes zeigt – ein kreisender Balken, ein flatterndes Blatt –
/// wäre hübsch, aber sie erzählt nichts über die App. Der Tauschring tut es.
///
/// Die Formen sind **keine Bilder**, sondern gerechnet: Dasselbe Dreieck mit
/// derselben Spitze wie im App-Icon, nur in der Grösse des Bildschirms
/// ([_ringpfad]). Sonst wäre das hier eine zweite Wahrheit: Ändert sich das
/// Icon, sieht der Startbildschirm weiterhin das alte.
///
/// ## Warum das ein Flügelschirm ist und nicht der Startbildschirm des Systems
///
/// Der des Systems kann nur ein Standbild zeigen – auf Android ab 12 gar keins
/// mehr, dort ist es das App-Icon. Ein Bildschirm, auf dem app-eigenes Zeichnen
/// passiert, gehört in die App: Erst dann kann er die Animation zeigen, und
/// er kennt das Theme, in dem die App danach startet. Siehe
/// `SplashGate` für den Übergang.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Wie lange der Startbildschirm ausblendet.
///
/// Kurz, weil sie **auf** der Uhr des Nutzers liegt: In dieser Zeit ist die
/// App schon da und schon benutzbar – sie wartet nur noch darauf, dass etwas
/// durchsichtig wird. Wer eine halbe Sekunde wartet, bis er tippen kann, wird
/// die App als träge in Erinnerung behalten, obwohl sie längst bereit war.
const Duration kSplashAusblenden = Duration(milliseconds: 260);

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Der Kalender wird gezeichnet, und **halb so lange** dauert es, bis der
  /// Schriftzug losgeht – beides hängt an diesem einen Controller.
  ///
  /// Zweimal die Zeit, die das Zeichnen allein braucht: Der Wert springt dann
  /// in der Mitte durch 0,5, und an diesem Punkt startet der Schriftzug. So
  /// gibt es für die Reihenfolge nur eine einzige Zeitangabe im ganzen
  /// Bildschirm – man kann sie nicht an einer Stelle ändern und an der anderen
  /// vergessen.
  late final AnimationController _zeichnen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1240),
  )..forward();

  /// Der Ring dreht sich weiter, bis der Bildschirm geht.
  ///
  /// Ohne Pause: Der Ring steht nie still. Eine Animation, die fertig ist und
  /// dann wartet, wirkt wie das eingefrorene Standbild, das sie eigentlich
  /// ablösen soll.
  late final AnimationController _drehen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  /// Der Schriftzug kommt zuletzt – er ist das Letzte, was man noch liest.
  late final AnimationController _schrift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  Brightness _helligkeit = Brightness.dark;

  @override
  void initState() {
    super.initState();
    _leseTheme();
    // Der Schriftzug wartet, bis der Kalender **halb** steht – nicht, bis er
    // fertig ist: Wer erst am Ende liest, liest den Namen zu spät, und
    // beides im selben Bild bedeutet, dass nichts aufeinander wirkt.
    //
    // Das Warten hängt an [_zeichnen] statt an einem `Future.delayed`: Ein
    // `Future.delayed` ist ein Timer, und der läuft weiter, auch wenn der
    // Bildschirm schon weg ist. Er kommt dann in eine `dispose`-Leere und
    // feuert in ein Widget, das nicht mehr im Baum ist.
    _zeichnen.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        _schrift.forward();
      }
    });
  }

  @override
  void dispose() {
    _zeichnen.dispose();
    _drehen.dispose();
    _schrift.dispose();
    super.dispose();
  }

  /// Liest die themes Einstellung und stellt sich darauf ein.
  ///
  /// Der Startbildschirm ist die **erste** Farbe, die der Nutzer sieht. Sie
  /// muss die sein, in der die App danach startet – sonst blinkt der
  /// Bildschirm einmal in der falschen Helligkeit, und genau dieses Blinken
  /// ist das, was man sich beim Start einer App am ehesten merkt.
  ///
  /// `SharedPreferences` ist hier schon im Speicher, der Start liest es vorher
  /// ohnehin. Vor dem ersten Bild steht deshalb der dunkle Standard: Das ist
  /// auch der, den die App benutzt, wenn noch nichts eingestellt ist.
  Future<void> _leseTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String wert = AppAppearance.themeOf(prefs);
    if (wert == AppAppearance.light) {
      setState(() => _helligkeit = Brightness.light);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dunkel = _helligkeit == Brightness.dark;

    // Die Farben stehen hier und nicht im Theme: Dieser Bildschirm baut **kein**
    // Theme auf (es gibt noch keins, die Einstellung wird ja gerade gelesen),
    // und er darf nicht auf eines warten – sonst käme er genau dann, wenn die
    // App startet, und nicht vorher.
    final Color grund =
        dunkel ? SplashFarben.grundDunkel : SplashFarben.grundHell;
    final Color zeichen = dunkel ? SplashFarben.weiss : SplashFarben.schwarz;
    final Color ring = dunkel ? SplashFarben.ringDunkel : SplashFarben.ringHell;

    // Das `Directionality` steckt im Bildschirm und nicht nur im `SplashGate`,
    // das ihn benutzt: Dieser Bildschirm ist der oberste der App und bekommt
    // von keinem `MaterialApp` eines – es gibt beim Start noch keins. Der
    // Schriftzug ist ein `RichText`, und der verlangt eine Leserichtung.
    //
    // `ltr` ist hier richtig und nicht etwa ein Fehler: Die App ist in Deutsch
    // und Englisch übersetzt, beide schreiben von links nach rechts. Eine
    // falsche Richtung wäre nur dann ein Fehler, wenn sie jemand liest, der
    // rechts nach links liest – und dann ist es ein Fehler in einer Stelle,
    // die man noch nicht kennt.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: grund,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints raum) {
            // Das Zeichen ist 608 von 1024 Einheiten breit – für eine sichtbare
            // Kalenderbreite von etwa einem Drittel des kleineren Bildschirmrandes
            // braucht es also eine Box, die gut das Doppelte ist. Die Klammern
            // halten sie auf einem kleinen Telefon hineinpassend und auf einem
            // Tablet davon fern, den halben Bildschirm einzunehmen.
            final double kante = math.min(raum.maxWidth, raum.maxHeight);
            final double groesse = kante.clamp(210.0, 300.0);

            // `Center` und nicht `Stack`: Das `Stack` gab es nur, weil die
            // Zeichnung einmal überlagert werden sollte – der Schriftzug steht
            // jetzt unter ihr, und für eine einzige Spalte braucht es keinen
            // Stapel. Vor allem aber: Ein `Stack` will ohne `Directionality` über
            // ihm eine Ausrichtung auflösen, und der Startbildschirm baut sie
            // nicht auf (es gibt noch kein `MaterialApp`). Genau daran ist die
            // erste Fassung gescheitert.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: groesse,
                    height: groesse,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _zeichnen,
                        _drehen,
                      ]),
                      builder: (BuildContext context, Widget? _) => CustomPaint(
                        painter: _SplashMaler(
                          // Nur die **erste Hälfte** des Controllers ist das Zeichnen,
                          // die zweite die Pause, in der der Kalender fertig steht
                          // und der Schriftzug noch nicht da ist. Ohne dieses
                          // `clamp` finge der Kalender am Ende noch einmal von
                          // vorn an.
                          aufbau: (_zeichnen.value * 2).clamp(0.0, 1.0),
                          drehung: _drehen.value,
                          zeichen: zeichen,
                          ring: ring,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: groesse * 0.16),
                  _Schriftzug(
                    animation: _schrift,
                    farbe: zeichen.withValues(alpha: 0.92),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Die Farben des Startbildschirms.
///
/// Sie stehen hier als eigene Klasse und nicht verstreut im Aufbau, weil sie an
/// **zwei** Stellen gebraucht werden: hier und in [SplashGate], das denselben
/// Grund für den Übergang braucht – sonst stünde für einen Bildschirm lang
/// der alte, dann der neue Hintergrund, und man sähe es.
class SplashFarben {
  const SplashFarben._();

  /// Der Grund der App im Dunkeln – derselbe Wert wie in `main.dart`.
  /// *Nicht* `scaffoldBackgroundColor`: Das ist der Grund **hinter** den
  /// Karten, und der ist noch einmal dunkler. Der Startbildschirm ist die
  /// Fläche, auf der noch keine Karte liegt – also der Grund selbst.
  static const Color grundDunkel = Color(0xff1e1f25);

  /// Der Grund der App im Hellen.
  static const Color grundHell = Color(0xfff5f5f8);

  static const Color weiss = Colors.white;

  /// Fast Schwarz statt Reinweiss: Reinweiss ist im Hellen zu grell, und der
  /// Kalender ist eine grosse Fläche.
  static const Color schwarz = Color(0xff1b1b1f);

  /// Der Ring im Dunkeln – der Akzent der App.
  static const Color ringDunkel = Color(0xffAF69EE);

  /// Im Hellen der **dunklere** Akzent, aus demselben Grund wie in `main.dart`:
  /// Der helle Akzent verschwindet auf weissem Grund.
  static const Color ringHell = Color(0xff7d43c4);
}

/// Der Schriftzug unter dem Zeichen.
///
/// Er ist ein eigenes Widget, weil er die **einzige** Stelle ist, an der eine
/// eigene Schrift steht. `Crackman` ist die Handschrift, in der die App ihren
/// Namen schreibt (siehe `introscreen.dart`) – der Startbildschirm soll mit der
/// Seite, die danach kommt, aussehen wie aus einem Haus.
class _Schriftzug extends StatelessWidget {
  const _Schriftzug({required this.animation, required this.farbe});

  final Animation<double> animation;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Nicht nur blenden: Der Schriftzug steigt um ein Stück. Blenden allein
      // ist an einem Bildschirm, der ohnehin nur kurz steht, zu wenig – die
      // Bewegung ist das, was den Übergang zum Bildschirm danach vorbereitet.
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, 14 * (1 - animation.value)),
          child: child,
        ),
        child: Text(
          'Substitute',
          style: TextStyle(
            fontFamily: 'Crackman',
            fontSize: 34,
            color: farbe,
          ),
        ),
      ),
    );
  }
}

/// Zeichnet den Kalender und den drehenden Tauschring.
///
/// Der Kalender wird **nicht gefüllt**, sondern als Kontur gezeichnet – und
/// zwar Stück für Stück ([_pfadFortschritt]). Das ist der Teil, der sagt
/// „es wird etwas aufgebaut".
class _SplashMaler extends CustomPainter {
  _SplashMaler({
    required this.aufbau,
    required this.drehung,
    required this.zeichen,
    required this.ring,
  });

  /// 0 bis 1: Wie weit der Kalender gezeichnet ist.
  final double aufbau;

  /// 0 bis 1: Eine volle Umdrehung des Rings.
  final double drehung;

  /// Die Farbe des Kalenders.
  final Color zeichen;

  /// Die Farbe des Tauschrings.
  final Color ring;

  /// Die Farbe, mit der der Kalender gestrichelt wird – 20 Einheiten breit,
  /// also halb so breit wie die Trennlinie im Icon. Dünner und die Zeichnung
  /// zerfällt in Linien, dicker und der Kalender wird zur Fläche.
  static const double _strich = 20;

  @override
  void paint(Canvas canvas, Size size) {
    // Der Kalender im Koordinatensystem des Icons (1024 Einheiten) – dieselben
    // Zahlen wie in `assets/icon/icon.svg`. Die Zeichnung wird am Ende auf die
    // tatsächliche Grösse umgerechnet, damit hier nichts vom Bildschirm steht.
    const double einheit = 1024;
    final double s = size.shortestSide / einheit;
    canvas
      ..save()
      ..translate(
        (size.width - einheit * s) / 2,
        (size.height - einheit * s) / 2,
      )
      ..scale(s);

    _maleKalender(
        canvas,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strich
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = zeichen);

    _maleRing(canvas);

    canvas.restore();
  }

  /// Zeichnet den Kalender, aber nur so weit, wie [aufbau] reicht.
  ///
  /// Zwei Durchgänge, und sie sind nicht gleich: Der **Umriss** des Kalenders
  /// wird als Kontur gezeichnet und von oben nach unten aufgebaut. Die
  /// **Trennlinie** unter der Kopfzeile dagegen ist eine Fläche, keine
  /// Kontur – als Kontur gezeichnet wäre sie ein Band, dessen Ränder man
  /// sieht, statt der Fläche, die man im Icon sieht. Sie wächst deshalb von
  /// der Mitte aus nach links und rechts, was zugleich der richtigen
  /// Richtung entspricht: Die Trennlinie zieht sich quer über den Kalender.
  void _maleKalender(Canvas canvas, Paint kontur) {
    final Path pfad = Path()
      // Die beiden Aufhängungen zuerst: Der Leser sieht eine Bewegung, die
      // oben beginnt, und der Kalender baut sich dann darunter auf – wie ein
      // Kalender, den man aufhängt.
      ..addRRect(RRect.fromLTRBR(352, 210, 408, 340, const Radius.circular(28)))
      ..addRRect(RRect.fromLTRBR(616, 210, 672, 340, const Radius.circular(28)))
      ..addRRect(
          RRect.fromLTRBR(208, 250, 816, 774, const Radius.circular(96)));

    _pfadFortschritt(canvas, pfad, aufbau, kontur);

    // Die Trennlinie: Von 208 bis 816, 20 Einheiten hoch, in der Mitte
    // gerundet – dieselben Zahlen wie im Icon. Sie beginnt bei einem Drittel
    // des Aufbaus, weil vorher die Form des Kalenders noch gar nicht steht und
    // ein Strich quer durch nichts nichts bedeutet.
    final double trenn = ((aufbau - 0.35) / 0.65).clamp(0.0, 1.0);
    if (trenn <= 0) return;
    // `y = 380`, `height = 20` – dieselben Zahlen wie im Icon, also liegt die
    // Mitte bei 390 und nicht bei 380. Hier steht die Mitte, weil sie die
    // bequemere Zahl ist: Von hier aus nach oben und unten je die Hälfte.
    const double mitteX = 512;
    const double mitteY = 390;
    const double hoehe = 20;
    final double breite = 608 * trenn / 2;
    final Rect streifen = Rect.fromLTRB(
      mitteX - breite,
      mitteY - hoehe / 2,
      mitteX + breite,
      mitteY + hoehe / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(streifen, const Radius.circular(hoehe / 2)),
      Paint()..color = kontur.color,
    );
  }

  /// Zeichnet [pfad] bis zum Anteil [anteil] seiner Länge.
  ///
  /// Ohne das gäbe es kein Zeichnen, sondern nur Ein- und Ausblenden. Die
  /// Strecke, auf der der Strich gerade liegt, ist der eigentliche Reiz: Man
  /// sieht den Kalender entstehen.
  ///
  /// Die Anzahl der Striche wird gerundet, damit der Fortschritt in
  /// gleichmässigen Schritten geht. `computeMetrics` kann bei dieser Form vier
  /// Stücke liefern (zwei Aufhängungen, Kalender, Trennlinie); jedes wird um
  /// denselben Anteil gekürzt, und dadurch wandert der Strich über alle vier
  /// hinweg statt nur über dem ersten.
  void _pfadFortschritt(
    Canvas canvas,
    Path pfad,
    double anteil,
    Paint farbe,
  ) {
    if (anteil <= 0) return;
    for (final PathMetric m in pfad.computeMetrics()) {
      final double lang = m.length * anteil.clamp(0.0, 1.0);
      if (lang <= 0) continue;
      canvas.drawPath(m.extractPath(0, lang), farbe);
    }
  }

  /// Zeichnet den Tauschring und dreht ihn dabei.
  void _maleRing(Canvas canvas) {
    final Offset mitte = const Offset(512, 587);

    canvas
      ..save()
      ..translate(mitte.dx, mitte.dy)
      // Der Ring dreht sich um **seine** Mitte, nicht um die Mitte der Fläche:
      // Sonst würde er aus seinem Kalender wandern.
      ..rotate(drehung * 2 * math.pi)
      ..translate(-mitte.dx, -mitte.dy)
      ..drawPath(
        _ringpfad(mitte),
        Paint()
          ..style = PaintingStyle.fill
          ..color = ring,
      )
      ..restore();
  }

  /// Der Tauschring: zwei Bögen über je eine Ringhälfte, jeder mit einer Spitze.
  ///
  /// Die Zahlen sind dieselben wie im App-Icon – Radius 126, Dicke 64, Spitzen
  /// 92 breit und 74 lang, Mitte (512, 587) – nur als [_pfeilpfad] gerechnet
  /// statt als Zahlenkolonne im SVG. Wer hier etwas ändert, sollte es dort auch
  /// ändern: Das Icon und der Startbildschirm sollen dasselbe Zeichen sein.
  static Path _ringpfad(Offset mitte) {
    // Die beiden Bögen: jeweils 128 Grad. Die restlichen 52 Grad oben und
    // unten bleiben frei, damit die Spitzen sich nicht in die Füsse laufen –
    // dieselbe Überlegung wie im Icon.
    final Path p = Path()
      ..addPath(_pfeilpfad(mitte, _winkel(116), _winkel(244)), Offset.zero)
      ..addPath(_pfeilpfad(mitte, _winkel(296), _winkel(424)), Offset.zero);
    return p;
  }

  static double _winkel(double grad) => grad * math.pi / 180;

  static Offset _pol(Offset mitte, double radius, double winkel) => Offset(
        mitte.dx + radius * math.cos(winkel),
        mitte.dy + radius * math.sin(winkel),
      );

  /// Ein Pfeil: ein Bogen von [von] bis [bis] mit einer Spitze am Ende.
  ///
  /// Der Bogen läuft auf dem **Aussen**radius hin und auf dem Innenradius
  /// zurück – so entsteht das Band. Die Spitze ist ein Dreieck, dessen Grund
  /// auf der Verbindungslinie der beiden Bogenenden steht und damit senkrecht
  /// zur Fahrtrichtung liegt; es ist breiter als das Band (92 gegen 64), weil
  /// ein Dreieck, das genau so breit ist wie sein Schaft, aussieht wie eine
  /// Nadel.
  static Path _pfeilpfad(Offset mitte, double von, double bis) {
    const double radius = 126;
    const double dicke = 64;
    const double spitzenBreite = 92;
    const double spitzenLaenge = 74;
    const double aussen = radius + dicke / 2;
    const double innen = radius - dicke / 2;

    final Offset e = _pol(mitte, radius, bis);
    // Die Richtung, in die der Pfeil zeigt: senkrecht zum Radius, im
    // Uhrzeigersinn – so wie die Fahrtrichtung des Bogens.
    final Offset radial = Offset(math.cos(bis), math.sin(bis));
    final Offset vor = Offset(-math.sin(bis), math.cos(bis));

    Offset spitze(Offset richtung, double betrag) => e + richtung * betrag;

    final Path p = Path()
      ..moveTo(
        _pol(mitte, aussen, von).dx,
        _pol(mitte, aussen, von).dy,
      );
    p
      ..arcToPoint(
        _pol(mitte, aussen, bis),
        radius: const Radius.circular(aussen),
        clockwise: true,
      )
      ..lineTo(spitze(radial, spitzenBreite / 2).dx,
          spitze(radial, spitzenBreite / 2).dy)
      ..lineTo(spitze(vor, spitzenLaenge).dx, spitze(vor, spitzenLaenge).dy)
      ..lineTo(spitze(radial, -spitzenBreite / 2).dx,
          spitze(radial, -spitzenBreite / 2).dy)
      ..lineTo(_pol(mitte, innen, bis).dx, _pol(mitte, innen, bis).dy)
      ..arcToPoint(
        _pol(mitte, innen, von),
        radius: const Radius.circular(innen),
        clockwise: false,
      )
      ..close();
    return p;
  }

  @override
  bool shouldRepaint(_SplashMaler alt) =>
      alt.aufbau != aufbau ||
      alt.drehung != drehung ||
      alt.zeichen != zeichen ||
      alt.ring != ring;
}

/// Der Rahmen, in dem der Startbildschirm steht.
///
/// Er macht zwei Sachen, die ohne ihn nicht gingen:
///
/// * Er hält den [SplashScreen], **bis die App wirklich da ist**, und blendet
///   ihn dann weg.
/// * Er blendet den Startbildschirm **über** die App weg, statt ihn zu
///   ersetzen. Ein Ersetzen sähe man als einen Sprung; so sieht man eine
///   Überblendung, und die App ist schon gebaut und schon benutzbar, während
///   der Startbildschirm noch auf ihr steht.
///
/// ## Er hält den Startbildschirm **nicht** künstlich fest
///
/// Es gab hier eine Mindestzeit von 1,5 Sekunden, mit der Begründung, eine
/// Animation müsse auch zu sehen sein. Das war falsch, und zwar auf zwei
/// Arten:
///
/// * **Es wartet jemand, der nichts dafür kann.** Die Zeit zwischen dem Tippen
///   auf das Icon und dem fertigen Plan ist genau das, was über die Trägheit
///   einer App entscheidet. Eine Sekunde davon zu verschenken, damit eine
///   Bewegung hübscher aussieht, ist ein Tausch gegen nichts.
/// * **Man sieht die Animation auch so.** Sie läuft während des Ladens, und
///   das Laden ist nicht auf 100 Millisekunden zu drücken. Sie ist nur
///   kürzer, wenn das Laden schnell ist – und dann war es ohnehin kein
///   langsamer Start.
///
/// Die App wartet jetzt also **nur** noch auf ihr eigenes Laden. Wer schnell
/// startet, bekommt eine schnellere App; wer langsam lädt, sieht die Animation
/// länger – und das ist genau die richtige Richtung.
///
/// Der Bildschirm wird nicht über eine Route eingeblendet, sondern als
/// `Stack` **über** der App. Grund: Die App bringt ihr eigenes `MaterialApp`
/// mit, und zwei davon in einer `AnimatedSwitcher`-Kette zu haben ist eine
/// bekannte Fehlerquelle (der ausscheidende Navigator wird abgebaut, während
/// er noch eingeblendet wird). Im `Stack` wird nur eine harmslose Fläche
/// ausgeblendet.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.starten});

  /// Holt die App. Das Ergebnis ist der ganze Bildschirm, der nach dem
  /// Startbildschirm dasteht – also in der Regel ein `MaterialApp`.
  final Future<Widget> Function() starten;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ausblenden = AnimationController(
    vsync: this,
    duration: kSplashAusblenden,
  );

  /// Die App, sobald sie fertig geladen ist. Vorher `null` – dann steht
  /// allein der Startbildschirm.
  Widget? _app;

  /// Der Fehler, falls das Laden scheitert. Solange er hier steht, wird statt
  /// der App eine Fehlermeldung gezeigt – **nicht** der Startbildschirm
  /// weiter.
  ///
  /// Warum das wichtig ist: Ein Fehler im Laden, der einfach verschluckt
  /// würde, ließe den Startbildschirm für immer stehen. Der Nutzer drückt auf
  /// das Icon, sieht eine Animation, und nach einer Sekunde ist sie weg. Er
  /// wiederholt es, mit demselben Ergebnis. Das fühlt sich nicht wie ein
  /// Fehler an, sondern wie eine App, die kaputt ist – und ist damit
  /// schlimmer als ein Absturz, weil man ihn nicht suchen würde.
  Object? _fehler;

  /// Ob der Startbildschirm ganz weg darf. Er wird erst **nach** dem
  /// Ausblenden entfernt: Würde er vorher weggenommen, wäre die Blende eine
  /// Einblendung ins Nichts, also ein kurzer schwarzer oder heller Fleck.
  bool _weg = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void dispose() {
    _ausblenden.dispose();
    super.dispose();
  }

  Future<void> _laden() async {
    final Widget app;
    try {
      app = await widget.starten();
    } catch (fehler) {
      // Siehe [_fehler]: Der Startbildschirm darf nicht weiterlaufen, als
      // wäre nichts geschehen. Die Meldung ist auf Deutsch und ohne
      // Fachsprache, denn wer hier landet, hat kein Android-Gerät vor sich,
      // auf dem er nachsehen könnte, sondern nur diese eine Zeile.
      //
      // `debugPrint` trotzdem: Der vollständige Fehler mit Stack gehoert in
      // das Log, nicht auf den Bildschirm. Wer die App gebaut hat, findet ihn
      // dort.
      debugPrint('Start: die App liess sich nicht laden – $fehler');
      if (mounted) setState(() => _fehler = fehler);
      return;
    }
    if (!mounted) return;

    // Die App wird gebaut und **sofort** sichtbar gemacht – es wird nicht
    // gewartet. Sie steht hinter dem Startbildschirm, baut ihren ersten
    // Bildschirm also schon auf, während dieser noch steht: Warten mit dem
    // Aufbauen hiesse, dass nach dem Ausblenden erst noch die App gebaut wird,
    // und genau das ist der Moment, in dem man einen Ruckler sähe.
    setState(() => _app = app);

    await _ausblenden.forward();
    if (!mounted) return;
    setState(() => _weg = true);
  }

  @override
  Widget build(BuildContext context) {
    final Object? fehler = _fehler;
    if (fehler != null)
      return _Fehlerbildschirm(grund: SplashFarben.grundDunkel);

    final Widget? app = _app;
    if (app == null) return const SplashScreen();

    return Stack(
      // `alignment.topLeft` und nicht der Standard `topStart`: Der Standard
      // ist richtungsabhängig und würde ohne `Directionality` über der App
      // stehen – und über einer App, die ihre mitbringt, weiss man ihre
      // Leserichtung hier noch nicht.
      alignment: Alignment.topLeft,
      children: [
        app,
        if (!_weg)
          Positioned.fill(
            child: IgnorePointer(
              // Der Startbildschirm nimmt keine Eingabe an, solange er
              // sichtbar ist: Ein Tippen geht an die App darunter, nicht an
              // eine Fläche, die es gleich nicht mehr gibt.
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0).animate(_ausblenden),
                child: SplashScreen(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Was der Nutzer sieht, wenn das Laden nicht gelingt.
///
/// Ohne den Fehler im Text: **Eine** Zeile, und die ist übersetzt. Der
/// vollständige Fehler steht im Log – für jemanden, der die App nicht gebaut
/// hat, ist ein Stacktrace wertlos, und eine Bildschirmhälfte Text auf Deutsch
/// wäre es in einer englischen App erst recht.
///
/// Der Grund ist derselbe wie der des Startbildschirms, damit der Übergang von
/// ihm hierher keine Kante hat.
class _Fehlerbildschirm extends StatelessWidget {
  const _Fehlerbildschirm({required this.grund});

  final Color grund;

  @override
  Widget build(BuildContext context) => Directionality(
        // Wie im Startbildschirm: Dieser Bildschirm ist der oberste der App,
        // und es gibt beim Start noch kein `MaterialApp`, das eine
        // Leserichtung mitbringen würde.
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: grund,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Substitute',
                    style: TextStyle(
                      fontFamily: 'Crackman',
                      fontSize: 34,
                      color: SplashFarben.weiss,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Die App konnte nicht geladen werden. Bitte neu starten.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SplashFarben.weiss, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
