# Plan zur Lösung: Neuester Vertretungsplan wird immer angezeigt

## Problemanalyse
- App lädt Daten nur beim ersten Öffnen der VPlan-Seite
- Keine automatische Aktualisierung beim App-Resume
- Background Service prüft nur Benachrichtigungen, nicht Datenaktualität
- Keine Anzeige des letzten Aktualisierungszeitpunkts

## Implementierungsschritte
- [ ] VPlanAPI erweitern um TTL-basiertes Caching
- [ ] Automatische Aktualisierung beim App-Resume implementieren
- [ ] Pull-to-Refresh Funktionalität hinzufügen
- [ ] Anzeige des letzten Aktualisierungszeitpunkts
- [ ] Background Service erweitern um Datenaktualisierung
- [ ] Testing und Verifikation

## Technische Details
- SharedPreferences erweitern um `lastUpdateTime` und `vplanCacheTTL`
- Widgets erweitern um Lifecycle-Hooks
- UI-Elemente für Aktualisierungsanzeige hinzufügen
