import UIKit

/// Die Plan-Einstellungen – eine reine **Übersicht**.
///
/// ## Warum hier keine Schalter mehr stehen
///
/// Vorher standen hier Schalter für einzelne Anzeigedetails direkt neben den
/// Einträgen zu den Untermenüs. Wer gezielt etwas ändern wollte, musste an der
/// Liste vorbei an genau einer Zeile drehen, die einen anderen Aufbau hatte als
/// die übrigen – und dieselben Fragen standen an zwei Orten.
///
/// Deshalb ist diese Seite eine Liste von Zeilen, die **weiterführen**, und
/// sonst nichts.
///
/// ## Warum die Zeilen hier und nicht in `Settings.dart`
///
/// Dort gab es dieselbe Liste in Flutter. Sie ist auf iOS durch diesen Bildschirm
/// ersetzt; die Dart-Seite bleibt für Android und das Web.
final class PlanSettingsScreen: ListScreen {
    init() {
        super.init(title: L.planSettings)
    }

    override func makeSections() -> [Section] {
        [
            Section(
                rows: [
                    .choice(
                        title: L.lessonInfoSettings,
                        subtitle: L.lessonInfoSettingsSubtitle,
                        symbol: "info.circle"
                    ) {[weak self] in self?.zeige(LessonInfoScreen()) },
                    .choice(
                        title: L.previewSettings,
                        subtitle: L.previewSettingsSubtitle,
                        symbol: "eye"
                    ) {[weak self] in self?.zeige(PreviewScreen()) },
                    .choice(
                        title: L.defaultPlanModeEntry,
                        subtitle: L.defaultPlanModeEntrySubtitle,
                        symbol: "square.stack.3d.up"
                    ) {[weak self] in self?.zeige(PlanModeScreen()) },
                    .choice(
                        title: L.lessonTimes,
                        subtitle: L.lessonTimesSubtitle,
                        symbol: "clock"
                    ) {[weak self] in self?.zeige(LessonsScreen()) },
                ])
        ]
    }

    private func zeige(_ screen: UIViewController) {
        navigationController?.pushViewController(screen, animated: true)
    }
}