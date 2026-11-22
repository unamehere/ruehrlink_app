import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import 'theme.dart';

/// Ein Absatz einer Hilfe: optional mit Symbol und Überschrift, dazu 1–3 Sätze.
class HilfeEintrag {
  const HilfeEintrag(this.text, {this.titel, this.icon});

  final String text;
  final String? titel;
  final IconData? icon;
}

/// Inhalt eines Hilfe-Fensters. [bild] ist ein Asset-Pfad, [aktion] ein Knopf unter den Texten
/// (z. B. „So geht's an der Maschine“), der das Fenster schließt und dann [aktion] ausführt.
class Hilfe {
  const Hilfe({
    required this.titel,
    required this.eintraege,
    this.bild,
    this.aktion,
  });

  final String titel;
  final List<HilfeEintrag> eintraege;
  final String? bild;
  final ({String label, IconData icon, void Function(BuildContext) onTap})?
  aktion;
}

/// Baut eine [Hilfe] aus den Texten – so stehen alle Hilfen gesammelt in `hilfe_themen.dart`.
typedef HilfeThema = Hilfe Function(AppLocalizations l10n);

/// Kleiner, dezenter „?“-Knopf: öffnet die Hilfe als Fenster von unten – nur auf Wunsch, nie von
/// selbst. Für die App-Leiste so lassen; neben einer Abschnitts-Überschrift [klein] setzen.
class HilfeKnopf extends StatelessWidget {
  const HilfeKnopf(this.thema, {super.key, this.klein = false});

  final HilfeThema thema;
  final bool klein;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.helpButton,
    icon: const Icon(Icons.help_outline_rounded),
    iconSize: klein ? 22 : null,
    visualDensity: klein ? VisualDensity.compact : null,
    color: klein ? Theme.of(context).colorScheme.onSurfaceVariant : null,
    onPressed: () => zeigeHilfe(context, thema(context.l10n)),
  );
}

/// Abschnitts-Überschrift mit [HilfeKnopf] rechts daneben.
class UeberschriftMitHilfe extends StatelessWidget {
  const UeberschriftMitHilfe(this.text, this.thema, {super.key, this.style});

  final String text;
  final HilfeThema thema;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(text, style: style)),
      HilfeKnopf(thema, klein: true),
    ],
  );
}

/// Zeigt [hilfe] als Fenster von unten.
Future<void> zeigeHilfe(BuildContext context, Hilfe hilfe) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => HilfeFenster(hilfe: hilfe, aufrufer: context),
    );

/// Inhalt des Hilfe-Fensters: Titel, optional Bild, Absätze, optional ein Knopf.
class HilfeFenster extends StatelessWidget {
  const HilfeFenster({super.key, required this.hilfe, this.aufrufer});

  final Hilfe hilfe;

  /// Kontext unter dem Fenster – dort läuft die [Hilfe.aktion], nachdem das Fenster zu ist.
  final BuildContext? aufrufer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktion = hilfe.aktion;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          maxWidth: Tokens.maxContentWidth,
        ),
        // Kurze Texte: alles auf einmal bauen (kein ListView), dann ist auch der Knopf unten da.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Tokens.l, 0, Tokens.l, Tokens.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hilfe.titel, style: theme.textTheme.titleLarge),
              const SizedBox(height: Tokens.m),
              if (hilfe.bild case final bild?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radius),
                  child: Image.asset(bild, fit: BoxFit.cover),
                ),
                const SizedBox(height: Tokens.m),
              ],
              for (final e in hilfe.eintraege)
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.m),
                  child: _Absatz(e),
                ),
              if (aktion != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: Icon(aktion.icon),
                    label: Text(aktion.label),
                    onPressed: () {
                      Navigator.of(context).pop();
                      final ziel = aufrufer;
                      if (ziel != null && ziel.mounted) aktion.onTap(ziel);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Absatz extends StatelessWidget {
  const _Absatz(this.e);

  final HilfeEintrag e;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (e.titel case final titel?) ...[
          Text(titel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
        ],
        Text(e.text, style: theme.textTheme.bodyMedium),
      ],
    );
    final icon = e.icon;
    if (icon == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: Tokens.m),
        Expanded(child: text),
      ],
    );
  }
}
