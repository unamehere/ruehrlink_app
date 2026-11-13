import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/einrichtung/einrichtung_page.dart';
import 'features/einrichtung/setup_controller.dart';
import 'core/api/bridge_providers.dart';
import 'features/kochen/kochen_page.dart';
import 'features/kochen/programs.dart';
import 'features/kochen/sequence_nudge.dart';
import 'features/maschine/maschine_page.dart';
import 'features/mehr/mehr_page.dart';
import 'features/mehr/pair_request_watcher.dart';
import 'features/mehr/verbindung_page.dart';
import 'features/rezepte/rezepte_page.dart';
import 'l10n/l10n.dart';
import 'ui/layout.dart';
import 'ui/theme.dart';

class FreikochApp extends ConsumerStatefulWidget {
  const FreikochApp({super.key});

  @override
  ConsumerState<FreikochApp> createState() => _FreikochAppState();
}

class _FreikochAppState extends ConsumerState<FreikochApp> {
  // Zurück im Vordergrund (z. B. nach dem Entsperren): sofort neu verbinden und den Stand holen,
  // statt auf das Zeitlimit der eingeschlafenen Verbindung zu warten (Fehlerliste F5).
  late final _lifecycle = AppLifecycleListener(
    onResume: () {
      ref.read(bridgeApiProvider).reconnect();
      ref.invalidate(applianceStatusProvider);
      ref.invalidate(sequenceProvider);
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // anlegen
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => context.l10n.appTitle,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    // Nicht `AppLocalizations.localizationsDelegates`: der Generator kennt
    // material_ui noch nicht und würde die Delegates aus flutter/material nehmen.
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    routerConfig: ref.watch(routerProvider),
  );
}

/// Die vier Tabs der unteren Navigation bzw. Seitenleiste.
const _tabs = [
  (path: '/kochen', icon: Icons.restaurant_rounded),
  (path: '/rezepte', icon: Icons.menu_book_rounded),
  (path: '/maschine', icon: Icons.blender_rounded),
  (path: '/mehr', icon: Icons.more_horiz_rounded),
];

final routerProvider = Provider<GoRouter>((ref) {
  // Router nur neu auswerten (nicht neu bauen), wenn sich der Einrichtungsstatus ändert.
  final refresh = ValueNotifier(0);
  ref.listen(setupDoneProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: _tabs.first.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(setupDoneProvider);
      final inSetup = state.matchedLocation == '/einrichtung';
      if (!done && !inSetup) return '/einrichtung';
      if (done && inSetup) return _tabs.first.path;
      return null;
    },
    routes: [
      GoRoute(
        path: '/einrichtung',
        builder: (context, state) => const EinrichtungPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PairRequestWatcher(
          child: SequenceNudgeWatcher(child: AppShell(shell: shell)),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kochen',
                builder: (context, state) => const KochenPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rezepte',
                builder: (context, state) => const RezeptePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/maschine',
                builder: (context, state) => const MaschinePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mehr',
                builder: (context, state) => const MehrPage(),
                routes: [
                  GoRoute(
                    path: 'verbindung',
                    builder: (context, state) => const VerbindungPage(),
                  ),
                  GoRoute(
                    path: 'hinweise',
                    builder: (context, state) => const NudgeSettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Rahmen um die Tabs: unten eine Leiste (Handy hochkant), sonst eine
/// Seitenleiste links (Tablet, Querformat).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.tabKochen,
      l10n.tabRezepte,
      l10n.tabMaschine,
      l10n.tabMehr,
    ];

    if (!WindowSize.of(context).useRail) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final (i, tab) in _tabs.indexed)
              NavigationDestination(icon: Icon(tab.icon), label: labels[i]),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: LayoutBuilder(
              // Bei wenig Höhe (Handy quer) scrollt die Seitenleiste statt abzuschneiden.
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: _select,
                      groupAlignment: 0,
                      destinations: [
                        for (final (i, tab) in _tabs.indexed)
                          NavigationRailDestination(
                            icon: Icon(tab.icon),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
