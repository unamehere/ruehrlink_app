import '../../core/models/models.dart';
import '../../l10n/l10n.dart';

/// Schnellprogramme: immer wiederkehrende Abläufe ohne Fragen – ein Tipp und los.
/// (Mit Fragen und Rechnung: die Assistenten.)
///
/// Stufen werden über `caps` aufgelöst (Bezeichnung wie am Gerät), nichts Gerätespezifisches fest im
/// Code. **Alle Zeiten, Stufen und Temperaturen sind vorläufig** – an der Maschine prüfen
/// (Testplan 3b); Quellen: KCL95-Anleitung (Presets Z. 3872–3959, Richtwerte Z. 4104–4114) bzw. Schätzung.
List<Program> quickPrograms(ApplianceCaps caps, AppLocalizations l10n) {
  final cont = caps.speedsIn(SpeedGroup.continuous);
  final stir = caps.speedsIn(SpeedGroup.stir);
  SpeedOption? c(String label) =>
      cont.where((o) => o.label == label).firstOrNull;
  SpeedOption? s(String label) =>
      stir.where((o) => o.label == label).firstOrNull;

  ProgramStep step(SpeedOption o, int seconds, String label, {int temp = 0}) =>
      ProgramStep(
        settings: MachineSettings(temperature: temp, time: seconds, speed: o.v),
        label: label,
      );

  final min = c('min'), s1 = c('1'), s3 = c('3'), s4 = c('4'), max = c('max');
  final i1 = s('1'), i2 = s('2');
  // Fehlt eine Stufe (anderes Gerät), entfällt das Programm – lieber keins als ein falsches.
  return [
    if (min != null)
      Program(
        id: 'qp-unterruehren',
        name: l10n.qpStir,
        steps: [step(min, 30, l10n.qpStepStir)], // Schätzung
      ),
    if (min != null && s4 != null)
      Program(
        id: 'qp-ruehrteig',
        name: l10n.qpBatter,
        steps: [
          step(min, 30, l10n.qpStepStir), // Schätzung
          step(
            s4,
            180,
            l10n.qpStepBeat,
          ), // Schätzung, Anleitung: Rührteig mit K-Haken
        ],
      ),
    if (min != null && s1 != null)
      Program(
        id: 'qp-hefeteig',
        name: l10n.qpYeastDough,
        steps: [
          step(
            min,
            60,
            l10n.qpStepStir,
          ), // Anleitung Z. 4241 (Unterrühren auf min)
          step(
            s1,
            360,
            l10n.qpStepKnead,
          ), // Schätzung (Assistent: 420 s für 500 g Weizen)
        ],
      ),
    if (s3 != null && max != null)
      Program(
        id: 'qp-sahne',
        name: l10n.qpCream,
        steps: [
          step(s3, 20, l10n.qpStepStart), // Schätzung
          step(max, 75, l10n.qpStepWhip), // Schätzung für 200 ml
        ],
      ),
    if (s3 != null && max != null)
      Program(
        id: 'qp-eischnee',
        name: l10n.qpEggWhites,
        steps: [
          step(s3, 30, l10n.qpStepStart), // Anleitung Z. 3881
          step(max, 90, l10n.qpStepWhip), // Anleitung Z. 4194, steif
        ],
      ),
    if (i1 != null)
      Program(
        id: 'qp-zwiebeln',
        name: l10n.qpOnions,
        steps: [
          step(
            i1,
            240,
            l10n.qpStepSaute,
            temp: 120,
          ), // Richtwert Sautieren 130–140 °C, etwas sanfter
        ],
      ),
    if (i1 != null)
      Program(
        id: 'qp-schokolade',
        name: l10n.qpChocolate,
        steps: [
          step(
            i1,
            480,
            l10n.qpStepMelt,
            temp: 50,
          ), // Richtwert 60 °C, sanfter (siehe Assistent)
        ],
      ),
    if (i2 != null)
      Program(
        id: 'qp-warmhalten',
        name: l10n.qpKeepWarm,
        steps: [
          step(
            i2,
            1800,
            l10n.qpStepKeepWarm,
            temp: 62,
          ), // wie Kenwood-Warmhalten: 30 min, 62 °C, Intervall 2
        ],
      ),
  ];
}
