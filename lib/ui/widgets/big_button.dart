import 'package:material_ui/material_ui.dart';

import '../theme.dart';

enum BigButtonKind { primary, danger, secondary }

/// Großer, volle Breite einnehmender Button für die Hauptaktion eines Bildschirms.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = BigButtonKind.primary,
    this.busy = false,
  });

  /// Roter Stopp-Button – überall gleich.
  const BigButton.stop({
    super.key,
    required this.label,
    required this.onPressed,
  }) : icon = Icons.stop_rounded,
       kind = BigButtonKind.danger,
       busy = false;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BigButtonKind kind;

  /// Zeigt einen Ladekreis und sperrt den Button.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onTap = busy ? null : onPressed;
    final Widget leading = busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        : Icon(icon, size: 30);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null || busy) ...[
          leading,
          const SizedBox(width: Tokens.s + 4),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    const size = Size.fromHeight(Tokens.bigButton);

    return switch (kind) {
      BigButtonKind.primary => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(minimumSize: size),
        child: child,
      ),
      BigButtonKind.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        child: child,
      ),
      BigButtonKind.secondary => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: size),
        child: child,
      ),
    };
  }
}
