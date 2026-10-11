import 'package:flutter/material.dart';

/// Die Ladeanzeige des Vertretungsplans.
///
/// **Drei Punkte, die nacheinander auf- und abschwingen** – bewusst mehr als
/// ein kreisender Balken: Der Plan lädt an vielen Stellen (Öffnen, Tagessprung,
/// Wochensprung, Pull-to-Refresh), und eine deutliche, in sich geschlossene
/// Bewegung ist schneller als ein sich drehendes Rad zu erkennen als „es
/// arbeitet gerade".
///
/// Eine eigene [StatefulWidget] mit [AnimationController] statt einer
/// `Lottie`-Datei: Sie passt sich der Theme-Farbe an, braucht kein Asset und
/// lässt sich überall einsetzen – Tagesansicht, Wochenansicht, Kursauswahl.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    Key? key,
    this.size = 34,
    this.color,
  }) : super(key: key);

  /// Gesamtbreite der Anzeige (Punkte und Abstand).
  final double size;

  /// Farbe der Punkte. Standard: die Theme-Akzentfarbe.
  final Color? color;

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? Theme.of(context).primaryColor;
    final double dotSize = widget.size * 0.26;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                _bouncingDot(i, dotSize, color),
            ],
          );
        },
      ),
    );
  }

  /// Ein einzelner Punkt. Jeder Punkt ist um ein Drittel der Laufzeit
  /// versetzt – dadurch laufen sie wellenförmig statt alle gleichzeitig.
  Widget _bouncingDot(int index, double dotSize, Color color) {
    // 0.0 … 1.3: Das Fenster des Punktes, um 1/3 des Kreises verschoben.
    final double start = index / 3;
    final double phase = (_controller.value + start) % 1.0;

    // 0 → 1 → 0 innerhalb des Fensters; dazwischen ist der Punkt unten.
    final double t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;

    return Transform.translate(
      // Der Punkt hebt sich an und federt zurück.
      offset: Offset(0, -widget.size * 0.16 * _curve(t)),
      child: Opacity(
        // Beim Absinken blendet er aus, damit die Bewegung wie ein Laufweg
        // wirkt und nicht wie ein Blinken.
        opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.7 + 0.3 * t,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Weiches Anheben statt linearer Bewegung – wie ein federnder Punkt.
  double _curve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 0;
    // Auf- und abwärts getrennt: hin schnell, zurück langsamer.
    return t < 0.5 ? (t * 2) * (t * 2) : (1 - (t - 0.5) * 2);
  }
}

/// Die Ladeanzeige als Zeile für eine Seite – mit gleichmäßigem Abstand
/// darüber und darunter, damit sie nicht am Inhalt klebt.
class LoadingIndicatorBlock extends StatelessWidget {
  const LoadingIndicatorBlock({
    Key? key,
    this.size = 34,
    this.padding = const EdgeInsets.symmetric(vertical: 18),
  }) : super(key: key);

  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(child: LoadingIndicator(size: size)),
    );
  }
}