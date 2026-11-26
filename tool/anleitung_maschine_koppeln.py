"""Erzeugt die Bildanleitung „Maschine koppeln“ als SVG (assets/anleitung/maschine-koppeln/).

Vereinfachte Zeichnungen des KCL95-Displays statt Fotos: gleiche Beschriftungen wie an der Maschine,
ohne Hintergrundbild, das Ziel jeweils orange markiert. Nur Grundformen, Verläufe und Text, damit
flutter_svg alles darstellt (keine Filter, kein CSS).

    python tool/anleitung_maschine_koppeln.py
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "anleitung" / "maschine-koppeln"

W, H = 800, 560
DX, DY, DW, DH = 90, 60, 620, 390          # Display
ACCENT, GLOW = "#C2410C", "#F2A33A"
PILL, INK, WHITE = "#F4F1EC", "#24262B", "#F4F1EC"
FONT = 'font-family="Roboto, Segoe UI, Arial, sans-serif"'


def frame(body: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <linearGradient id="gehaeuse" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7A7D84"/><stop offset="1" stop-color="#4B4E54"/>
    </linearGradient>
    <linearGradient id="display" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#3A3E46"/><stop offset="1" stop-color="#1B1D21"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="{W}" height="{H}" rx="40" fill="url(#gehaeuse)"/>
  <rect x="{DX - 22}" y="{DY - 22}" width="{DW + 44}" height="{DH + 44}" rx="34" fill="#3B3D42"/>
  <rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" rx="20" fill="url(#display)" stroke="#121316" stroke-width="5"/>
  <circle cx="{W / 2}" cy="{DY + DH + 52}" r="9" fill="none" stroke="#2C2E32" stroke-width="3"/>
{body}
</svg>
"""


def text(x, y, s, size=30, fill=WHITE, weight=500, anchor="middle"):
    return (f'  <text x="{x}" y="{y}" {FONT} font-size="{size}" font-weight="{weight}" fill="{fill}" '
            f'text-anchor="{anchor}">{s}</text>\n')


def pill(x, y, w, h, label=None, size=28, rx=None, anchor="middle"):
    rx = h / 2 if rx is None else rx
    s = f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{PILL}"/>\n'
    if label:
        tx = x + w / 2 if anchor == "middle" else x + 26
        s += text(tx, y + h / 2 + size * 0.36, label, size, INK, 500, anchor)
    return s


def close_btn(x=DX + 18, y=DY + 18):
    return (pill(x, y, 56, 56, rx=12)
            + f'  <path d="M{x + 18} {y + 18} L{x + 38} {y + 38} M{x + 38} {y + 18} L{x + 18} {y + 38}" '
              f'stroke="{INK}" stroke-width="4" stroke-linecap="round"/>\n')


def title(s):
    return text(W / 2, DY + 58, s, 32, WHITE, 600)


def mark(x, y, w, h, rx=16):
    """Orange Rahmen um das Ziel + Tipp-Punkt (rechts bzw. an der Ecke, damit die Beschriftung frei bleibt)."""
    if w > 120:
        cx, cy = x + w - 44, y + h / 2
    else:
        cx, cy = x + w + 4, y + h + 4
    return (f'  <rect x="{x - 7}" y="{y - 7}" width="{w + 14}" height="{h + 14}" rx="{rx + 6}" fill="none" '
            f'stroke="{GLOW}" stroke-width="6"/>\n'
            f'  <circle cx="{cx}" cy="{cy}" r="34" fill="{GLOW}" fill-opacity="0.28"/>\n'
            f'  <circle cx="{cx}" cy="{cy}" r="17" fill="{GLOW}" fill-opacity="0.9" stroke="{WHITE}" stroke-width="3"/>\n')


def gear(cx, cy, r=18, fill=INK):
    pts = []
    teeth = 8
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        rr = r if (i % 4) in (0, 1) else r * 0.74
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return (f'  <polygon points="{" ".join(pts)}" fill="{fill}"/>\n'
            f'  <circle cx="{cx}" cy="{cy}" r="{r * 0.36}" fill="{PILL}"/>\n')


def clock(cx, cy, r=20, col=WHITE):
    return (f'  <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{col}" stroke-width="4"/>\n'
            f'  <path d="M{cx} {cy - r * 0.6} L{cx} {cy} L{cx + r * 0.5} {cy}" fill="none" stroke="{col}" '
            f'stroke-width="4" stroke-linecap="round"/>\n')


def gauge(cx, cy, r=22, col=INK):
    return (f'  <path d="M{cx - r} {cy} A{r} {r} 0 0 1 {cx + r} {cy}" fill="none" stroke="{col}" stroke-width="4" '
            f'stroke-linecap="round"/>\n'
            f'  <path d="M{cx} {cy} L{cx + r * 0.55} {cy - r * 0.6}" stroke="{col}" stroke-width="4" '
            f'stroke-linecap="round"/>\n')


def thermo(cx, cy, col=WHITE, k=1.0):
    return (f'  <rect x="{cx - 6 * k}" y="{cy - 26 * k}" width="{12 * k}" height="{32 * k}" rx="{6 * k}" fill="none" '
            f'stroke="{col}" stroke-width="{4 * k}"/>\n'
            f'  <circle cx="{cx}" cy="{cy + 12 * k}" r="{10 * k}" fill="{col}"/>\n')


