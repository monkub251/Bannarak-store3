"""Monochrome palette, bundled fonts and small helpers."""
from __future__ import annotations

import os
import sys

from PySide6.QtGui import QColor, QFont, QFontDatabase


def resource_path(*parts: str) -> str:
    # Works for: plain `python main.py`, PyInstaller (_MEIPASS) and Nuitka (onefile / standalone).
    base = getattr(sys, "_MEIPASS", None)
    if not base:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if not os.path.isdir(os.path.join(base, "assets")):  # fallback: next to the exe
            base = os.path.dirname(os.path.abspath(sys.argv[0]))
    return os.path.join(base, *parts)


# Strict black / white / silver / grayscale.  No colour anywhere.
def gray(v: int, a: int = 255) -> QColor:
    return QColor(v, v, v, a)


WHITE = gray(244)
SILVER = gray(186)
SOFT = gray(140)
DIM = gray(92)
LINE = gray(255, 38)
BLACK = gray(0)

_FILES = {
    "display": "Michroma-Regular.ttf",
    "ui": "Rajdhani-SemiBold.ttf",
    "uib": "Rajdhani-Bold.ttf",
    "body": "Sarabun-Regular.ttf",
    "bodym": "Sarabun-Medium.ttf",
    "bodyb": "Sarabun-SemiBold.ttf",
    "mono": "JetBrainsMono.ttf",
}
_FALLBACK = {
    "display": ["Segoe UI", "Arial"],
    "ui": ["Segoe UI Semibold", "Segoe UI", "Arial"],
    "body": ["Leelawadee UI", "Tahoma", "Segoe UI", "Arial"],
    "mono": ["Consolas", "Courier New"],
}
_families: dict[str, str] = {}


def load_fonts() -> None:
    for key, fn in _FILES.items():
        fid = QFontDatabase.addApplicationFont(resource_path("assets", "fonts", fn))
        fams = QFontDatabase.applicationFontFamilies(fid) if fid >= 0 else []
        if fams:
            _families[key] = fams[0]


def font(kind: str, px: float, weight: QFont.Weight | None = None, spacing: float = 0.0) -> QFont:
    base = {"uib": "ui", "bodym": "body", "bodyb": "body"}.get(kind, kind)
    fam = _families.get(kind) or _families.get(base)
    f = QFont()
    f.setFamilies(([fam] if fam else []) + _FALLBACK.get(base, ["Arial"]))
    f.setPixelSize(int(round(px)))
    if weight is None:
        weight = {"uib": QFont.Bold, "ui": QFont.DemiBold, "bodym": QFont.Medium,
                  "bodyb": QFont.DemiBold}.get(kind, QFont.Normal)
    f.setWeight(weight)
    if spacing:
        f.setLetterSpacing(QFont.AbsoluteSpacing, spacing)
    # grey-scale anti-aliasing only: LCD sub-pixel fringes would add colour
    f.setStyleStrategy(QFont.PreferAntialias | QFont.NoSubpixelAntialias)
    return f
