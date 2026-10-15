import 'package:flutter/material.dart';

/// Ein Eingabefeld im Stil der App – die beschriftete Fläche, in der die
/// anderen Felder der App stehen.
///
/// ## Warum hier kein `Center` und kein `alignment`
///
/// Beides macht aus dem Container ein `Align`, und ein `Align` **füllt den
/// ihm gegebenen Raum aus**, statt sich auf sein Kind zu beschränken. In einem
/// `AlertDialog` ist das der verfügbare Dialoginhalt – das Feld war dadurch
/// fast so hoch wie die ganze App, mit dem Text in der Mitte und einem
/// haushohen Rahmen drumherum. Besonders schlimm beim Sync-Code, weil der
/// Dialog dadurch auf dem Telefon nur noch aus einem Rahmen bestand.
///
/// Ohne die beiden wird der Container so hoch wie das Feld selbst, so breit
/// wie die Vorgabe – und der Text steht links, wie in jedem anderen
/// Eingabefeld der App.
class InputField extends StatelessWidget {
  const InputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.keaboardType,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  }) : super(key: key);

  final TextEditingController controller;
  final TextInputType? keaboardType;
  final String labelText;

  /// Wird bei jeder Eingabe aufgerufen – für Felder, deren Wert eine Anzeige
  /// direkt darunter steuert (etwa eine Suchzeile).
  final ValueChanged<String>? onChanged;

  /// Die Aktion der Tastatur, etwa `TextInputAction.search`.
  final TextInputAction? textInputAction;

  /// Wird beim Absenden ausgelöst (Tastatur oder Taste „Fertig"/„Suchen").
  final ValueChanged<String>? onSubmitted;

  final bool autofocus;

  /// Wohin die Tastatur springen soll, wenn das Feld den Fokus bekommt.
  ///
  /// Nötig, sobald ein Feld **auf Befehl** den Fokus bekommen soll – etwa wenn
  /// ein Schalter eingeschaltet wird und das dadurch sichtbar gewordene Feld
  /// ausfüllt werden soll. `autofocus` allein hilft dort nicht: Es gilt nur für
  /// das erste Feld der Seite.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(20),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: TextFormField(
        autocorrect: false,
        autofocus: autofocus,
        focusNode: focusNode,
        controller: controller,
        keyboardType: keaboardType,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: Theme.of(context).primaryColor,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}