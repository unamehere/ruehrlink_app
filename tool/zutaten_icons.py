"""Erzeugt die Zutaten-Icons (assets/zutaten/*.svg) im Rührlink-Stil.

Farbige Flächen mit dunkler Kontur, 48er Raster, runde Enden, 2,5 px Linie. Nur Pfade, Kreise und
Rechtecke, damit flutter_svg alles darstellt. Welcher Name zu welchem Icon gehört, steht in
lib/ui/zutat_icons.dart (feste Liste, nichts wird geraten).

    python tool/zutaten_icons.py [vorschau.html]
"""
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "zutaten"
INK = "#2B2D33"
GRUEN = "#6DAA4F"
BLATT = "#7DB35A"


# ---------------------------------------------------------------------------------------------
# Bausteine: Liste von (svg-element, füllfarbe oder None)

def wuerfel(x, y, a=14, t=4):
    return [
        (f'<path d="M{x} {y} L{x+a} {y} L{x+a} {y+a} L{x} {y+a} Z"/>', "#FFFFFF"),
        (f'<path d="M{x} {y} L{x+t} {y-t} L{x+a+t} {y-t} L{x+a} {y} Z"/>', "#EEF1F5"),
        (f'<path d="M{x+a} {y} L{x+a+t} {y-t} L{x+a+t} {y+a-t} L{x+a} {y+a} Z"/>', "#D5DCE6"),
    ]


def tuete(farbe, falz, motiv):
    """Päckchen (Backpulver, Vanillezucker …)."""
    return [
        ('<path d="M12 12 L36 12 L37 41.5 Q37 44 34.5 44 L13.5 44 Q11 44 11 41.5 Z"/>', farbe),
        ('<path d="M12 12 L13 6 L35 6 L36 12 Z"/>', falz),
    ] + motiv


def flasche(farbe, deckel, etikett, motiv):
    return [
        ('<rect x="20" y="3" width="8" height="5" rx="1.5"/>', deckel),
        ('<path d="M21 8 L27 8 L27 13 Q35 16 35 23 L35 41 Q35 44 32 44 L16 44 Q13 44 13 41 L13 23 Q13 16 21 13 Z"/>', farbe),
        ('<path d="M13 26 L35 26 L35 37 L13 37 Z"/>', etikett),
    ] + motiv


def becher(band):
    """Hoher Becher (Joghurt, Quark, Schmand) – nur die Farbe der Banderole unterscheidet."""
    return [
        ('<path d="M12 14 L36 14 L33.2 42 Q33 44 31 44 L17 44 Q15 44 14.8 42 Z"/>', "#FFFFFF"),
        ('<path d="M13.1 24 L34.9 24 L34.1 33 L13.9 33 Z"/>', band),
        ('<rect x="9.5" y="9" width="29" height="5" rx="2"/>', "#D5DCE6"),
    ]


def schale(farbe, inhalt):
    return inhalt + [('<path d="M7 26 L41 26 Q40 43 24 43 Q8 43 7 26 Z"/>', farbe)]


def weinglas(farbe):
    kelch = 'M13 6 L35 6 Q37 20 30 25 Q27 27 24 27 Q21 27 18 25 Q11 20 13 6 Z'
    return [
        (f'<path d="{kelch}"/>', "#FFFFFF"),
        ('<path d="M12.7 13 L35.3 13 Q35.8 21 30 25 Q27 27 24 27 Q21 27 18 25 Q12.2 21 12.7 13 Z" stroke="none"/>', farbe),
        (f'<path d="{kelch}"/>', None),
        ('<path d="M24 27 L24 41 M16 42 L32 42"/>', None),
    ]


def punkte(farbe, pts, r=1.4):
    return [("".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y in pts).replace("/>", ' stroke="none"/>'),
             farbe)]


def eierschale(farbe="#F3E2C2"):
    return [('<path d="M9 28 L13 25 L17 29 L21 25 L25 29 L29 25 L33 29 L36 25 L39 28 Q39 44 24 44 Q9 44 9 28 Z"/>',
             farbe)]


