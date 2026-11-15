import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/storage/app_storage.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../waage/scale_sheet.dart';
import '../rezepte/recipe_library.dart' show safetyHintsProvider;
import 'programs.dart';

/// Wie deutlich die App meldet, dass die Maschine auf dich wartet (Fehlerliste F14).
enum NudgeVibration { off, normal, strong }

class NudgeSettings {
  const NudgeSettings({
    this.vibration = NudgeVibration.normal,
    this.bigHint = true,
  });

  final NudgeVibration vibration;

  /// Großer Hinweis mitten auf dem Bildschirm (zusätzlich zur Programm-Karte).
  final bool bigHint;
}

final nudgeSettingsProvider =
    NotifierProvider<NudgeSettingsNotifier, NudgeSettings>(
      NudgeSettingsNotifier.new,
    );

class NudgeSettingsNotifier extends Notifier<NudgeSettings> {
  @override
  NudgeSettings build() {
    final s = ref.read(appStorageProvider);
    return NudgeSettings(
      vibration: NudgeVibration
          .values[s.nudgeVibration.clamp(0, NudgeVibration.values.length - 1)],
      bigHint: s.nudgeBigHint,
    );
  }

  Future<void> setVibration(NudgeVibration v) async {
    state = NudgeSettings(vibration: v, bigHint: state.bigHint);
    await ref.read(appStorageProvider).setNudgeVibration(v.index);
  }

  Future<void> setBigHint(bool on) async {
    state = NudgeSettings(vibration: state.vibration, bigHint: on);
    await ref.read(appStorageProvider).setNudgeBigHint(on);
  }
}

/// Vibration abspielen: normal = zwei kurze, kräftig = drei lange Impulse.
Future<void> playNudge(NudgeVibration v) async {
  switch (v) {
    case NudgeVibration.off:
      return;
    case NudgeVibration.normal:
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await HapticFeedback.heavyImpact();
    case NudgeVibration.strong:
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.vibrate();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
  }
  await SystemSound.play(SystemSoundType.alert);
}

/// Nur melden, wenn die Maschine wirklich auf dich wartet – nicht bei Dingen, die man gerade selbst tut
/// (Kopf auf/zu, am Gerät angehalten, Programm gestartet):
/// - nach einer Ruhephase (lief → wartet auf Knopfdruck)
/// - Programm fertig
/// - Abbruch, den nicht du ausgelöst hast (Verbindung weg, keine Antwort, zu lange pausiert)
bool shouldNudge(SequenceState? prev, SequenceState next) {
  if (prev == null || prev.step == 0 && next.step == 0) return false;
  final pauseOver =
      next.state == SequenceRunState.waitingStart &&
      prev.state == SequenceRunState.running;
  final done =
      next.state == SequenceRunState.done &&
      prev.state != SequenceRunState.done;
  if (pauseOver || done) return true;
  return next.state == SequenceRunState.aborted &&
      prev.state != SequenceRunState.aborted &&
      next.reason != 'user';
}

/// Liegt um den Tab-Rahmen: meldet überall in der App, egal welcher Tab offen ist.
class SequenceNudgeWatcher extends ConsumerStatefulWidget {
  const SequenceNudgeWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SequenceNudgeWatcher> createState() =>
      _SequenceNudgeWatcherState();
}

class _SequenceNudgeWatcherState extends ConsumerState<SequenceNudgeWatcher> {
  bool _dialogOpen = false;

  Future<void> _nudge(SequenceState seq) async {
    final settings = ref.read(nudgeSettingsProvider);
    unawaited(playNudge(settings.vibration));
    if (!settings.bigHint || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => _NudgeDialog(initial: seq),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SequenceState?>(sequenceProvider.select((s) => s.value), (
      prev,
      next,
    ) {
      if (next != null && shouldNudge(prev, next)) _nudge(next);
    });
    return widget.child;
  }
}

/// Großer Hinweis. Schließt sich selbst, sobald die Maschine wieder läuft.
class _NudgeDialog extends ConsumerWidget {
  const _NudgeDialog({required this.initial});

  final SequenceState initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    ref.listen<SequenceState?>(sequenceProvider.select((s) => s.value), (
      _,
      next,
    ) {
      if (initial.state == SequenceRunState.waitingStart &&
          next?.state == SequenceRunState.running) {
        Navigator.of(context).maybePop();
      }
    });
    final (IconData icon, String title) = switch (initial.state) {
      SequenceRunState.waitingStart => (
        Icons.touch_app_rounded,
        l10n.seqPressStart,
      ),
      SequenceRunState.done => (Icons.check_circle_rounded, l10n.seqDone),
      _ => (Icons.error_outline_rounded, l10n.nudgeAborted),
    };
    return AlertDialog(
      icon: Icon(icon, size: 72, color: Tokens.glow),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium,
      ),
      content: Text(
        initial.name,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      actions: [
        BigButton(
          label: l10n.seqDismiss,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Einstellungen unter „Mehr → Hinweise beim Kochen“.
class NudgeSettingsPage extends ConsumerWidget {
  const NudgeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(nudgeSettingsProvider);
    final notifier = ref.read(nudgeSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nudgeTitle)),
      body: AdaptivePage(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.nudgeExplain, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Tokens.l),
            Text(l10n.nudgeVibration, style: theme.textTheme.titleMedium),
            const SizedBox(height: Tokens.s),
            SegmentedButton<NudgeVibration>(
              segments: [
                ButtonSegment(
                  value: NudgeVibration.off,
                  label: Text(l10n.nudgeOff),
                ),
                ButtonSegment(
                  value: NudgeVibration.normal,
                  label: Text(l10n.nudgeNormal),
                ),
                ButtonSegment(
                  value: NudgeVibration.strong,
                  label: Text(l10n.nudgeStrong),
                ),
              ],
              selected: {settings.vibration},
              onSelectionChanged: (v) {
                notifier.setVibration(v.first);
                playNudge(v.first);
              },
            ),
            const SizedBox(height: Tokens.l),
            Card(
              child: SwitchListTile(
                title: Text(l10n.nudgeBigHint),
                subtitle: Text(l10n.nudgeBigHintDetail),
                value: settings.bigHint,
                onChanged: notifier.setBigHint,
              ),
            ),
            const SizedBox(height: Tokens.m),
            Card(
              child: SwitchListTile(
                title: Text(l10n.scalePopupSetting),
                subtitle: Text(l10n.scalePopupSettingDetail),
                value: ref.watch(scalePopupProvider),
                onChanged: ref.read(scalePopupProvider.notifier).set,
              ),
            ),
            const SizedBox(height: Tokens.m),
            Card(
              child: SwitchListTile(
                title: Text(l10n.safetyHintsTitle),
                subtitle: Text(l10n.safetyHintsDetail),
                value: ref.watch(safetyHintsProvider),
                onChanged: ref.read(safetyHintsProvider.notifier).set,
              ),
            ),
            const SizedBox(height: Tokens.l),
            Text(
              l10n.nudgeLockedNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
