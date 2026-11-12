import 'package:material_ui/material_ui.dart';

import '../../core/provisioning/diag_log.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';

/// Gemeinsamer Aufbau jedes Einrichtungsschritts: Bild, Überschrift, Text –
/// darunter (schmal) bzw. daneben (breit) der Inhalt und die Hauptaktion.
class SetupStepLayout extends StatelessWidget {
  const SetupStepLayout({
    super.key,
    required this.title,
    required this.text,
    this.visual,
    this.content,
    this.action,
  });

  final String title;
  final String text;
  final Widget? visual;
  final Widget? content;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visual != null) ...[visual!, const SizedBox(height: Tokens.l)],
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.s),
        Text(text, style: theme.textTheme.bodyLarge),
      ],
    );
    final hasSecondary = content != null;
    return AdaptivePage(
      primary: hasSecondary || action == null
          ? intro
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                intro,
                const SizedBox(height: Tokens.xl),
                action!,
              ],
            ),
      secondary: hasSecondary
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content!,
                if (action != null) ...[
                  const SizedBox(height: Tokens.l),
                  action!,
                ],
              ],
            )
          : null,
    );
  }
}

/// Großes rundes Symbol als Bild-Ersatz für einen Schritt.
class SetupIcon extends StatelessWidget {
  const SetupIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.l),
          child: Icon(icon, size: 72, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

/// Fehlermeldung in einem Schritt – gut sichtbar, mit Symbol. [detail] ist die
/// technische Ursache in kleiner Schrift (hilft bei Bildschirmfotos).
class SetupError extends StatelessWidget {
  const SetupError(this.message, {super.key, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_rounded,
                color: scheme.onErrorContainer,
                size: 30,
              ),
              const SizedBox(width: Tokens.s + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: Tokens.s),
                      SelectableText(
                        detail!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ).copyWith(color: scheme.onErrorContainer),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ausklappbares Protokoll der Einrichtung („Entwicklerdetails“). Bewusst klein
/// gesetzt – es ist für Bildschirmfotos an die Entwickler gedacht.
class DiagPanel extends StatelessWidget {
  const DiagPanel({super.key, required this.log});

  final DiagLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.bug_report_outlined),
      title: Text(context.l10n.diagTitle, style: theme.textTheme.bodyMedium),
      children: [
        ListenableBuilder(
          listenable: log,
          builder: (context, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Tokens.s),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              log.lines.isEmpty ? '–' : log.lines.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ladeanzeige mit Text, z. B. „Suche Brücke …“.
class SetupProgress extends StatelessWidget {
  const SetupProgress(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tokens.l),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
        const SizedBox(width: Tokens.m),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