# ---------------------------------------------------------------------------------------------

ICONS = {
    # --- Backen: Grundzutaten -----------------------------------------------------------------
    "mehl": [
        ('<path d="M13 16 L35 16 L37.5 41 Q37.8 44 35 44 L13 44 Q10.2 44 10.5 41 Z"/>', "#EFE4D0"),
        ('<path d="M13 16 L15.5 8 L32.5 8 L35 16"/>', "#E2D3B8"),
        ('<path d="M24 39 L24 24"/>', None),
        ('<path d="M24 34 Q19 33 18.5 28 Q23 28.5 24 32.5 M24 34 Q29 33 29.5 28 Q25 28.5 24 32.5'
         ' M24 28 Q19.5 27 19.5 22.5 Q23.5 23 24 27 M24 28 Q28.5 27 28.5 22.5 Q24.5 23 24 27"/>', "#E7A84A"),
    ],
    "zucker": wuerfel(5, 27) + wuerfel(23, 27) + wuerfel(14, 11),
    "puderzucker": [
        ('<path d="M10 44 Q12 35 24 34 Q36 35 38 44 Z"/>', "#FFFFFF"),
        ('<path d="M31 11 L43 4"/>', None),
        ('<circle cx="21" cy="15" r="11"/>', "#E7EAEE"),
        ('<path d="M13.5 11 L28.5 11 M11 15.5 L31 15.5 M13 20 L29 20" stroke-width="1.3"/>', None),
    ] + punkte("#9AA3AE", [(16, 30), (21, 29), (26, 30.5), (18.5, 26), (23.5, 25.5)], 1.2),
    "vanillezucker": tuete("#F6E7A8", "#E8CF6A", [
        ('<path d="M16 38 Q21 27 32 20" stroke="#5A3A22" stroke-width="4"/>', None),
    ]),
    "backpulver": tuete("#FFFFFF", "#D9534F", [
        ('<path d="M11.7 22 L36.3 22 L36.7 32 L11.3 32 Z"/>', "#D9534F"),
    ] + punkte("#FFFFFF", [(18, 27), (24, 27), (30, 27)], 1.8)),
    "sahnesteif": tuete("#DDEBF7", "#5B8FCB", [
        ('<path d="M16 37 Q16 30 21 31 Q22 25 26.5 26 Q32 25 31 31 Q35 31.5 33 37 Z"/>', "#FFFFFF"),
    ]),
    "trockenhefe": tuete("#EFE0B9", "#C9A86A",
                         punkte("#A57E40", [(18, 24), (24, 21), (30, 25), (21, 30), (28, 32), (17, 36), (25, 38),
                                            (31, 38)], 1.7)),
    "hefe": [
        ('<path d="M7 24 L25 24 L25 41 L7 41 Z"/>', "#E9D7A8"),
        ('<path d="M7 24 L15 17 L33 17 L25 24 Z"/>', "#F2E4BE"),
        ('<path d="M25 24 L33 17 L33 34 L25 41 Z"/>', "#D9C38C"),
        ('<path d="M33 34 L36 31 L41 33 L40 38 L35 39 Z M37 25 L40 24 L42 27 L39 29 Z"/>', "#E9D7A8"),
    ],
    "speisestaerke": [
        ('<path d="M12 14 L32 14 L32 44 L12 44 Z"/>', "#F2C94C"),
        ('<path d="M12 14 L17 9 L37 9 L32 14 Z"/>', "#F7DC80"),
        ('<path d="M32 14 L37 9 L37 39 L32 44 Z"/>', "#E0B13A"),
        ('<ellipse cx="22" cy="29" rx="5" ry="7"/>', "#FFFFFF"),
    ],
    "kakao": [
        ('<path d="M12 14 L36 14 L36 42 Q36 44 34 44 L14 44 Q12 44 12 42 Z"/>', "#7A4A2E"),
        ('<rect x="10" y="9" width="28" height="6" rx="2"/>', "#5C3620"),
        ('<path d="M12 22 L36 22 L36 36 L12 36 Z"/>', "#F1E4D0"),
        ('<path d="M17 33 Q19 27 24 27 Q29 27 31 33 Z"/>', "#7A4A2E"),
    ],
    "schokolade": [
        ('<rect x="9" y="6" width="30" height="36" rx="3"/>', "#6B3E26"),
        ('<path d="M9 18 L39 18 M24 6 L24 30"/>', None),
        ('<path d="M8 31 L12 28 L16 31 L20 28 L24 31 L28 28 L32 31 L36 28 L40 31 L40 44 L8 44 Z"/>', "#C9CED6"),
        ('<path d="M8 37 L40 37 L40 44 L8 44 Z"/>', "#C2410C"),
    ],
    "honig": [
        ('<path d="M14 14 Q9 18 9 26 L9 38 Q9 44 15 44 L33 44 Q39 44 39 38 L39 26 Q39 18 34 14 Z"/>', "#F2A33A"),
        ('<rect x="13" y="7" width="22" height="7" rx="2"/>', "#8A5B38"),
        ('<path d="M24 25 L30 28.5 L30 35.5 L24 39 L18 35.5 L18 28.5 Z"/>', "#FFE08A"),
    ],
    "vanille": [
        ('<path d="M7 41 Q20 35 30 21 Q36 12 42 7 Q39 15 33 23 Q23 37 9 43 Z"/>', "#4A2E1E"),
        ('<circle cx="11" cy="11" r="3.6"/><circle cx="19" cy="11" r="3.6"/><circle cx="15" cy="5.5" r="3.6"/>'
         '<circle cx="11.5" cy="17" r="3.6"/><circle cx="18.5" cy="17" r="3.6"/>', "#FFF6D6"),
        ('<circle cx="15" cy="12.5" r="2.4"/>', "#F2C94C"),
    ],
    "zimt": [
        ('<rect x="5" y="16" width="38" height="8" rx="4" transform="rotate(-20 24 20)"/>', "#B66A3C"),
        ('<rect x="5" y="27" width="38" height="8" rx="4" transform="rotate(-20 24 31)"/>', "#C97B48"),
        ('<path d="M10 23 Q8 19 11 18 M11 35 Q9 31 12 30" stroke-width="1.8"/>', None),
    ],
    # --- Milchprodukte und Ei -------------------------------------------------------------------
    "milch": [
        ('<path d="M14 20 L34 20 L34 42 Q34 44 32 44 L16 44 Q14 44 14 42 Z"/>', "#FFFFFF"),
        ('<path d="M14 20 L19 11 L29 11 L34 20 Z"/>', "#E9EEF4"),
        ('<path d="M19 11 L19 6 L29 6 L29 11"/>', "#E9EEF4"),
        ('<path d="M14 27 L34 27 L34 37 L14 37 Z"/>', "#5B8FCB"),
        ('<path d="M24 29.5 Q27 33 27 34 A3 3 0 0 1 21 34 Q21 33 24 29.5 Z"/>', "#FFFFFF"),
    ],
    "sahne": schale("#5B8FCB", [
        ('<path d="M10 26 Q10 17 17 18 Q18 10 25 11 Q32 9 33 17 Q39 17 38 26 Z"/>', "#FFFDF7"),
        ('<path d="M21 11.5 Q24 6 27 11"/>', None),
    ]),
    "joghurt": becher("#E7A3B5"),
    "quark": becher("#9CC5A1"),
    "schmand": becher("#F2C94C"),
    "frischkaese": [
        ('<path d="M9 22 L39 22 L37 40 Q36.8 42 35 42 L13 42 Q11.2 42 11 40 Z"/>', "#FFFFFF"),
        ('<path d="M10.1 29 L37.9 29 L37.3 35 L10.7 35 Z"/>', "#9CC5A1"),
        ('<path d="M7 17 Q7 14 10 14 L38 14 Q41 14 41 17 L41 22 L7 22 Z"/>', "#D5DCE6"),
    ],
    "kaese": [
        ('<path d="M6 22 L30 10 L42 22 Z"/>', "#FAE08A"),
        ('<path d="M6 22 L42 22 L42 40 L6 40 Z"/>', "#F6D46B"),
    ] + punkte("#E2B23A", [(14, 30), (27, 34), (35, 28)], 2.6),
    "butter": [
        ('<path d="M5 35 L43 35 L39 42 L9 42 Z"/>', "#E7EAEE"),
        ('<path d="M11 24 L31 24 L31 35 L11 35 Z"/>', "#F6D46B"),
        ('<path d="M11 24 L17 17 L37 17 L31 24 Z"/>', "#FAE49A"),
        ('<path d="M31 24 L37 17 L37 28 L31 35 Z"/>', "#E9BE48"),
    ],
    "ei": [
        ('<path d="M24 5 C33 5 39 19 39 29 C39 38 32 44 24 44 C16 44 9 38 9 29 C9 19 15 5 24 5 Z"/>', "#F3E2C2"),
        ('<path d="M15.5 26 Q16.5 18 20 13"/>', None),
    ],
    "eigelb": [('<circle cx="24" cy="18" r="9"/>', "#F6B73C")] + eierschale(),
    "eiweiss": [
        ('<path d="M13 27 Q9 18 16 15 Q18 8 25 9 Q33 8 34 15 Q40 18 36 27 Z"/>', "#FFFFFF"),
    ] + eierschale(),
    # --- Flüssiges und Würze ----------------------------------------------------------------------
    "wasser": [
        ('<path d="M24 5 C24 5 38 21 38 30 A14 14 0 0 1 10 30 C10 21 24 5 24 5 Z"/>', "#6FB1E6"),
        ('<path d="M17 30 A7 7 0 0 0 22 37"/>', None),
    ],
    "oel": flasche("#F2C94C", "#8A5B38", "#FFF6D6", [
        ('<circle cx="24" cy="31.5" r="3.6"/>', "#F2A33A"),
    ]),
    "olivenoel": flasche("#9DB050", "#4F5E22", "#F4F0DC", [
        ('<ellipse cx="24" cy="31.5" rx="3.6" ry="2.7"/>', "#5E7A24"),
    ]),
    "weisswein": weinglas("#F2DE8A"),
    "rotwein": weinglas("#9E2B3A"),
    "salz": [
        ('<path d="M15 21 L33 21 L35.5 41 Q35.8 44 33 44 L15 44 Q12.2 44 12.5 41 Z"/>', "#F4F6F8"),
        ('<path d="M15 21 Q15 10 24 10 Q33 10 33 21 Z"/>', "#B9C0C9"),
        ('<path d="M14.5 33 L33.5 33 L34.6 41.5 Q34.8 43.5 33 43.5 L15 43.5 Q13.2 43.5 13.4 41.5 Z" stroke="none"/>',
         "#FFFFFF"),
        ('<circle cx="20" cy="16" r="0.6"/><circle cx="24" cy="14" r="0.6"/><circle cx="28" cy="16" r="0.6"/>', INK),
    ],
    "pfeffer": [
        ('<circle cx="24" cy="6.5" r="3"/>', "#7A4E2E"),
        ('<path d="M17 16 Q17 10 24 10 Q31 10 31 16 Z"/>', "#7A4E2E"),
        ('<path d="M17 16 L31 16 Q28 22 28 28 Q28 34 32 39 L32 42 Q32 44 30 44 L18 44 Q16 44 16 42 L16 39'
         ' Q20 34 20 28 Q20 22 17 16 Z"/>', "#B07C52"),
    ],
    "muskat": [
        ('<ellipse cx="24" cy="25" rx="14" ry="17"/>', "#A0673F"),
        ('<path d="M17 15 Q23 21 20 30 Q18 36 22 41 M27 9 Q25 18 31 23 Q35 28 32 37" stroke="#6E4228"'
         ' stroke-width="2"/>', None),
    ],
    "zitrone": [
        ('<path d="M7 26 Q7 14 19 11 Q30 8 38 15 Q43 18 43 24 Q42 28 40 30 Q38 40 26 41 Q14 42 9 33'
         ' Q5 30 7 26 Z"/>', "#F6D74A"),
        ('<path d="M30 10 Q35 3 42 5 Q39 12 30 10 Z"/>', BLATT),
        ('<path d="M14 23 Q16 17 22 15.5" stroke="#FFF3B8" stroke-width="2.5"/>', None),
    ],
    "zitronensaft": [
        ('<circle cx="24" cy="25" r="17"/>', "#F6D74A"),
        ('<circle cx="24" cy="25" r="12.5" stroke-width="1.8"/>', "#FBEA9C"),
        ('<path d="M24 12.5 L24 37.5 M13.2 18.8 L34.8 31.2 M13.2 31.2 L34.8 18.8" stroke="#F2C94C" stroke-width="2"/>',
         None),
    ],
    # --- Nüsse ------------------------------------------------------------------------------------
    "mandeln": [
        ('<path d="M20 6 C27 11 30 20 28 29 C26.5 37 22.5 42 18.5 42 C14.5 42 11 37 10.5 29 C10 19 13.5 11 20 6 Z"'
         ' transform="rotate(-18 19 24)"/>', "#C08552"),
        ('<path d="M33 10 C39 15 41 23 39.5 31 C38 38 35 42 31.5 42 C28 42 25.5 38 25 31 C24.5 23 27 15 33 10 Z"'
         ' transform="rotate(16 32 26)"/>', "#D39A66"),
        ('<path d="M17 16 Q14.5 23 16 31 M32.5 19 Q30.5 25 32 32"/>', None),
    ],
    "haselnuss": [
        ('<path d="M24 14 Q36 14 37 28 Q37 42 24 42 Q11 42 11 28 Q12 14 24 14 Z"/>', "#B07A47"),
        ('<ellipse cx="24" cy="35" rx="6" ry="3" stroke="none"/>', "#D2A274"),
        ('<path d="M11 23 Q12 12 24 12 Q36 12 37 23 Q30 19.5 24 19.5 Q18 19.5 11 23 Z"/>', "#7A5230"),
        ('<path d="M24 12 L24 6"/>', None),
    ],
    "walnuss": [
        ('<path d="M24 7 Q39 8 40 25 Q39 42 24 43 Q9 42 8 25 Q9 8 24 7 Z"/>', "#C99A62"),
        ('<path d="M24 7 L24 43 M15 16 Q19 21 15 26 Q12 31 17 36 M33 16 Q29 21 33 26 Q36 31 31 36"/>', None),
    ],
    # --- Gemüse und Obst --------------------------------------------------------------------------
    "zwiebel": [
        ('<path d="M20 42 L19 45.5 M24 42 L24 46 M28 42 L29 45.5 M24 9 L24 4"/>', None),
        ('<path d="M24 8 Q26 14 32 18 Q40 23 39 32 Q37 42 24 42 Q11 42 9 32 Q8 23 16 18 Q22 14 24 8 Z"/>', "#D99A5B"),
        ('<path d="M24 15 Q17 25 20 41 M24 15 Q31 25 28 41" stroke-width="2"/>', None),
    ],
    "knoblauch": [
        ('<path d="M19 42 L18 45.5 M24 42 L24 46 M29 42 L30 45.5"/>', None),
        ('<path d="M24 6 Q25 12 30 15 Q41 20 40 31 Q38 42 24 42 Q10 42 8 31 Q7 20 18 15 Q23 12 24 6 Z"/>', "#F4EFE6"),
        ('<path d="M24 14 Q18 25 22 41 M24 14 Q30 25 26 41 M16 19 Q12 29 15 38 M32 19 Q36 29 33 38"'
         ' stroke-width="2"/>', None),
    ],
    "tomate": [
        ('<path d="M24 14 Q40 13 41 28 Q40 43 24 43 Q8 43 7 28 Q8 13 24 14 Z"/>', "#E0533D"),
        ('<path d="M14 27 Q15 22 19 20" stroke="#F4A091" stroke-width="2.5"/>', None),
        ('<path d="M24 16 L19 11 L22 16 L14 15 L21 18.5 L17 22 L24 19.5 L31 22 L27 18.5 L34 15 L26 16 L29 11 Z"'
         ' stroke-width="2"/>', GRUEN),
        ('<path d="M24 15 L24 7"/>', None),
    ],
    "kartoffel": [
        ('<path d="M10 22 Q12 11 25 11 Q39 11 40 23 Q41 32 35 38 Q28 44 18 42 Q8 39 9 30 Q8 26 10 22 Z"/>', "#D2AA6C"),
    ] + punkte("#9C7442", [(18, 20), (30, 18), (33, 31), (21, 34)], 1.6),
    "karotte": [
        ('<path d="M30 16 Q30 6 36 4 Q34 10 33 14 Q38 6 44 8 Q38 12 35 16 Q42 14 44 19 Q37 20 32 19 Z"/>', GRUEN),
        ('<path d="M30 15 Q37 21 32 26 L12 44 Q8.5 45.5 9 42 L24 18 Q27 12 30 15 Z"/>', "#EE8A3C"),
        ('<path d="M17 33 L21 35 M22 26 L26 28" stroke-width="2"/>', None),
    ],
    "apfel": [
        ('<path d="M24 15 Q30 10 36 12 Q43 15 42 26 Q41 38 34 42 Q29 45 24 42 Q19 45 14 42 Q7 38 6 26'
         ' Q5 15 12 12 Q18 10 24 15 Z"/>', "#D9493F"),
        ('<path d="M24 15 Q24 9 27 5"/>', None),
        ('<path d="M27 9 Q32 3 39 5 Q35 11 27 9 Z"/>', BLATT),
        ('<path d="M12 22 Q13 18 17 16.5" stroke="#F09A92" stroke-width="2.5"/>', None),
    ],
    "banane": [
        ('<path d="M8 12 Q6 30 18 38 Q30 45 42 38 Q44 35.5 41 35 Q30 38 22 31 Q14 24 13 12 Q11 9 8 12 Z"/>', "#F6D04D"),
        ('<path d="M8.5 11 L9 6.5 L12 7 L12.5 11"/>', "#8A6A2E"),
        ('<path d="M16 21 Q19 30 29 34.5" stroke="#E0B233" stroke-width="2"/>', None),
    ],
    "erdbeere": [
        ('<path d="M24 44 Q8 34 9 22 Q10 14 18 14 Q21 15 24 15 Q27 15 30 14 Q38 14 39 22 Q40 34 24 44 Z"/>', "#E04B4B"),
    ] + punkte("#FBE38A", [(17, 23), (24, 22), (31, 23), (20.5, 30), (27.5, 30), (24, 37)], 1.2) + [
        ('<path d="M24 17 L16 12.5 L21 11.5 L18 6 L24 9 L30 6 L27 11.5 L32 12.5 Z" stroke-width="2"/>', GRUEN),
    ],
    "beeren": [
        ('<circle cx="16.5" cy="31" r="9.5"/>', "#4E63B5"),
        ('<circle cx="31.5" cy="31" r="9.5"/>', "#5A70C4"),
        ('<circle cx="24" cy="17" r="9.5"/>', "#4659A8"),
    ] + punkte("#2E3D7A", [(16.5, 26.5), (31.5, 26.5), (24, 12.5)], 1.8),
    "kraeuter": [
        ('<path d="M24 45 L24 14"/>', None),
        ('<path d="M24 22 Q14 20 12 11 Q22 11 24 22 Z M24 22 Q34 20 36 11 Q26 11 24 22 Z'
         ' M24 33 Q13 32 10 23 Q21 23 24 33 Z M24 33 Q35 32 38 23 Q27 23 24 33 Z'
         ' M24 14 Q19.5 8 24 3 Q28.5 8 24 14 Z"/>', GRUEN),
    ],
    # --- Herzhaft ---------------------------------------------------------------------------------
    "reis": schale("#C9A27A", [
        ('<path d="M9.5 26 Q12 15 24 15 Q36 15 38.5 26 Z"/>', "#FFFFFF"),
    ] + punkte("#D8CFC0", [(17, 22), (22, 19), (27, 21.5), (32, 23), (24, 24)], 1.2)),
    "nudeln": [
        ('<path d="M21 20 L7 10 Q3 24 7 38 L21 28 Z M27 20 L41 10 Q45 24 41 38 L27 28 Z"/>', "#F2D27A"),
        ('<path d="M10 15 Q8 24 10 33 M38 15 Q40 24 38 33" stroke-width="1.6"/>', None),
        ('<rect x="20" y="17" width="8" height="14" rx="3"/>', "#E6B94E"),
    ],
    "fleisch": [
        ('<path d="M10 18 Q14 9 26 10 Q40 11 41 22 Q42 33 32 38 Q22 43 14 38 Q6 32 10 18 Z"/>', "#D96B6B"),
        ('<path d="M13 35 Q8.5 29 11 20" stroke="#F6E7DA" stroke-width="3"/>', None),
        ('<circle cx="29" cy="23" r="4.5"/>', "#F6E7DA"),
    ],
    "speck": [
        ('<path d="M6 12 Q14 6 22 12 Q30 18 42 10 L42 22 Q30 30 22 24 Q14 18 6 24 Z"/>', "#D9726B"),
        ('<path d="M6 18 Q14 12 22 18 Q30 24 42 16" stroke="#F6E2D3" stroke-width="3"/>', None),
        ('<path d="M6 26 Q14 20 22 26 Q30 32 42 24 L42 36 Q30 44 22 38 Q14 32 6 38 Z"/>', "#E07F77"),
        ('<path d="M6 32 Q14 26 22 32 Q30 38 42 30" stroke="#F6E2D3" stroke-width="3"/>', None),
    ],
}


