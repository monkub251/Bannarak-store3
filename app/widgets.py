"""Custom-painted monochrome controls."""
from __future__ import annotations

import math
import time

from PySide6.QtCore import (QEasingCurve, QPointF, QRectF, Qt, QTimer, QVariantAnimation, Signal,
                            QObject)
from PySide6.QtGui import (QBrush, QColor, QLinearGradient, QPainter, QPainterPath, QPen,
                           QPolygonF)
from PySide6.QtWidgets import QWidget

from .theme import DIM, SILVER, SOFT, WHITE, font, gray


class Tween(QObject):
    changed = Signal()

    def __init__(self, parent, value=0.0, ms=200, curve=QEasingCurve.OutCubic):
        super().__init__(parent)
        self.value = float(value)
        self._a = QVariantAnimation(self)
        self._a.setDuration(ms)
        self._a.setEasingCurve(curve)
        self._a.valueChanged.connect(self._set)

    def to(self, v: float) -> None:
        self._a.stop()
        self._a.setStartValue(self.value)
        self._a.setEndValue(float(v))
        self._a.start()

    def _set(self, v) -> None:
        self.value = float(v)
        self.changed.emit()


def chamfer(r: QRectF, c: float, tl=True, tr=False, br=True, bl=False) -> QPolygonF:
    pts = []
    pts += [QPointF(r.left() + c, r.top()), QPointF(r.left(), r.top() + c)] if tl else [r.topLeft()]
    pts += [r.bottomLeft()] if not bl else [QPointF(r.left(), r.bottom() - c), QPointF(r.left() + c, r.bottom())]
    pts += [QPointF(r.right() - c, r.bottom()), QPointF(r.right(), r.bottom() - c)] if br else [r.bottomRight()]
    pts += [r.topRight()] if not tr else [QPointF(r.right(), r.top() + c), QPointF(r.right() - c, r.top())]
    return QPolygonF(pts)


# --------------------------------------------------------------------------- #
class ProfileRow(QWidget):
    clicked = Signal()

    def __init__(self, index: str, title: str, sub: str, parent=None):
        super().__init__(parent)
        self.index, self.title, self.sub = index, title, sub
        self.setFixedHeight(78)
        self.setCursor(Qt.PointingHandCursor)
        self.setMouseTracking(True)
        self.sel = Tween(self, 0, 260)
        self.hov = Tween(self, 0, 160)
        self.sel.changed.connect(self.update)
        self.hov.changed.connect(self.update)
        self.locked = False
        self.variant = "ultimate"
        self._want = False
        self._tm = QTimer(self)
        self._tm.setInterval(45)
        self._tm.timeout.connect(self._tick)

    def _tick(self):
        if not self._want and self.sel.value < 0.01:
            self._tm.stop()
        self.update()

    def set_selected(self, on: bool) -> None:
        self._want = on
        self.sel.to(1.0 if on else 0.0)
        if on and self.variant == "pulse":
            self._tm.start()

    def enterEvent(self, e):
        self.hov.to(1)

    def leaveEvent(self, e):
        self.hov.to(0)

    def mouseReleaseEvent(self, e):
        if e.button() == Qt.LeftButton and self.rect().contains(e.position().toPoint()) and not self.locked:
            self.clicked.emit()

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        s, h = self.sel.value, self.hov.value
        w, hh = self.width(), self.height()
        # selected: faint silver wash fading to the right
        g = QLinearGradient(0, 0, w, 0)
        g.setColorAt(0, gray(255, int(26 * s + 8 * h * (1 - s))))
        g.setColorAt(1, gray(255, 0))
        p.fillRect(self.rect(), g)
        # hairline
        p.setPen(QPen(gray(255, 30), 1))
        p.drawLine(0, hh - 1, w, hh - 1)
        # marker bar
        bh_ = hh * (0.30 + 0.62 * s)
        beat = ((time.perf_counter()) % 2.4) / 2.4
        if self.variant == "pulse" and s > 0.01:
            bh_ *= 0.80 + 0.20 * math.exp(-beat * 5.0)
        p.fillRect(QRectF(0, (hh - bh_) / 2, 2, bh_), gray(255, int(70 + 185 * s)))
        if self.variant == "pulse" and s > 0.01:            # scrolling heartbeat trace
            pts = [(0, 0), (.30, 0), (.36, -.22), (.42, 0), (.47, 0), (.52, -1.0), (.58, .9), (.64, 0),
                   (.72, 0), (.78, -.25), (.86, 0), (1, 0)]
            x0, wd, y0, amp, n = w - 190, 130.0, hh - 26.0, 11.0, 64
            path = QPainterPath()
            for i in range(n + 1):
                u = (i / n + 1.0 - (time.perf_counter() * 0.45) % 1.0) % 1.0
                for k in range(len(pts) - 1):
                    if pts[k][0] <= u <= pts[k + 1][0]:
                        t = (u - pts[k][0]) / max(pts[k + 1][0] - pts[k][0], 1e-6)
                        yv = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * t
                        break
                pt = QPointF(x0 + wd * i / n, y0 + yv * amp)
                path.moveTo(pt) if i == 0 else path.lineTo(pt)
            fade = QLinearGradient(x0, 0, x0 + wd, 0)
            fade.setColorAt(0, gray(255, 0))
            fade.setColorAt(0.25, gray(255, int(170 * s)))
            fade.setColorAt(1, gray(255, int(220 * s)))
            p.setPen(QPen(QBrush(fade), 1.4))
            p.drawPath(path)
        # title
        a = 0.40 + 0.60 * s + 0.15 * h * (1 - s)
        p.setPen(gray(244, int(255 * min(a, 1))))
        p.setFont(font("display", 21, spacing=1.2))
        p.drawText(QRectF(22, 12, w - 80, 32), Qt.AlignVCenter | Qt.AlignLeft, self.title)
        p.setPen(gray(170, int(255 * min(0.45 + 0.55 * s, 1))))
        p.setFont(font("mono", 10, spacing=2.0))
        p.drawText(QRectF(22, 46, w - 80, 18), Qt.AlignVCenter | Qt.AlignLeft, self.sub)
        p.setPen(gray(150, int(255 * (0.35 + 0.65 * s))))
        p.setFont(font("mono", 11, spacing=1.0))
        p.drawText(QRectF(w - 50, 12, 44, 32), Qt.AlignVCenter | Qt.AlignRight, self.index)


