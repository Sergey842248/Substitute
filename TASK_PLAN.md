# Task: Sicherstellen, dass immer der neueste Vertretungsplan angezeigt wird

## To-Do Liste
- [ ] Vertretungsplan-bezogene Dateien analysieren
- [ ] Datenabruf- und Caching-Mechanismen verstehen
- [ ] Aktuelle Implementierung der Datenaktualisierung prüfen
- [ ] Identifizieren, wo das Problem mit veralteten Daten liegt
- [ ] Implementierung der Lösung für automatische Aktualisierung
- [ ] Testing und Verifikation der Lösung

## Zu analysierende Dateien:
- lib/pages/vplan/VPlan.dart
- lib/pages/vplan/VPlanAPI.dart
- lib/pages/vplan/Analytics.dart
- lib/pages/teacherVPlan/TeacherVPlan.dart
- lib/background_service.dart
- lib/main.dart

## Erwartete Lösung:
- Automatische Aktualisierung beim App-Start
- Automatische Aktualisierung bei App-Resume
- Manuelle Aktualisierungsoption
- Anzeige des letzten Aktualisierungszeitpunkts
