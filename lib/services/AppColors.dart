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

  // ---------------------------------------------------------------- geändert

  /// Die Fläche einer Stunde, die **nur geändert** wurde: anderer Lehrer,
  /// anderes Fach oder anderer Raum.
  ///
  /// Bewusst **orange statt rot**, und das ist der ganze Unterschied. Rot heißt
  /// in dieser App "fällt aus" – daran hat sich das Auge gewöhnt. Eine
  /// Vertretung oder eine Raumänderung ist aber keine Ausfallstunde, und sie in
  /// derselben Farbe zu zeigen, hat zwei Folgen: Der Plan wirkt voller
  /// Ausfälle, als es sind, und das Auge lernt, Rot zu überlesen – gerade die
  /// Zeile, auf die es ankommt. Die Abstufung ist billig und macht die beiden
  /// Sortierarten überhaupt erst unterscheidbar.
  ///
  /// Die Werte folgen denselben Regeln wie [hinweisFlaeche]: kräftige Fläche,
  /// [hinweisText] darauf, und im dunklen Modus dieselbe Deckkraft wie das Rot.
  static Color aenderungFlaeche(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xffb35c00)
          : const Color.fromARGB(158, 156, 106, 20);

  /// Die Fläche einer Hinweiszeile – je nachdem, ob sie ausgefallen oder nur
  /// geändert ist.
  ///
  /// [ton] ist bewusst verpflichtend: Nur wer vorher [hinweisTonVon] gefragt
  /// hat, weiß die Antwort, und für `keiner` gibt es keine Fläche, sondern
  /// gar keine – die Zeile soll dann die Farbe der App behalten.
  static Color? hinweisFlaecheVon(BuildContext context, HinweisTon ton) =>
      switch (ton) {
        HinweisTon.entfall => hinweisFlaeche(context),
        HinweisTon.geaendert => aenderungFlaeche(context),
        HinweisTon.keiner => null,
      };

  /// Wie eine Stunde im Plan einzufärben ist.
  ///
  /// ## Die Regel
  ///
  /// * **Ausgefallen** ([HinweisTon.entfall]): Es steht ein Hinweistext im Plan
  ///   **und** die Stunde ist ausgefallen. Das ist der Fall, wenn **kein Lehrer
  ///   zugeordnet** ist – so meldet der VPlan eine Ausfallstunde: der Lehrer
  ///   wird geleert, und der Grund kommt in das Hinweisfeld. Damit derselbe
  ///   Fall auch dann als Ausfall erkannt wird, wenn der VPlan den Lehrer doch
  ///   noch mitliefert, zählt zusätzlich das Wort im Text ([_istAusfallText]).
  /// * **Geändert** ([HinweisTon.geaendert]): Es steht ein Hinweistext, aber
  ///   der Lehrer ist noch da – eine Vertretung, ein anderes Fach, ein anderer
  ///   Raum – **oder** der VPlan meldet eine Raumänderung (`placeChanged`).
  /// * Sonst nichts.
  ///
  /// ## Warum nicht "kein Lehrer" allein
  ///
  /// Der Hinweistext ist das, was den Unterschied macht: Er ist der Grund,
  /// warum der VPlan über diese Stunde überhaupt etwas sagt. Eine lehrerlose
  /// Stunde **ohne** Hinweistext ist nur eine Lücke, keine Ausfallstunde – und
  /// sie rot zu färben hieße, genau die Zeilen einzufärben, die man nicht
  /// meint.
  ///
  /// Eine reine Raumänderung kommt im VPlan **ohne** Hinweistext daher: Sie
  /// steckt im Attribut `RaAe` der Stunde und heißt in der Anzeige
  /// `placeChanged`. Deshalb steht sie bei den geänderten Zeilen und nicht bei
  /// den Ausfällen.
  static HinweisTon hinweisTonVon(Map<String, dynamic> lesson) {
    // Ein Hinweistext, der nur aus Leerzeichen besteht, ist keiner: Genau so
    // kommt er bei manchen Stunden an.
    final String info = (lesson['info'] ?? '').toString().trim();
    if (info.isNotEmpty) {
      if (!_hatLehrer(lesson) || _istAusfallText(info)) {
        return HinweisTon.entfall;
      }
      return HinweisTon.geaendert;
    }
    if (lesson['placeChanged'] == true) return HinweisTon.geaendert;
    return HinweisTon.keiner;
  }

  /// Steht im Hinweistext, dass die Stunde ausfällt?
  ///
  /// Bewusst **dieselbe** Prüfung wie `VPlanAPI.isCancelledLesson` – und
  /// bewusst trotzdem ein zweites Mal: Das Krankentracking zählt über jene
  /// Methode, und die Einfärbung des Plans darf nicht davon abhängen, ob eine
  /// andere Ebene der App geladen ist. Eine Stunde, die der Plan orange
  /// einfärbt und das Krankentracking als Ausfall behandelt, wäre
  /// widersprüchlich. Die beiden Stellen gehören zusammen geändert.
  static bool _istAusfallText(String info) {
    final String t = info
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    if (RegExp(r'\b(entfall|entfallt|entfaellt|ausfall|ausgefallen)\b')
        .hasMatch(t)) {
      return true;
    }
    return RegExp(r'\b(fallt|faellt)\b').hasMatch(t) &&
        RegExp(r'\baus\b').hasMatch(t);
  }

  /// true, wenn der Stunde ein Lehrer zugeordnet ist.
  ///
  /// `---` ist der Platzhalter, den die App selbst für "kein Wert" anzeigt
  /// (siehe `printValue`) – er darf nicht als Lehrer gelten.
  static bool _hatLehrer(Map<String, dynamic> lesson) {
    final String lehrer = (lesson['teacher'] ?? '').toString().trim();
    return lehrer.isNotEmpty && lehrer != '---';
  }
}

/// Wie auffällig eine Stunde im Plan ist.
///
/// Siehe [AppColors.hinweisTonVon] für die Regel, die das entscheidet.
enum HinweisTon {
  /// Nichts – die Stunde läuft wie jede andere.
  keiner,

  /// Nur **geändert**: anderer Lehrer, anderes Fach, anderer Raum.
  geaendert,

  /// **Ausgefallen** – kein Lehrer zugeordnet.
  entfall,
}
