import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';

/// Kopplungsanfragen neuer Geräte (WS `pairRequest`).
final pairRequestsProvider = StreamProvider<PairRequestEvent>(
  (ref) => ref
      .watch(bridgeApiProvider)
      .events()
      .where((e) => e is PairRequestEvent)
      .cast<PairRequestEvent>(),
);

/// Fragt bei einer Kopplungsanfrage „Name möchte sich verbinden – erlauben?“
/// und bestätigt sie bei Ja über `POST /api/v1/pair/approve`.
/// Liegt um den Tab-Rahmen, ist also überall in der App aktiv (nicht in der Einrichtung).
class PairRequestWatcher extends ConsumerStatefulWidget {
  const PairRequestWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PairRequestWatcher> createState() => _PairRequestWatcherState();
}

class _PairRequestWatcherState extends ConsumerState<PairRequestWatcher> {
  final _asked = <String>{};

  Future<void> _ask(PairRequestEvent request) async {
    if (!_asked.add(request.id)) return; // jede Anfrage nur einmal fragen
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.phonelink_lock_rounded, size: 40),
        title: Text(l10n.pairRequestTitle),
        content: Text(l10n.pairRequestText(request.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.pairDeny),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pairAllow),
          ),
        ],
      ),
    );
    // Ablehnen: nichts tun, die Anfrage verfällt auf der Brücke nach 60 s.
    if (allow != true) return;
    String message;
    try {
      await ref.read(bridgeApiProvider).approvePairing(request.id);
      message = l10n.pairAllowed;
    } on BridgeException catch (e) {
      message = e.statusCode == 404 ? l10n.pairExpired : l10n.pairFailed;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pairRequestsProvider, (_, next) {
      if (next case AsyncData(:final value)) _ask(value);
    });
    return widget.child;
  }
}