def bild1():
    b = ""
    b += pill(DX + 18, DY + 18, 64, 64, rx=14) + gear(DX + 50, DY + 50)
    b += pill(DX + 98, DY + 18, 410, 64, "Programme", 30, rx=16)
    for i in range(3):  # Listen-Symbol
        y = DY + 38 + i * 12
        b += f'  <circle cx="{DX + 128}" cy="{y}" r="3" fill="{INK}"/><rect x="{DX + 138}" y="{y - 2.5}" width="22" height="5" rx="2.5" fill="{INK}"/>\n'
    b += pill(DX + 524, DY + 18, 64, 64, rx=14)
    b += (f'  <path d="M{DX + 540} {DY + 66} L{DX + 545} {DY + 38} L{DX + 567} {DY + 38} L{DX + 572} {DY + 66} Z" '
          f'fill="none" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>\n')
    b += f'  <circle cx="{W / 2}" cy="{DY + 225}" r="92" fill="{PILL}"/>\n' + gauge(W / 2, DY + 205)
    b += text(W / 2, DY + 262, "Off", 40, INK, 500)
    b += clock(DX + 130, DY + 175) + text(DX + 130, DY + 250, "00:00", 40)
    b += thermo(DX + 490, DY + 178) + text(DX + 490, DY + 250, "Off", 40)
    b += mark(DX + 18, DY + 18, 64, 64, 14)
    return b


def bild2():
    b = close_btn() + title("Einstellungen")
    b += pill(DX + 185, DY + 98, 250, 50)
    b += text(DX + 250, DY + 133, "Zero", 26, INK)
    b += clock(DX + 325, DY + 123, 13, INK).replace('stroke-width="4"', 'stroke-width="3"')
    b += gauge(DX + 372, DY + 130, 14).replace('stroke-width="4"', 'stroke-width="3"')
    b += thermo(DX + 410, DY + 124, INK, 0.65)
    rows = ["WiFi", "Bildschirmschoner", "Helligkeit", "Signaltöne"]
    for i, r in enumerate(rows):
        b += pill(DX + 40, DY + 168 + i * 54, 540, 44, r, 26, rx=14, anchor="start")
    b += mark(DX + 40, DY + 168, 540, 44, 14)
    return b


def bild3():
    b = close_btn() + title("WiFi")
    b += text(DX + 230, DY + 140, "Off", 28, "#B9B6B0", 500)
    b += f'  <rect x="{DX + 272}" y="{DY + 116}" width="76" height="34" rx="17" fill="{PILL}"/>\n'
    b += f'  <circle cx="{DX + 331}" cy="{DY + 133}" r="13" fill="{ACCENT}"/>\n'
    b += text(DX + 395, DY + 140, "Ein", 28, WHITE, 600)
    b += pill(DX + 50, DY + 190, 520, 60, "Connect …", 30, rx=16)
    b += pill(DX + 50, DY + 272, 520, 60, "Netzwerk ignorieren …", 28, rx=16)
    b += mark(DX + 50, DY + 190, 520, 60, 16)
    return b


def warte(cy):
    s = ""
    for i in range(3):
        s += f'  <circle cx="{W / 2 - 30 + i * 30}" cy="{cy}" r="8" fill="{WHITE}" fill-opacity="{0.35 + 0.3 * i}"/>\n'
    return s


def bild4():
    b = title("WiFi")
    b += text(W / 2, DY + 190, "Wiederherstellung der", 32)
    b += text(W / 2, DY + 232, "Standardeinstellungen …", 32)
    b += warte(DY + 300)
    return b


def bild5():
    b = close_btn() + title("Verbinden")
    b += text(W / 2, DY + 210, "WiFi startet …", 34)
    b += warte(DY + 280)
    return b


def bild6():
    b = close_btn() + title("Verbinden")
    b += text(DX + 120, DY + 215, "SSID:", 34, WHITE, 500, "start")
    b += text(DX + 245, DY + 215, "KENWOOD", 34, WHITE, 600, "start")
    for i in range(4):
        b += f'  <rect x="{DX + 438 + i * 22}" y="{DY + 190}" width="16" height="30" rx="4" fill="#8A8D94" fill-opacity="0.7"/>\n'
    cx, cy = W / 2, DY + 300
    b += (f'  <circle cx="{cx}" cy="{cy}" r="32" fill="#22A045"/>\n'
          f'  <path d="M{cx - 14} {cy} L{cx - 4} {cy + 11} L{cx + 16} {cy - 11}" fill="none" stroke="{WHITE}" '
          f'stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>\n')
    return b


BILDER = {
    "01-startseite-zahnrad.svg": bild1,
    "02-einstellungen-wifi.svg": bild2,
    "03-wifi-connect.svg": bild3,
    "04-wiederherstellung.svg": bild4,
    "05-wifi-startet.svg": bild5,
    "06-ssid-angezeigt.svg": bild6,
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, f in BILDER.items():
        (OUT / name).write_text(frame(f()), encoding="utf-8")
        print(OUT / name)
