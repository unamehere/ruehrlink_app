import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Fenstergröße nach Material 3 – die EINZIGE Stelle, an der Breakpoints stehen.
///
/// - [compact] (< 600 dp): Handy hochkant – Hauptlayout, untere Navigation.
/// - [medium] (600–840 dp): Tablet hochkant, Handy quer – Seitenleiste, eine Spalte.
/// - [expanded] (≥ 840 dp): Tablet quer (Küche) – Seitenleiste, zwei Spalten.
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return compact;
    if (width < 840) return medium;
    return expanded;
  }

  /// Navigation als Seitenleiste statt unterer Leiste.
  bool get useRail => this != compact;

  /// Inhalte zweispaltig anordnen.
  bool get twoPane => this == expanded;
}

/// Seitenrumpf für alle Bildschirme: begrenzt die Breite, scrollt, und ordnet
/// [primary] und [secondary] bei breitem Fenster nebeneinander an, sonst
/// untereinander. [bottom] bleibt unten fest stehen (z. B. Stopp-Button).
///
/// Nichts wird abgeschnitten: jede Spalte scrollt für sich.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.primary,
    this.secondary,
    this.bottom,
  });

  final Widget primary;
  final Widget? secondary;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final twoPane = secondary != null && WindowSize.of(context).twoPane;

    final Widget content = twoPane
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Tokens.maxTwoPaneWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Pane(child: primary)),
                  Expanded(child: _Pane(child: secondary!)),
                ],
              ),
            ),
          )
        : _Pane(
            maxWidth: Tokens.maxContentWidth,
            child: secondary == null
                ? primary
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      const SizedBox(height: Tokens.l),
                      secondary!,
                    ],
                  ),
          );

    if (bottom == null) return content;
    return Column(
      children: [
        Expanded(child: content),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: twoPane
                  ? Tokens.maxTwoPaneWidth
                  : Tokens.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.m,
                Tokens.s,
                Tokens.m,
                Tokens.m,
              ),
              child: bottom,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget pane = Padding(
      padding: const EdgeInsets.all(Tokens.m),
      child: child,
    );
    if (maxWidth != null) {
      pane = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: pane,
        ),
      );
    }
    return SingleChildScrollView(child: pane);
  }
}
