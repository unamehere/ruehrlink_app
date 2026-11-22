import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import 'programs.dart';

/// Nachstellen (Sprint-Plan 23.11., Abschnitt 6): Ist ein Programm fertig, aber Sahne noch nicht steif
/// oder der Teig noch nicht so weit, startet „+30 s“ usw. den letzten Schritt noch einmal mit derselben
/// Stufe und Temperatur – als ganz normales Programm über den Sequencer (`POST /sequence/start`), also
/// mit allen Prüfungen der Brücke. Gestartet wird wie immer am Gerät.

/// Was diese App zuletzt gestartet hat – nur dann lässt sich nachstellen (bei Programmen anderer
/// Handys kennt die App die Werte nicht).
class LetzterLauf {
  const LetzterLauf({required this.programm, required this.bezugS});

  final Program programm;

  /// Dauer des ursprünglichen letzten Schritts. Bestimmt die Zeitschritte – auch nach dem
  /// Nachstellen bleibt es bei „+1 min / +5 min“ für einen langen Knetschritt.
  final int bezugS;

  ProgramStep get schritt => programm.steps.last;

  /// Gehört der Zustand [seq] der Brücke zu diesem Lauf?
  bool passt(SequenceState seq) =>
      seq.name == programm.name && seq.of == programm.steps.length;
}

final letzterLaufProvider = NotifierProvider<LetzterLaufNotifier, LetzterLauf?>(
  LetzterLaufNotifier.new,
);

class LetzterLaufNotifier extends Notifier<LetzterLauf?> {
  @override
  LetzterLauf? build() => null;

  void merken(LetzterLauf lauf) => state = lauf;
}

/// Schritt ohne Motor (Gehen, Ruhen)? Ohne `caps` gilt 0 als „aus“ (wie auf der Brücke).
bool motorAus(int speed, ApplianceCaps? caps) =>
    speed == 0 || caps?.speedOption(speed)?.group == SpeedGroup.off;

/// Die beiden angebotenen Verlängerungen in Sekunden, passend zum Schritt:
/// Gehen/Ruhen (Motor aus, mit Wärme): +5/+10 min · kurze Schritte (< 3 min): +30 s/+1 min ·
/// sonst +1/+5 min. `null` = nicht nachstellbar (Motor aus und keine Wärme – so ein Programm nimmt
/// die Brücke nicht an, `first_step`).
(int, int)? nachstellZeiten(
  MachineSettings s, {
  required int bezugS,
  ApplianceCaps? caps,
}) {
  if (motorAus(s.speed, caps)) {
    return s.temperature > 0 ? (300, 600) : null;
  }
  return bezugS < 180 ? (30, 60) : (60, 300);
}

/// Programm für „+[zusatzS]“: derselbe Schritt (Stufe, Temperatur, Beschriftung), nur kürzer.
/// Der Name bleibt, damit die Programm-Karte gleich aussieht.
Program nachstellProgramm(LetzterLauf lauf, int zusatzS) => Program(
  id: '',
  name: lauf.programm.name,
  steps: [
    ProgramStep(
      settings: lauf.schritt.settings.copyWith(time: zusatzS),
      label: lauf.schritt.label,
    ),
  ],
);

/// Zeitschritte für den fertigen Lauf [seq] – `null`, wenn hier nichts angeboten wird.
(int, int)? nachstellAngebot(
  SequenceState? seq,
  LetzterLauf? lauf,
  ApplianceCaps? caps,
) {
  if (seq == null || lauf == null || seq.state != SequenceRunState.done) {
    return null;
  }
  if (!lauf.passt(seq)) return null;
  return nachstellZeiten(
    lauf.schritt.settings,
    bezugS: lauf.bezugS,
    caps: caps,
  );
}

/// „30 s“, „1 min“ …
String nachstellDauer(AppLocalizations l10n, int s) =>
    s < 60 ? l10n.seqMoreSeconds(s) : l10n.seqMoreMinutes(s ~/ 60);

/// Dezente Frage „Noch nicht fertig?“ mit zwei Knöpfen. Erscheint nur, wenn das Programm fertig ist
/// und von dieser App kam; sonst leer. Wer weitermachen will, tippt einfach woanders hin.
class NachstellenLeiste extends ConsumerStatefulWidget {
  const NachstellenLeiste({super.key, this.onGestartet});

  /// Nach erfolgreichem Start (z. B. damit der Kochmodus den Lauf wieder verfolgt).
  final VoidCallback? onGestartet;

  @override
  ConsumerState<NachstellenLeiste> createState() => _NachstellenLeisteState();
}

class _NachstellenLeisteState extends ConsumerState<NachstellenLeiste> {
  bool _sendet = false;

  Future<void> _nachstellen(int s) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendet = true);
    final fehler = await ref
        .read(sequenceControllerProvider)
        .nachstellen(s, l10n);
    if (!mounted) return;
    setState(() => _sendet = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(fehler ?? l10n.seqMoreStarted(nachstellDauer(l10n, s))),
      ),
    );
    if (fehler == null) widget.onGestartet?.call();
  }

  @override
  Widget build(BuildContext context) {
    final seq = ref.watch(sequenceProvider).value;
    final lauf = ref.watch(letzterLaufProvider);
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final zeiten = nachstellAngebot(seq, lauf, caps);
    if (zeiten == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (kurz, lang) = zeiten;
    Widget knopf(int s) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
        onPressed: _sendet ? null : () => _nachstellen(s),
        child: Text(
          l10n.seqMoreAdd(nachstellDauer(l10n, s)),
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.seqMoreQuestion,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.s),
        Row(
          children: [
            knopf(kurz),
            const SizedBox(width: Tokens.m),
            knopf(lang),
          ],
        ),
      ],
    );
  }
}
