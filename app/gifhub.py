"""GIF HUB: grayscale GIF browser (hover = play, click = theater)."""
from __future__ import annotations

import glob
import os
import shutil

from PySide6.QtCore import QRectF, QSize, Qt, QTimer, QUrl, Signal
from PySide6.QtGui import QColor, QDesktopServices, QImage, QMovie, QPainter, QPen
from PySide6.QtWidgets import QFileDialog, QScrollArea, QVBoxLayout, QWidget

from .theme import font, gray, resource_path
from .widgets import TextButton, Tween, _Pressable


def user_gif_dir() -> str:
    base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), ".local", "share")
    d = os.path.join(base, "BannarakxFiveM", "gifs")
    os.makedirs(d, exist_ok=True)
    return d


def all_gifs() -> list[str]:
    seen, out = set(), []
    for d in (resource_path("gifs"), user_gif_dir()):
        for f in sorted(glob.glob(os.path.join(d, "*.gif"))):
            if os.path.basename(f).lower() not in seen:
                seen.add(os.path.basename(f).lower())
                out.append(f)
    return out


class GifView(QWidget):
    """Plays one GIF in grayscale (colour is removed so the palette stays monochrome)."""

    def __init__(self, parent=None, autoplay=False):
        super().__init__(parent)
        self.movie: QMovie | None = None
        self.img: QImage | None = None
        self.frames = 0
        self.path = ""
        self.autoplay = autoplay

    def load(self, path: str) -> None:
        if self.movie:
            self.movie.stop()
            self.movie.deleteLater()
        self.path = path
        self.movie = QMovie(path)
        self.movie.setCacheMode(QMovie.CacheAll if os.path.getsize(path) < 12e6 else QMovie.CacheNone)
        self.movie.frameChanged.connect(self._frame)
        self.movie.jumpToFrame(0)
        self.frames = self.movie.frameCount()
        self._frame()
        if self.autoplay:
            self.movie.start()

    def _frame(self, *_):
        if self.movie:
            im = self.movie.currentImage()
            if not im.isNull():
                self.img = im.convertToFormat(QImage.Format_Grayscale8)
                self.update()

    def play(self, on: bool) -> None:
        if not self.movie:
            return
        if on:
            self.movie.start()
        else:
            self.movie.stop()
            self.movie.jumpToFrame(0)

    def paintEvent(self, e):
        p = QPainter(self)
        p.fillRect(self.rect(), gray(4))
        if self.img is None:
            return
        p.setRenderHint(QPainter.SmoothPixmapTransform)
        r = QRectF(self.rect())
        s = max(r.width() / self.img.width(), r.height() / self.img.height())     # cover
        w, h = self.img.width() * s, self.img.height() * s
        p.drawImage(QRectF(r.center().x() - w / 2, r.center().y() - h / 2, w, h), self.img)


class Tile(_Pressable):
    opened = Signal(str)

    def __init__(self, path: str, parent=None):
        super().__init__(parent)
        self.path = path
        self.view = GifView(self)
        self.view.setAttribute(Qt.WA_TransparentForMouseEvents)
        self.view.load(path)
        self.clicked.connect(lambda: self.opened.emit(self.path))
        self.setMinimumHeight(190)

    def resizeEvent(self, e):
        self.view.setGeometry(1, 1, self.width() - 2, self.height() - 2 - 38)

    def enterEvent(self, e):
        super().enterEvent(e)
        self.view.play(True)

    def leaveEvent(self, e):
        super().leaveEvent(e)
        self.view.play(False)

    def paintEvent(self, e):
        p = QPainter(self)
        h = self.hov.value
        p.setPen(QPen(gray(255, int(40 + 150 * h)), 1))
        p.setBrush(Qt.NoBrush)
        p.drawRect(0, 0, self.width() - 1, self.height() - 1)
        y = self.height() - 38
        p.fillRect(1, y, self.width() - 2, 37, gray(255, int(6 + 10 * h)))
        name = os.path.splitext(os.path.basename(self.path))[0].replace("_", " ")
        p.setPen(gray(int(190 + 60 * h)))
        p.setFont(font("uib", 14, spacing=2.4))
        p.drawText(QRectF(14, y, self.width() - 100, 37), Qt.AlignVCenter | Qt.AlignLeft, name.upper())
        p.setPen(gray(120))
        p.setFont(font("mono", 9, spacing=1.5))
        p.drawText(QRectF(self.width() - 90, y, 76, 37), Qt.AlignVCenter | Qt.AlignRight,
                   f"{self.view.frames} FR")
        if h < 0.5:                                  # play glyph
            p.setPen(Qt.NoPen)
            p.setBrush(gray(245, int(200 * (1 - h * 2))))
            cx, cy = self.width() / 2, (self.height() - 38) / 2
            from PySide6.QtGui import QPolygonF
            from PySide6.QtCore import QPointF
            p.drawPolygon(QPolygonF([QPointF(cx - 7, cy - 10), QPointF(cx - 7, cy + 10), QPointF(cx + 12, cy)]))


