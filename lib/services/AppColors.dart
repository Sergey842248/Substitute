import 'package:flutter/material.dart';

/// Die roten Farben der App – und zwar **je Theme**.
///
/// ## Warum überhaupt ein Dienst
///
/// Rot war an fünf Stellen fest als `Colors.red` bzw.
/// `Color.fromARGB(158, 119, 18, 18)` eingetragen. Beide Werte sind für den
/// dunklen Modus gewählt:
///
/// * `Colors.red` ist eine **Text**farbe für die dunkle Fläche. Auf Weiß
///   erreicht sie knapp 3,5:1 – sie ist lesbar, aber nicht angenehm.
/// * `Color.fromARGB(158, 119, 18, 18)` ist eine dunkelrote Fläche **mit
///   halber Deckkraft**. Der Text darauf erbt die Theme-Farbe, und die ist im
///   hellen Modus fast schwarz – fast schwarzer Text auf dunklem Rot ist
///   unlesbar, und die Fläche selbst sieht braun und schmutzig aus. Genau das
///   ist der gemeldete Fehler an den ausgefallenen Stunden.
///
/// ## Die Regel
///
/// **Zu jeder Fläche gehört eine Textfarbe, und beide richten sich nach dem
/// Theme.** Der Text auf einer farbigen Fläche wird nicht fest eingetragen,
/// sondern geerbt – deshalb muss die Fläche so beschaffen sein, dass die
/// geerbte Textfarbe darauf steht: hell genug für dunkle Schrift im hellen
/// Modus, dunkel genug für helle Schrift im dunklen.
///
/// Die Werte sind nicht einfach umgekehrt, sondern je nach Rolle gewählt und
/// am Kontrast gemessen (`test/app_colors_test.dart`).
class AppColors {
  const AppColors._();

  /// Rot für **Aktionstext** – „Löschen" in den Dialogen.
  ///
  /// Im dunklen Modus `Colors.red`, wie es immer war. Im hellen ein
  /// dunkleres Rot mit rund 5,6:1 auf Weiß: `Colors.red` verschwindet auf
  /// hellen Flächen zu einem Rosa, das man eher als Dekoration liest.
  static Color aktionston(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xffc62828)
          : Colors.red;

  /// Rot für **Fehlermeldungen** – der Text, der sagt, dass etwas nicht
  /// geklappt hat.
  ///
  /// Im dunklen Modus ein helleres Rot als der Aktionston, weil eine Meldung
  /// gelesen und nicht nur erkannt wird. Im hellen derselbe dunkle Ton wie
  /// beim Aktionston – dort ist `red.shade300` unlesbar hell (unter 2:1 auf
  /// Weiß, also flimmernd statt lesbar).
  static Color fehlerton(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xffc62828)
          : Colors.red.shade300;

  /// Die Fläche einer **Stunde mit Hinweistext** – „Entfall", „fällt aus",
  /// alles, was der VPlan in das Info-Feld schreibt.
  ///
  /// Der Text darauf bekommt [hinweisText] – er wird also **nicht** geerbt.
  /// Das ist der entscheidende Punkt, denn er löst den Widerspruch:
  ///
  /// Eine kräftige rote Fläche und schwarzer Text darauf schließen sich aus.
  /// Schwarz auf Rot kommt nicht über 1,5:1, und eine Fläche, auf der schwarzer
  /// Text gerade noch lesbar wäre, ist so blass, dass man die Stunde
  /// übersieht. Genau das sind die beiden Beschwerden gewesen: einmal „die
  /// schwarze Schrift ist nicht zu erkennen", einmal „man sieht das Rot
  /// kaum".
  ///
  /// Deshalb: kräftige Fläche, weißer Text. Das ist die übliche Lösung und
  /// sie hält beides aus – die Fläche ist auf den ersten Blick_rot, und die
  /// Schrift darauf steht bei über 4,5:1.
  ///
  /// **Im dunklen Modus** bleibt es bei der Deckkraft wie bisher: Über der
  /// dunklen Karte wird daraus ein dunkles Rot, auf dem die weiße Schrift
  /// steht. So sah es aus, und so bleibt es.
  static Color hinweisFlaeche(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xffc62828)
          : const Color.fromARGB(158, 119, 18, 18);

  /// Die Schriftfarbe auf der Hinweisfläche.
  ///
  /// Nur im hellen Modus eine eigene Farbe: Dort ist die Fläche kräftig, und
  /// die schwarze Schrift der App wäre darauf unlesbar – 1,54:1, gemessen.
  /// Im dunklen Modus ist die Fläche schwach, und die weiße Textfarbe der App
  /// steht darauf ohnehin.
  static Color hinweisText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : Theme.of(context).focusColor;
}