def svg(shapes) -> str:
    teile = "".join(f'<g fill="{farbe or "none"}" stroke="{INK}">{el}</g>' for el, farbe in shapes)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" '
            f'stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">{teile}</svg>\n')


def vorschau(ziel: Path):
    zellen = "".join(f'<figure>{svg(s)}<figcaption>{n}</figcaption></figure>' for n, s in ICONS.items())
    ziel.write_text(f"""<!doctype html><html lang="de"><head><meta charset="utf-8"><title>Zutaten-Icons</title>
<style>body{{margin:0;font-family:"Segoe UI",Roboto,sans-serif;background:#F7F3EE}}
main{{max-width:980px;margin:0 auto;padding:20px}}
.grid{{display:grid;grid-template-columns:repeat(10,1fr);gap:8px 4px;padding:16px;border-radius:14px}}
.hell{{background:#fff}} .dunkel{{background:#1C1D21;color:#EDE7DE;margin-top:14px}}
.dunkel svg{{background:#F4EFE8;border-radius:12px;padding:5px}}
figure{{margin:0;text-align:center}} svg{{width:56px;height:56px}} figcaption{{font-size:11px}}</style>
</head><body><main><div class="grid hell">{zellen}</div><div class="grid dunkel">{zellen}</div></main></body></html>""",
                    encoding="utf-8")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shapes in ICONS.items():
        (OUT / f"{name}.svg").write_text(svg(shapes), encoding="utf-8")
    print(f"{len(ICONS)} Icons → {OUT}")
    if len(sys.argv) > 1:
        vorschau(Path(sys.argv[1]))
