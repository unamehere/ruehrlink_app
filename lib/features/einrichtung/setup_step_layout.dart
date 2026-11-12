import 'package:material_ui/material_ui.dart';

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

/// Fehlermeldung in einem Schritt – gut sichtbar, mit Symbol.
class SetupError extends StatelessWidget {
  const SetupError(this.message, {super.key});

  final String message;

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
            children: [
              Icon(
                Icons.error_rounded,
                color: scheme.onErrorContainer,
                size: 30,
              ),
              const SizedBox(width: Tokens.s + 4),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
