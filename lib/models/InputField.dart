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
  }) : super(key: key);

  final TextEditingController controller;
  final TextInputType? keaboardType;
  final String labelText;

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
        controller: controller,
        keyboardType: keaboardType,
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