class Theater(QWidget):
    closed = Signal()

    def __init__(self, parent):
        super().__init__(parent)
        self.view = GifView(self, autoplay=True)
        self.hide()
        self.name = ""

    def open(self, path: str):
        self.name = os.path.splitext(os.path.basename(path))[0].replace("_", " ").upper()
        self.view.load(path)
        self.setGeometry(self.parentWidget().rect())
        self.raise_()
        self.show()
        self.setFocus()

    def resizeEvent(self, e):
        w, h = self.width(), self.height()
        vw = min(w - 160, (h - 190) * 16 / 9)
        vh = vw * 9 / 16
        self.view.setGeometry(int((w - vw) / 2), int((h - vh) / 2) + 10, int(vw), int(vh))

    def paintEvent(self, e):
        p = QPainter(self)
        p.fillRect(self.rect(), gray(0, 232))
        g = self.view.geometry()
        p.setPen(QPen(gray(255, 90), 1))
        p.drawRect(g.adjusted(-1, -1, 0, 0))
        p.setPen(gray(244))
        p.setFont(font("display", 16, spacing=2))
        p.drawText(QRectF(g.left(), g.top() - 52, g.width(), 34), Qt.AlignVCenter | Qt.AlignLeft, self.name)
        p.setPen(gray(110))
        p.setFont(font("mono", 10, spacing=2.4))
        p.drawText(QRectF(g.left(), g.bottom() + 12, g.width(), 20), Qt.AlignVCenter | Qt.AlignRight,
                   "CLICK OR ESC TO CLOSE")

    def _close(self):
        self.view.play(False)
        self.hide()
        self.closed.emit()

    def mousePressEvent(self, e):
        self._close()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self._close()


class GifHub(QWidget):
    def __init__(self, parent):
        super().__init__(parent)
        self.setStyleSheet("background:transparent;")
        self.add = TextButton("ADD GIF", self)
        self.folder = TextButton("OPEN FOLDER", self)
        self.add.show()
        self.folder.show()
        self.add.clicked.connect(self._add)
        self.folder.clicked.connect(lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(user_gif_dir())))
        self.scroll = QScrollArea(self)
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QScrollArea.NoFrame)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.scroll.setStyleSheet(
            "QScrollArea{background:transparent;}QScrollArea>QWidget>QWidget{background:transparent;}"
            "QScrollBar:vertical{background:transparent;width:8px;margin:0;}"
            "QScrollBar::handle:vertical{background:#555;min-height:24px;}"
            "QScrollBar::add-line,QScrollBar::sub-line{height:0;}")
        self.holder = QWidget()
        self.scroll.setWidget(self.holder)
        self.tiles: list[Tile] = []
        self.theater = Theater(self)
        self.theater.closed.connect(self.refresh_playing)
        self.count = 0
        self.refresh()

    def refresh(self):
        for t in self.tiles:
            t.deleteLater()
        self.tiles = []
        paths = all_gifs()
        self.count = len(paths)
        for pth in paths:
            t = Tile(pth, self.holder)
            t.opened.connect(self.theater.open)
            t.show()
            self.tiles.append(t)
        self._layout()
        self.update()

    def refresh_playing(self):
        pass

    def _add(self):
        files, _ = QFileDialog.getOpenFileNames(self, "Add GIF", "", "GIF (*.gif)")
        for f in files:
            try:
                shutil.copy2(f, os.path.join(user_gif_dir(), os.path.basename(f)))
            except OSError:
                pass
        if files:
            self.refresh()

    def _layout(self):
        W = self.width()
        left = 60
        avail = max(W - left * 2, 300)
        cols = 4 if avail > 1500 else 3 if avail > 900 else 2
        gap = 18
        tw = (avail - gap * (cols - 1)) // cols
        th = int(tw * 9 / 16) + 38
        rows = (len(self.tiles) + cols - 1) // cols
        for i, t in enumerate(self.tiles):
            t.setGeometry(i % cols * (tw + gap), i // cols * (th + gap), tw, th)
        self.holder.setFixedSize(avail, max(rows * (th + gap), 10))
        self.scroll.setGeometry(left, 112, avail + 12, self.height() - 112 - 8)

    def resizeEvent(self, e):
        self.add.move(self.width() - 60 - 130 - 12 - 160, 48)
        self.folder.setMinimumWidth(160)
        self.folder.resize(160, 42)
        self.folder.move(self.width() - 60 - 160, 48)
        self.add.resize(130, 42)
        self._layout()
        self.theater.setGeometry(self.rect())

    def paintEvent(self, e):
        p = QPainter(self)
        p.setPen(gray(246))
        p.setFont(font("display", 22, spacing=2.4))
        p.drawText(QRectF(60, 36, 500, 40), Qt.AlignVCenter | Qt.AlignLeft, "GIF HUB")
        p.setPen(gray(125))
        p.setFont(font("mono", 10, spacing=2.6))
        p.drawText(QRectF(62, 76, 600, 20), Qt.AlignVCenter | Qt.AlignLeft,
                   f"{self.count} CLIPS · HOVER TO PLAY · CLICK TO ENLARGE · GRAYSCALE")
        p.setPen(QPen(gray(255, 30), 1))
        p.drawLine(60, 104, self.width() - 60, 104)
