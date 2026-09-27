import 'package:flutter/material.dart';

/// Einstellungs-Schalter mit Symbol, Titel und Erklärung – wie er in den
/// Einstellungsseiten (z.B. Plan-Einstellungen) mehrfach verwendet wird.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: SwitchListTile(
            secondary: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(icon),
            ),
            title: Text(title, style: const TextStyle(fontSize: 18)),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w100,
                color: Colors.grey,
              ),
            ),
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