# --------------------------------------------------------------------------- #
class _Pressable(QWidget):
    clicked = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setCursor(Qt.PointingHandCursor)
        self.setMouseTracking(True)
        self.hov = Tween(self, 0, 180)
        self.prs = Tween(self, 0, 90)
        self.hov.changed.connect(self.update)
        self.prs.changed.connect(self.update)
        self.enabled_click = True

    def enterEvent(self, e):
        self.hov.to(1)

    def leaveEvent(self, e):
        self.hov.to(0)
        self.prs.to(0)

    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self.prs.to(1)

    def mouseReleaseEvent(self, e):
        self.prs.to(0)
        if e.button() == Qt.LeftButton and self.rect().contains(e.position().toPoint()) and self.enabled_click:
            self.clicked.emit()


class OptimizeButton(_Pressable):
    """Hero control: chamfered silver plate, light sweep, running stripes."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(76)
        self.state = "idle"                     # idle | running | done | failed
        self.label = "OPTIMIZE"
        self.sub = "ULTIMATE V2"
        self.variant = "ultimate"
        self.sweep = Tween(self, 0, 900, QEasingCurve.InOutSine)
        self.phase = 0.0
        self._t = QTimer(self)
        self._t.setInterval(40)
        self._t.timeout.connect(self._tick)
        self._idle = QTimer(self)
        self._idle.setInterval(7000)
        self._idle.timeout.connect(self._idle_sweep)
        self._idle.start()

    def set_state(self, st: str, label: str | None = None) -> None:
        self.state = st
        self.enabled_click = st != "running"
        self.setCursor(Qt.PointingHandCursor if self.enabled_click else Qt.BusyCursor)
        if label:
            self.label = label
        if st == "running":
            self._t.start()
        else:
            self._t.stop()
        self.update()

    def _tick(self):
        self.phase = (self.phase + 0.035) % 1.0
        self.update()

    def _idle_sweep(self):
        if self.state in ("idle", "done"):
            self._play_sweep()

    def _play_sweep(self):
        self.sweep._a.stop()
        self.sweep.value = 0.0
        self.sweep.to(1.0)

    def enterEvent(self, e):
        super().enterEvent(e)
        if self.state != "running":
            self._play_sweep()

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(1.5, 1.5, self.width() - 3, self.height() - 3)
        pulse = self.variant == "pulse"
        poly = chamfer(r, 18, tl=False, tr=True, br=False, bl=True) if pulse else chamfer(r, 18, tl=True, tr=False, br=True, bl=False)
        path = QPainterPath()
        path.addPolygon(poly)
        path.closeSubpath()
        hv, pr = self.hov.value, self.prs.value
        st = self.state
        if pr:
            p.translate(0, 1.2 * pr)
        solid = st in ("idle", "done")
        if solid:
            g = QLinearGradient(0, r.top(), 0, r.bottom())
            top = 238 + int(17 * hv) - int(30 * pr)
            g.setColorAt(0, gray(min(top, 255)))
            g.setColorAt(0.55, gray(max(206 + int(24 * hv) - int(30 * pr), 0)))
            g.setColorAt(1, gray(max(168 + int(26 * hv) - int(30 * pr), 0)))
            p.fillPath(path, g)
            # silver outer contour
            p.setPen(QPen(gray(255, 150), 1))
            p.drawPath(path)
            if pulse:                                   # second contour: PULSE signature
                inner = QPainterPath()
                inner.addPolygon(chamfer(r.adjusted(5, 5, -5, -5), 13, tl=False, tr=True, br=False, bl=True))
                inner.closeSubpath()
                p.setPen(QPen(gray(0, 85), 1))
                p.drawPath(inner)
            # sweep
            if 0 < self.sweep.value < 1:
                p.save()
                p.setClipPath(path)
                x = r.left() - 120 + (r.width() + 240) * self.sweep.value
                sg = QLinearGradient(x - 70, 0, x + 70, 0)
                sg.setColorAt(0, gray(255, 0))
                sg.setColorAt(0.5, gray(255, 170))
                sg.setColorAt(1, gray(255, 0))
                p.setTransform(p.transform().shear(-0.5, 0))
                p.fillRect(QRectF(x - 70, r.top() - 4, 140, r.height() + 8), sg)
                p.restore()
            fg = gray(8)
            fg2 = gray(40)
        else:
            p.fillPath(path, gray(6))
            if st == "running":
                p.save()
                p.setClipPath(path)
                p.setPen(QPen(gray(255, 26), 10))
                off = self.phase * 40
                x = r.left() - r.height() - 40 + off
                while x < r.right() + 40:
                    p.drawLine(QPointF(x, r.bottom() + 4), QPointF(x + r.height(), r.top() - 4))
                    x += 40
                p.restore()
            pen = QPen(gray(255, 210 if st == "running" else 150), 1.2)
            if st == "failed":
                pen.setStyle(Qt.DashLine)
            p.setPen(pen)
            p.drawPath(path)
            fg = gray(246)
            fg2 = gray(170)
        # bolt / state icon
        cx, cy = r.left() + 44, r.center().y()
        p.setPen(Qt.NoPen)
        p.setBrush(fg)
        if st == "done":
            pen = QPen(fg, 3, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin)
            p.setPen(pen)
            p.setBrush(Qt.NoBrush)
            p.drawPolyline(QPolygonF([QPointF(cx - 11, cy + 1), QPointF(cx - 3, cy + 9), QPointF(cx + 12, cy - 9)]))
        elif st == "failed":
            p.setPen(QPen(fg, 3, Qt.SolidLine, Qt.RoundCap))
            p.drawLine(QPointF(cx - 9, cy - 9), QPointF(cx + 9, cy + 9))
            p.drawLine(QPointF(cx + 9, cy - 9), QPointF(cx - 9, cy + 9))
        elif pulse:
            p.setPen(QPen(fg, 3, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
            p.setBrush(Qt.NoBrush)
            p.drawPolyline(QPolygonF([QPointF(cx - 16, cy), QPointF(cx - 8, cy), QPointF(cx - 4, cy - 12),
                                      QPointF(cx + 2, cy + 13), QPointF(cx + 7, cy - 6), QPointF(cx + 10, cy),
                                      QPointF(cx + 16, cy)]))
        else:
            bolt = QPolygonF([QPointF(cx + 3, cy - 17), QPointF(cx - 11, cy + 3), QPointF(cx - 1, cy + 3),
                              QPointF(cx - 5, cy + 17), QPointF(cx + 11, cy - 5), QPointF(cx + 1, cy - 5)])
            p.drawPolygon(bolt)
        # labels
        tx = r.left() + 78
        p.setPen(fg)
        p.setFont(font("uib", 26, spacing=5.0))
        p.drawText(QRectF(tx, r.top() + 10, r.width() - tx - 16, 34), Qt.AlignVCenter | Qt.AlignLeft, self.label)
        p.setPen(fg2)
        p.setFont(font("mono", 10, spacing=2.6))
        p.drawText(QRectF(tx, r.top() + 44, r.width() - tx - 16, 18), Qt.AlignVCenter | Qt.AlignLeft, self.sub)


class ResetButton(_Pressable):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(54)
        self.busy = False
        self.phase = 0.0
        self._t = QTimer(self)
        self._t.setInterval(40)
        self._t.timeout.connect(self._tick)

    def set_busy(self, on: bool) -> None:
        self.busy = on
        self.enabled_click = not on
        if on:
            self._t.start()
        else:
            self._t.stop()
            self.phase = 0
        self.update()

    def _tick(self):
        self.phase = (self.phase + 0.05) % 1.0
        self.update()

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(1.5, 1.5, self.width() - 3, self.height() - 3)
        poly = chamfer(r, 12, tl=False, tr=True, br=False, bl=True)
        path = QPainterPath()
        path.addPolygon(poly)
        path.closeSubpath()
        hv, pr = self.hov.value, self.prs.value
        p.fillPath(path, gray(255, int(8 + 20 * hv + 18 * pr)))
        p.setPen(QPen(gray(255, int(90 + 120 * hv)), 1))
        p.drawPath(path)
        col = gray(int(190 + 60 * hv))
        # circular arrow
        cx, cy, rad = r.left() + 34, r.center().y(), 9.0
        p.setPen(QPen(col, 2, Qt.SolidLine, Qt.RoundCap))
        rect = QRectF(cx - rad, cy - rad, 2 * rad, 2 * rad)
        start = int((60 - 360 * self.phase) * 16)
        p.drawArc(rect, start, 280 * 16)
        e_deg = 60 - 360 * self.phase + 280
        ea = math.radians(e_deg)
        P = QPointF(cx + rad * math.cos(ea), cy - rad * math.sin(ea))
        t = QPointF(-math.sin(ea), -math.cos(ea))
        n = QPointF(math.cos(ea), -math.sin(ea))
        p.setBrush(col)
        p.setPen(Qt.NoPen)
        p.drawPolygon(QPolygonF([P + t * 6.5, P - n * 5.0, P + n * 5.0]))
        p.setPen(col)
        p.setFont(font("uib", 17, spacing=3.4))
        p.drawText(QRectF(r.left() + 58, r.top() + 5, r.width() - 70, 24), Qt.AlignVCenter | Qt.AlignLeft,
                   "RESETTING" if self.busy else "GLOBAL RESET")
        p.setPen(gray(140))
        p.setFont(font("body", 12))
        p.drawText(QRectF(r.left() + 58, r.top() + 28, r.width() - 70, 20), Qt.AlignVCenter | Qt.AlignLeft,
                   "คืนค่าที่แอปปรับไว้เป็นค่าเดิม")


class NavLink(_Pressable):
    def __init__(self, text: str, parent=None, width: int = 76):
        super().__init__(parent)
        self.text = text
        self.on = Tween(self, 0, 220)
        self.on.changed.connect(self.update)
        self.setFixedSize(width, 34)

    def set_active(self, v: bool) -> None:
        self.on.to(1.0 if v else 0.0)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        a, h = self.on.value, self.hov.value
        p.setPen(gray(int(120 + 124 * max(a, h * 0.8))))
        p.setFont(font("uib", 14, spacing=3.0))
        p.drawText(self.rect().adjusted(0, -2, 0, -2), Qt.AlignCenter, self.text)
        w = (self.width() - 24) * a
        p.fillRect(QRectF((self.width() - w) / 2, self.height() - 5, w, 1.5), gray(240))


class WinButton(_Pressable):
    def __init__(self, kind: str, parent=None):
        super().__init__(parent)
        self.kind = kind
        self.setFixedSize(40, 34)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        h = self.hov.value
        if h:
            p.fillRect(self.rect(), gray(255, int(22 * h)))
        p.setPen(QPen(gray(int(150 + 100 * h)), 1.3))
        c = QPointF(self.width() / 2, self.height() / 2)
        if self.kind == "min":
            p.drawLine(c + QPointF(-6, 3), c + QPointF(6, 3))
        elif self.kind == "max":
            p.drawRect(QRectF(c.x() - 5.5, c.y() - 5, 11, 10))
        else:
            p.drawLine(c + QPointF(-5.5, -5.5), c + QPointF(5.5, 5.5))
            p.drawLine(c + QPointF(5.5, -5.5), c + QPointF(-5.5, 5.5))


class TextButton(_Pressable):
    """Small underlined text control used in dialogs / settings."""

    def __init__(self, text: str, primary=False, parent=None):
        super().__init__(parent)
        self.text, self.primary = text, primary
        self.setFixedHeight(42)
        self.setMinimumWidth(130)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(1, 1, self.width() - 2, self.height() - 2)
        path = QPainterPath()
        path.addPolygon(chamfer(r, 9, tl=True, tr=False, br=True, bl=False))
        path.closeSubpath()
        hv = self.hov.value
        if self.primary:
            p.fillPath(path, gray(int(226 + 29 * hv)))
            p.setPen(gray(8))
        else:
            p.fillPath(path, gray(255, int(6 + 16 * hv)))
            p.setPen(QPen(gray(255, int(80 + 110 * hv)), 1))
            p.drawPath(path)
            p.setPen(gray(220))
        p.setFont(font("uib", 15, spacing=3.0))
        p.drawText(self.rect(), Qt.AlignCenter, self.text)
