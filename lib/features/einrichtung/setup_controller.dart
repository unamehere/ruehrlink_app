import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// Die Schritte der Einrichtung, in dieser Reihenfolge (docs/screens.md).
enum SetupStep { welcome, bridge, wifi, machine, done }

/// Aktueller Schritt. Wird beim Verlassen der Einrichtung zurückgesetzt.
final setupStepProvider =
    NotifierProvider.autoDispose<SetupStepNotifier, SetupStep>(
      SetupStepNotifier.new,
    );

class SetupStepNotifier extends Notifier<SetupStep> {
  @override
  SetupStep build() => ref.read(setupEntryProvider);

  void next() {
    if (state != SetupStep.done) state = SetupStep.values[state.index + 1];
  }

  void back() {
    if (state != SetupStep.welcome) state = SetupStep.values[state.index - 1];
  }

  void goTo(SetupStep step) => state = step;

  /// „Maschine koppeln“ wurde übersprungen, weil die Maschine schon mit dem
  /// Rührlink gekoppelt war (z. B. App neu installiert). „Fertig“ sagt das dazu.
  bool machineAlreadyPaired = false;

  void skipMachine() {
    machineAlreadyPaired = true;
    state = SetupStep.done;
  }
}

/// Womit die Einrichtung beginnt. „Mit Code vom Etikett koppeln“ (kein anderes
/// Handy da) springt direkt zu „Rührlink finden“ statt zur Begrüßung.
final setupEntryProvider = NotifierProvider<SetupEntryNotifier, SetupStep>(
  SetupEntryNotifier.new,
);

class SetupEntryNotifier extends Notifier<SetupStep> {
  @override
  SetupStep build() => SetupStep.welcome;

  void set(SetupStep step) => state = step;
}

/// Ist die Einrichtung abgeschlossen? Steuert die Weiterleitung im Router.
final setupDoneProvider = NotifierProvider<SetupDoneNotifier, bool>(
  SetupDoneNotifier.new,
);

class SetupDoneNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(appStorageProvider).setupDone;

  Future<void> set(bool done) async {
    state = done;
    await ref.read(appStorageProvider).setSetupDone(done);
  }
}
