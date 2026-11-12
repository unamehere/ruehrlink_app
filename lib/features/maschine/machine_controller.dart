import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';

enum SendState { idle, sending, confirmed, unconfirmed, failed }

/// Was auf dem Maschinen-Bildschirm eingestellt ist, und ob es angekommen ist.
class MachineDraft {
  const MachineDraft({required this.settings, this.sendState = SendState.idle});

  final MachineSettings settings;
  final SendState sendState;

  MachineDraft copyWith({MachineSettings? settings, SendState? sendState}) =>
      MachineDraft(
        settings: settings ?? this.settings,
        sendState: sendState ?? this.sendState,
      );
}

/// Eingabefelder, die gerade ungültig sind – solange wird nicht gesendet.
final invalidInputsProvider = NotifierProvider<InvalidInputs, Set<String>>(
  InvalidInputs.new,
);

class InvalidInputs extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void report(String field, {required bool valid}) {
    if (valid == !state.contains(field)) return;
    state = valid ? ({...state}..remove(field)) : {...state, field};
  }
}

final machineControllerProvider =
    NotifierProvider<MachineController, MachineDraft>(MachineController.new);

class MachineController extends Notifier<MachineDraft> {
  /// So lange warten wir auf die Bestätigung der Maschine.
  static const ackTimeout = Duration(seconds: 5);

  @override
  MachineDraft build() => const MachineDraft(
    settings: MachineSettings(temperature: 0, time: 60, speed: 1),
  );

  /// Neue Werte setzen – eine frühere Sende-Rückmeldung gilt dann nicht mehr.
  void edit(MachineSettings settings) =>
      state = MachineDraft(settings: settings);

  /// Werte an die Maschine senden und auf `ack` warten.
  Future<void> send() async {
    final caps = ref.read(bridgeInfoProvider).value?.readyCaps;
    if (caps == null || state.sendState == SendState.sending) return;
    final settings = caps.clamp(state.settings);
    final api = ref.read(bridgeApiProvider);
    state = MachineDraft(settings: settings, sendState: SendState.sending);

    // Vor dem Senden abonnieren, damit die Bestätigung nicht verloren geht.
    // Ergebnis: true/false = Maschine hat (nicht) übernommen, null = keine Antwort.
    final ack = api
        .events()
        .where((e) => e is AckEvent && e.cmd == AckEvent.setProgramme)
        .cast<AckEvent>()
        .first
        .timeout(ackTimeout)
        .then<bool?>((a) => a.ok, onError: (_) => null);

    SendState result;
    try {
      await api.sendProgram(settings);
      result = switch (await ack) {
        true => SendState.confirmed,
        false => SendState.failed,
        null => SendState.unconfirmed,
      };
    } on BridgeException {
      result = SendState.failed;
    }
    // Nur zurückmelden, wenn inzwischen nichts anderes eingestellt wurde.
    if (ref.mounted && state.settings == settings) {
      state = state.copyWith(sendState: result);
    }
  }

  /// Programm stoppen. Liefert `false`, wenn die Brücke nicht erreichbar war.
  Future<bool> stop() async {
    try {
      await ref.read(bridgeApiProvider).stop();
      return true;
    } on BridgeException {
      return false;
    }
  }
}
