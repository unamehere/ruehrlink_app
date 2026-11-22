import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/theme.dart';

/// Fotos der Bildanleitung (eigene Aufnahmen an der KCL95, verkleinert; Gerätekennung der SSID
/// im letzten Bild verpixelt).
const maschineKoppelnBilder = [
  'assets/anleitung/maschine-koppeln/01-startseite-zahnrad.jpg',
  'assets/anleitung/maschine-koppeln/02-einstellungen-wifi.jpg',
  'assets/anleitung/maschine-koppeln/03-wifi-connect.jpg',
  'assets/anleitung/maschine-koppeln/04-wiederherstellung.jpg',
  'assets/anleitung/maschine-koppeln/05-wifi-startet.jpg',
  'assets/anleitung/maschine-koppeln/06-ssid-angezeigt.jpg',
];

List<String> _texte(AppLocalizations l10n) => [
  l10n.helpGuideStep1,
  l10n.helpGuideStep2,
  l10n.helpGuideStep3,
  l10n.helpGuideStep4,
  l10n.helpGuideStep5,
  l10n.helpGuideStep6,
];

/// Öffnet die blätterbare Bildanleitung „So geht's an der Maschine“ als Vollbild.
Future<void> zeigeMaschineKoppelnAnleitung(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const MaschineKoppelnAnleitung(),
      ),
    );

/// Schritt-Anleitung: je Seite ein Foto vom Display der Maschine und ein Satz, was zu tippen ist.
class MaschineKoppelnAnleitung extends StatefulWidget {
  const MaschineKoppelnAnleitung({super.key});

  @override
  State<MaschineKoppelnAnleitung> createState() =>
      _MaschineKoppelnAnleitungState();
}

class _MaschineKoppelnAnleitungState extends State<MaschineKoppelnAnleitung> {
  final _seiten = PageController();
  int _seite = 0;

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  void _gehe(int seite) => _seiten.animateToPage(
    seite,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final texte = _texte(l10n);
    final total = maschineKoppelnBilder.length;
    final letzte = _seite == total - 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.asClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.helpSetupMachineGuide),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _seiten,
                    itemCount: total,
                    onPageChanged: (s) => setState(() => _seite = s),
                    itemBuilder: (context, i) => ListView(
                      padding: const EdgeInsets.all(Tokens.m),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tokens.radius),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.asset(
                              maschineKoppelnBilder[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: Tokens.m),
                        Text(
                          l10n.helpGuideStepOf(i + 1, total),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Tokens.s),
                        Text(texte[i], style: theme.textTheme.titleLarge),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.m,
                    0,
                    Tokens.m,
                    Tokens.m,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(Tokens.tap),
                          ),
                          onPressed: _seite == 0
                              ? null
                              : () => _gehe(_seite - 1),
                          child: Text(l10n.helpGuideBack),
                        ),
                      ),
                      const SizedBox(width: Tokens.m),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(Tokens.tap),
                          ),
                          onPressed: letzte
                              ? () => Navigator.of(context).pop()
                              : () => _gehe(_seite + 1),
                          child: Text(
                            letzte ? l10n.helpGuideDone : l10n.helpGuideNext,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vorschau für den Einrichtungsschritt: erstes Foto, antippen öffnet die Anleitung.
class MaschineKoppelnVorschau extends StatelessWidget {
  const MaschineKoppelnVorschau({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    void oeffnen() => zeigeMaschineKoppelnAnleitung(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(maschineKoppelnBilder.first, fit: BoxFit.cover),
            // Das ganze Bild ist antippbar; für Screenreader reicht der Knopf.
            ExcludeSemantics(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: oeffnen),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s),
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.helpSetupMachineGuide),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surface.withValues(alpha: 0.9),
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: oeffnen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
