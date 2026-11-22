import '../../l10n/l10n.dart';
import '../../ui/illustrations.dart';
import 'assistent.dart';
import 'rechner.dart';
import 'werte.dart';

/// Alle Assistenten in der Reihenfolge auf dem Kochen-Tab.
const List<Assistent> alleAssistenten = [
  PizzaAssistent(),
  TeigAssistent(),
  EischneeAssistent(),
  SahneAssistent(),
  SchokoladeAssistent(),
];

Assistent? assistentMitId(String id) {
  for (final a in alleAssistenten) {
    if (a.id == id) return a;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Texte zu Werten (auch für die Ergebnisseite)

String mehlName(AppLocalizations l10n, Mehl m) => switch (m) {
  Mehl.weizen405 => l10n.asFlourW405,
  Mehl.weizen550 => l10n.asFlourW550,
  Mehl.weizen1050 => l10n.asFlourW1050,
  Mehl.weizenVollkorn => l10n.asFlourWWhole,
  Mehl.dinkel630 => l10n.asFlourD630,
  Mehl.dinkelVollkorn => l10n.asFlourDWhole,
};

String? _mehlDetail(AppLocalizations l10n, Mehl m) => switch (m) {
  Mehl.dinkel630 || Mehl.dinkelVollkorn => l10n.asFlourSpeltDetail,
  Mehl.weizenVollkorn => l10n.asFlourWholeDetail,
  Mehl.weizen405 => l10n.asFlourW405Detail,
  _ => null,
};

String schokoladeName(AppLocalizations l10n, Schokolade s) => switch (s) {
  Schokolade.zartbitter => l10n.asChocDark,
  Schokolade.vollmilch => l10n.asChocMilk,
  Schokolade.weiss => l10n.asChocWhite,
};

// ---------------------------------------------------------------------------
// Texte zu Zutaten und Hinweisen (Ergebnisseite, „Als Rezept speichern“)

String zutatName(AppLocalizations l10n, ZutatMenge z) => switch (z.zutat) {
  Zutat.mehl =>
    z.sorte is Mehl
        ? l10n.asIngFlourOf(mehlName(l10n, z.sorte! as Mehl))
        : l10n.asIngFlour,
  Zutat.wasser => l10n.asIngWater,
  Zutat.salz => l10n.asIngSalt,
  Zutat.hefeFrisch => l10n.asIngYeastFresh,
  Zutat.hefeTrocken => l10n.asIngYeastDry,
  Zutat.olivenoel => l10n.asIngOil,
  Zutat.eiweiss => l10n.asIngEggWhite,
  Zutat.prisesalz => l10n.asIngSalt,
  Zutat.sahne => l10n.asIngCream,
  Zutat.schokolade =>
    z.sorte is Schokolade
        ? schokoladeName(l10n, z.sorte! as Schokolade)
        : l10n.asIngChocolate,
};

String mengeText(AppLocalizations l10n, ZutatMenge z) {
  final m = z.menge;
  final zahl = m == m.roundToDouble()
      ? '${m.round()}'
      : m.toStringAsFixed(1).replaceAll('.', ',');
  return switch (z.einheit) {
    Einheit.g => '$zahl g',
    Einheit.ml => '$zahl ml',
    Einheit.stueck => zahl,
    Einheit.prise => l10n.asPinch,
  };
}

String hinweisText(AppLocalizations l10n, Hinweis h) => switch (h) {
  Hinweis.knopfNachRuhe => l10n.asHintPressAfterRest,
  Hinweis.wenigMehl => l10n.asHintLittleFlour(TeigWerte.minMehlG),
  Hinweis.vielMehl => l10n.asHintMuchFlour(TeigWerte.maxMehlG),
  Hinweis.fettfrei => l10n.asHintGreaseFree,
  Hinweis.lieberKuerzer => l10n.asHintRatherShort,
  Hinweis.schokoladeHacken => l10n.asHintChopChocolate,
  Hinweis.warmhalten => l10n.asHintKeepWarm,
  Hinweis.spritzschutz => l10n.asHintSplashGuard,
};

// ---------------------------------------------------------------------------
// Gemeinsame Fragen der Teig-Assistenten

const _mehlBild = 'mehl';

Frage _mehlFrage(List<Mehl> sorten, Mehl standard) => Frage(
  id: 'mehl',
  titel: (l) => l.asQFlour,
  optionen: (_) => [
    for (final m in sorten)
      Option(
        m,
        (l) => mehlName(l, m),
        detail: _mehlHatDetail(m) ? (l) => _mehlDetail(l, m)! : null,
        bild: Illustrations.forName(_mehlBild),
      ),
  ],
  standard: (_) => standard,
);

bool _mehlHatDetail(Mehl m) => m != Mehl.weizen550 && m != Mehl.weizen1050;

final _wasserFrage = Frage(
  id: 'wasser',
  titel: (l) => l.asQWater,
  detail: (l) => l.asQWaterDetail,
  optionen: (a) {
    final empfohlen = _empfohleneHydration(a);
    final werte = {...TeigWerte.hydrationen, empfohlen}.toList()..sort();
    return [
      for (final h in werte)
        Option(
          h,
          (l) => l.asPercent(h),
          detail: (l) => h == empfohlen
              ? l.asRecommended
              : h < empfohlen
              ? l.asWaterFirmer
              : l.asWaterSofter,
        ),
    ];
  },
  standard: _empfohleneHydration,
);

int _empfohleneHydration(Antworten a) {
  final m = a['mehl'];
  return TeigWerte.mehl[m is Mehl ? m : Mehl.weizen550]!.hydrationStandard;
}

final _hefeFrage = Frage(
  id: 'hefe',
  titel: (l) => l.asQYeast,
  optionen: (_) => [
    Option(
      Hefe.frisch,
      (l) => l.asYeastFresh,
      detail: (l) => l.asYeastFreshDetail,
    ),
    Option(
      Hefe.trocken,
      (l) => l.asYeastDry,
      detail: (l) => l.asYeastDryDetail,
    ),
  ],
  standard: (_) => Hefe.frisch,
);

Frage _gehzeitFrage(Gehzeit standard) => Frage(
  id: 'gehzeit',
  titel: (l) => l.asQRise,
  detail: (l) => l.asQRiseDetail,
  optionen: (_) => [
    Option(
      Gehzeit.kurz,
      (l) => l.asRiseShort,
      detail: (l) => l.asRiseShortDetail,
    ),
    Option(
      Gehzeit.mittel,
      (l) => l.asRiseMid,
      detail: (l) => l.asRiseMidDetail,
    ),
    Option(
      Gehzeit.lang,
      (l) => l.asRiseLong,
      detail: (l) => l.asRiseLongDetail,
    ),
  ],
  standard: (_) => standard,
);

// ---------------------------------------------------------------------------
// Pizzateig

class PizzaAssistent extends Assistent {
  const PizzaAssistent();

  @override
  String get id => 'pizzateig';
  @override
  String titel(AppLocalizations l10n) => l10n.asPizzaTitle;
  @override
  String untertitel(AppLocalizations l10n) => l10n.asPizzaSub;
  @override
  String get bild => Illustrations.forName('pizza') ?? Illustrations.bowl;

  @override
  List<Frage> get fragen => [
    Frage(
      id: 'anzahl',
      titel: (l) => l.asQPizzaCount,
      detail: (l) => l.asQPizzaCountDetail(TeigWerte.pizzaTeiglingG),
      optionen: (_) => [
        for (final n in TeigWerte.pizzaAnzahl)
          Option(n, (l) => l.asPizzaCount(n)),
      ],
      standard: (_) => 4,
    ),
    _mehlFrage(const [
      Mehl.weizen405,
      Mehl.weizen550,
      Mehl.dinkel630,
    ], Mehl.weizen405),
    _wasserFrage,
    _hefeFrage,
    _gehzeitFrage(Gehzeit.mittel),
  ];

  @override
  String programmName(AppLocalizations l10n, Antworten a) =>
      l10n.asPizzaName(wert<int>(a, 'anzahl'));

  @override
  String rezeptTitel(AppLocalizations l10n) => l10n.asSaveTitlePizza;

  @override
  int portionen(Antworten a) => wert<int>(a, 'anzahl');

  @override
  AssistentPlan plan(Antworten a) {
    final hydration = wert<int>(a, 'wasser');
    final gehzeit = wert<Gehzeit>(a, 'gehzeit');
    return teigPlan(
      art: TeigArt.pizza,
      mehl: wert<Mehl>(a, 'mehl'),
      mehlG: pizzaMehlG(
        wert<int>(a, 'anzahl'),
        hydration: hydration,
        gehzeit: gehzeit,
      ),
      hydration: hydration,
      hefe: wert<Hefe>(a, 'hefe'),
      gehzeit: gehzeit,
    );
  }
}

// ---------------------------------------------------------------------------
// Brot- und Hefeteig (Teig-Rechner)

class TeigAssistent extends Assistent {
  const TeigAssistent();

  @override
  String get id => 'brotteig';
  @override
  String titel(AppLocalizations l10n) => l10n.asDoughTitle;
  @override
  String untertitel(AppLocalizations l10n) => l10n.asDoughSub;
  @override
  String get bild => Illustrations.forName('brot') ?? Illustrations.bowl;

  @override
  List<Frage> get fragen => [
    _mehlFrage(Mehl.values, Mehl.weizen550),
    Frage(
      id: 'menge',
      titel: (l) => l.asQFlourAmount,
      detail: (l) => l.asQFlourAmountDetail(TeigWerte.maxMehlG),
      optionen: (_) => [
        for (final g in TeigWerte.brotMehlG) Option(g, (l) => l.asGrams(g)),
      ],
      standard: (_) => 500,
    ),
    _wasserFrage,
    _hefeFrage,
    _gehzeitFrage(Gehzeit.kurz),
  ];

  @override
  String programmName(AppLocalizations l10n, Antworten a) => l10n.asDoughName(
    mehlName(l10n, wert<Mehl>(a, 'mehl')),
    wert<int>(a, 'menge'),
  );

  @override
  String rezeptTitel(AppLocalizations l10n) => l10n.asSaveTitleDough;

  @override
  AssistentPlan plan(Antworten a) => teigPlan(
    art: TeigArt.brot,
    mehl: wert<Mehl>(a, 'mehl'),
    mehlG: wert<int>(a, 'menge'),
    hydration: wert<int>(a, 'wasser'),
    hefe: wert<Hefe>(a, 'hefe'),
    gehzeit: wert<Gehzeit>(a, 'gehzeit'),
  );
}

// ---------------------------------------------------------------------------
// Eischnee

class EischneeAssistent extends Assistent {
  const EischneeAssistent();

  @override
  String get id => 'eischnee';
  @override
  String titel(AppLocalizations l10n) => l10n.asEggTitle;
  @override
  String untertitel(AppLocalizations l10n) => l10n.asEggSub;
  @override
  String get bild => Illustrations.forName('eischnee') ?? Illustrations.bowl;

  @override
  List<Frage> get fragen => [
    Frage(
      id: 'anzahl',
      titel: (l) => l.asQEggCount,
      detail: (l) => l.asQEggCountDetail(EischneeWerte.anzahl.last),
      optionen: (_) => [
        for (final n in EischneeWerte.anzahl)
          Option(
            n,
            (l) => l.asEggWhites(n),
            detail: (l) => l.asGramsApprox(n * EischneeWerte.gProEiweiss),
          ),
      ],
      standard: (_) => 4,
    ),
    Frage(
      id: 'steif',
      titel: (l) => l.asQEggFirm,
      optionen: (_) => [
        Option(false, (l) => l.asEggSoft, detail: (l) => l.asEggSoftDetail),
        Option(true, (l) => l.asEggStiff, detail: (l) => l.asEggStiffDetail),
      ],
      standard: (_) => true,
    ),
  ];

  @override
  String programmName(AppLocalizations l10n, Antworten a) =>
      l10n.asEggName(wert<int>(a, 'anzahl'));

  @override
  String rezeptTitel(AppLocalizations l10n) => l10n.asSaveTitleEgg;

  @override
  AssistentPlan plan(Antworten a) => eischneePlan(
    anzahl: wert<int>(a, 'anzahl'),
    steif: wert<bool>(a, 'steif'),
  );
}

// ---------------------------------------------------------------------------
// Sahne

class SahneAssistent extends Assistent {
  const SahneAssistent();

  @override
  String get id => 'sahne';
  @override
  String titel(AppLocalizations l10n) => l10n.asCreamTitle;
  @override
  String untertitel(AppLocalizations l10n) => l10n.asCreamSub;
  @override
  String get bild => Illustrations.forName('sahne') ?? Illustrations.bowl;

  @override
  List<Frage> get fragen => [
    Frage(
      id: 'menge',
      titel: (l) => l.asQCreamAmount,
      optionen: (_) => [
        for (final ml in SahneWerte.mengenMl)
          Option(
            ml,
            (l) => l.asMl(ml),
            detail: (l) => l.asCreamCups(ml ~/ 200),
          ),
      ],
      standard: (_) => 400,
    ),
  ];

  @override
  String programmName(AppLocalizations l10n, Antworten a) =>
      l10n.asCreamName(wert<int>(a, 'menge'));

  @override
  String rezeptTitel(AppLocalizations l10n) => l10n.asSaveTitleCream;

  @override
  AssistentPlan plan(Antworten a) => sahnePlan(ml: wert<int>(a, 'menge'));
}

// ---------------------------------------------------------------------------
// Schokolade schmelzen

class SchokoladeAssistent extends Assistent {
  const SchokoladeAssistent();

  @override
  String get id => 'schokolade';
  @override
  String titel(AppLocalizations l10n) => l10n.asChocTitle;
  @override
  String untertitel(AppLocalizations l10n) => l10n.asChocSub;
  @override
  String get bild => Illustrations.forName('schokolade') ?? Illustrations.bowl;

  @override
  List<Frage> get fragen => [
    Frage(
      id: 'sorte',
      titel: (l) => l.asQChocKind,
      optionen: (_) => [
        for (final s in Schokolade.values)
          Option(
            s,
            (l) => schokoladeName(l, s),
            detail: (l) => l.asUpToDegrees(SchokoladeWerte.temperatur[s]!),
            bild: Illustrations.forName('schokolade'),
          ),
      ],
      standard: (_) => Schokolade.zartbitter,
    ),
    Frage(
      id: 'menge',
      titel: (l) => l.asQChocAmount,
      optionen: (_) => [
        for (final g in SchokoladeWerte.mengenG) Option(g, (l) => l.asGrams(g)),
      ],
      standard: (_) => 200,
    ),
  ];

  @override
  String programmName(AppLocalizations l10n, Antworten a) =>
      l10n.asChocName(schokoladeName(l10n, wert<Schokolade>(a, 'sorte')));

  @override
  String rezeptTitel(AppLocalizations l10n) => l10n.asSaveTitleChoc;

  @override
  AssistentPlan plan(Antworten a) => schokoladePlan(
    sorte: wert<Schokolade>(a, 'sorte'),
    g: wert<int>(a, 'menge'),
  );
}
