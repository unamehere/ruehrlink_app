import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/illustrations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../../ui/widgets/smooth_countdown.dart';
import '../../ui/widgets/speed_slider.dart';
import '../maschine/live_status_band.dart';
import 'programs.dart';

/// Start-Tab: Begrüßung, Statusband, laufendes Programm, Programme.
/// Später: „Weiterkochen“, Lieblingsrezepte, Assistenten.
class KochenPage extends ConsumerWidget {
  const KochenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Tokens.m,
                Tokens.l,
                Tokens.m,
                Tokens.xl,
              ),
              children: [
                const _Greeting(),
                const SizedBox(height: Tokens.l),
                if (ref.watch(bridgeTargetProvider) is DemoTarget) ...[
                  HintCard(icon: Icons.science_outlined, text: l10n.demoBanner),
                  const SizedBox(height: Tokens.m),
                ],
                const LiveStatusBand(),
                const SizedBox(height: Tokens.l),
                const _SequencePanel(),
                const _ProgramSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Image.asset(
          dark
              ? 'assets/brand/zeichen_dunkel.png'
              : 'assets/brand/zeichen_hell.png',
          width: 56,
          height: 56,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: Tokens.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.kochenGreeting,
                style: theme.textTheme.headlineMedium,
              ),
              Text(
                context.l10n.kochenGreetingSub,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bild zu einem Programm: passend zum Namen, sonst Schüssel bzw. Reagenzglas für Tests.
String programIllustration(String id, String name) => id.startsWith('test')
    ? Illustrations.test
    : Illustrations.forName(name) ?? Illustrations.bowl;

// ---------------------------------------------------------------------------
// Laufendes Programm

/// Ob die Abschlussmeldung (fertig/abgebrochen) schon weggeklickt wurde.
final _dismissedProvider = NotifierProvider<_Dismissed, bool>(_Dismissed.new);

class _Dismissed extends Notifier<bool> {
  @override
  bool build() {
    // Neues Programm → Meldung wieder zeigen.
    ref.listen(sequenceProvider.select((s) => s.value?.active), (prev, next) {
      if (next == true) state = false;
    });
    return false;
  }

  void dismiss() => state = true;
}

class _SequencePanel extends ConsumerStatefulWidget {
  const _SequencePanel();

  @override
  ConsumerState<_SequencePanel> createState() => _SequencePanelState();
}

class _SequencePanelState extends ConsumerState<_SequencePanel> {
  // Für den Ring: größte Restzeit, die für den aktuellen Schritt gemeldet wurde.
  String _stepKey = '';
  int _stepMax = 0;

  /// Anteil des Schritts, der schon vorbei ist – aus der lokal gezählten Restzeit [left].
  double _stepFraction(SequenceState seq, int left) {
    final key = '${seq.name}/${seq.step}';
    if (key != _stepKey) {
      _stepKey = key;
      _stepMax = 0;
    }
    if (seq.stepRemainingS > _stepMax) _stepMax = seq.stepRemainingS;
    return _stepMax == 0 ? 0 : (1 - left / _stepMax).clamp(0.0, 1.0);
  }

  /// Kurz vibrieren, sobald die Nutzerin etwas tun muss (Knopf drücken, Kopf schließen …) –
  /// z. B. nach einer Ruhephase, die die Maschine nicht von selbst beendet (Fehlerliste F10).
  void _nudgeOnUserAction(SequenceState? prev, SequenceState? next) {
    if (next == null) return;
    final needsUser =
        next.state == SequenceRunState.waitingStart ||
        next.state == SequenceRunState.paused;
    final changed =
        prev?.state != next.state ||
        prev?.reason != next.reason ||
        prev?.step != next.step;
    if (needsUser && changed) {
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 250),
        HapticFeedback.heavyImpact,
      );
      SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SequenceState?>(
      sequenceProvider.select((s) => s.value),
      _nudgeOnUserAction,
    );
    final seq = ref.watch(sequenceProvider).value;
    if (seq == null || seq.state == SequenceRunState.idle || seq.step == 0) {
      return const SizedBox.shrink();
    }
    final finished = !seq.active;
    if (finished && ref.watch(_dismissedProvider)) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needsUser =
        seq.state == SequenceRunState.waitingStart ||
        seq.state == SequenceRunState.paused;
    final running = seq.state == SequenceRunState.running;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.l),
      child: Card(
        color: needsUser ? scheme.tertiaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Illustration(
                    programIllustration(seq.programId ?? 'test', seq.name),
                    size: 48,
                  ),
                  const SizedBox(width: Tokens.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(seq.name, style: theme.textTheme.titleLarge),
                        Text(
                          [
                            l10n.seqStep(seq.step, seq.of),
                            if (seq.label.isNotEmpty) seq.label,
                          ].join(' · '),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.l),
              if (running)
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: SmoothCountdown(
                      seconds: seq.stepRemainingS,
                      running: running,
                      builder: (context, left) => Stack(
                        fit: StackFit.expand,
                        children: [
                          TweenAnimationBuilder<double>(
                            // Ring gleitet zwischen den Sekunden statt zu springen
                            tween: Tween(end: _stepFraction(seq, left)),
                            duration: const Duration(milliseconds: 900),
                            builder: (context, v, _) =>
                                CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                  color: Tokens.glow,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                ),
                          ),
                          Center(
                            child: Text(
                              formatDuration(left),
                              style: theme.textTheme.displaySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      _icon(seq),
                      size: 40,
                      color: needsUser
                          ? scheme.onTertiaryContainer
                          : scheme.primary,
                    ),
                    const SizedBox(width: Tokens.m),
                    Expanded(
                      child: Text(
                        _message(l10n, seq),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: Tokens.l),
              _StepDots(
                step: seq.step,
                of: seq.of,
                done: seq.state == SequenceRunState.done,
              ),
              const SizedBox(height: Tokens.l),
              if (finished)
                BigButton(
                  label: l10n.seqDismiss,
                  kind: BigButtonKind.secondary,
                  onPressed: () =>
                      ref.read(_dismissedProvider.notifier).dismiss(),
                )
              else
                BigButton.stop(label: l10n.seqAbort, onPressed: _abort),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(SequenceState seq) => switch (seq.state) {
    SequenceRunState.waitingStart => Icons.touch_app_rounded,
    SequenceRunState.paused => Icons.pause_circle_rounded,
    SequenceRunState.done => Icons.check_circle_rounded,
    _ => Icons.info_rounded,
  };

  static String _message(AppLocalizations l10n, SequenceState seq) => switch ((
    seq.state,
    seq.reason,
  )) {
    (SequenceRunState.waitingStart, _) => l10n.seqPressStart,
    (SequenceRunState.running, _) => l10n.seqRunning,
    (SequenceRunState.paused, 'lid_open') => l10n.seqLidOpen,
    (SequenceRunState.paused, 'bowl_missing') => l10n.seqBowlMissing,
    (SequenceRunState.paused, 'machine_paused') => l10n.seqMachinePaused,
    (SequenceRunState.paused, _) => l10n.seqPaused,
    (SequenceRunState.done, _) => l10n.seqDone,
    (SequenceRunState.aborted, 'disconnected') => l10n.seqAbortedDisconnected,
    (SequenceRunState.aborted, 'no_ack') => l10n.seqAbortedNoAck,
    (SequenceRunState.aborted, 'timeout') => l10n.seqAbortedTimeout,
    _ => l10n.seqAbortedUser,
  };

  Future<void> _abort() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(sequenceControllerProvider).abort();
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(l10n.stopFailed)));
  }
}

/// Ein Punkt pro Schritt: erledigt, aktuell (Bernstein), offen.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.of, required this.done});

  final int step;
  final int of;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= of; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == step && !done ? 28 : 12,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: done || i < step
                  ? scheme.primary
                  : i == step
                  ? Tokens.glow
                  : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Programme

class _ProgramSection extends ConsumerWidget {
  const _ProgramSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final fromBridge =
        ref.watch(bridgeProgramsProvider).value ?? const <Program>[];

    final children = <Widget>[
      Text(l10n.programsTitle, style: theme.textTheme.headlineSmall),
      const SizedBox(height: Tokens.s),
    ];
    if (caps == null) {
      children.add(
        HintCard(
          icon: Icons.link_off_rounded,
          text: l10n.programsMachineMissing,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    children
      ..add(
        Text(
          l10n.programsHint,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      )
      ..add(const SizedBox(height: Tokens.m));
    if (fromBridge.isNotEmpty) {
      children.add(_ProgramGrid(programs: fromBridge, caps: caps));
    }
    final tests = testPrograms(caps, l10n);
    if (tests.isNotEmpty) {
      children
        ..add(const SizedBox(height: Tokens.l))
        ..add(Text(l10n.programsTestTitle, style: theme.textTheme.titleMedium))
        ..add(const SizedBox(height: Tokens.s))
        ..add(_ProgramGrid(programs: tests, caps: caps));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ProgramGrid extends StatelessWidget {
  const _ProgramGrid({required this.programs, required this.caps});

  final List<Program> programs;
  final ApplianceCaps caps;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 560 ? 3 : 2;
      final width = (c.maxWidth - (columns - 1) * Tokens.m) / columns;
      return Wrap(
        spacing: Tokens.m,
        runSpacing: Tokens.m,
        children: [
          for (final p in programs)
            SizedBox(
              width: width,
              child: _ProgramTile(program: p, caps: caps),
            ),
        ],
      );
    },
  );
}

class _ProgramTile extends ConsumerWidget {
  const _ProgramTile({required this.program, required this.caps});

  final Program program;
  final ApplianceCaps caps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProgram(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Illustration(
                programIllustration(program.id, program.name),
                size: 72,
              ),
              const SizedBox(height: Tokens.m),
              Text(
                program.name,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.programStepsInfo(
                  program.steps.length,
                  formatDuration(program.totalTime),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepLine(BuildContext context, AppLocalizations l10n, ProgramStep s) {
    final v = s.settings;
    final time = formatDuration(v.time);
    final line = caps.speedOption(v.speed)?.group == SpeedGroup.off
        ? l10n.programStepRest(time)
        : v.temperature > 0
        ? l10n.programStepLineHeat(
            speedText(context, caps, v.speed),
            time,
            v.temperature,
          )
        : l10n.programStepLine(speedText(context, caps, v.speed), time);
    return s.label.isEmpty ? line : '${s.label} – $line';
  }

  Future<void> _showProgram(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final start = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final busy = ref.watch(sequenceProvider).value?.active ?? false;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.l, 0, Tokens.l, Tokens.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Illustration(
                      programIllustration(program.id, program.name),
                      size: 64,
                    ),
                    const SizedBox(width: Tokens.m),
                    Expanded(
                      child: Text(
                        program.name,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.l),
                for (final (i, s) in program.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.s),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox(width: Tokens.m),
                        Expanded(
                          child: Text(
                            _stepLine(context, l10n, s),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: Tokens.m),
                if (busy) ...[
                  HintCard(
                    icon: Icons.hourglass_top_rounded,
                    text: l10n.programBusy,
                  ),
                  const SizedBox(height: Tokens.m),
                ],
                BigButton(
                  label: l10n.programStart,
                  icon: Icons.play_arrow_rounded,
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (start != true) return;
    final error = await ref
        .read(sequenceControllerProvider)
        .start(program, l10n);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}
