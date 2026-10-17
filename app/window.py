"""Main window: one large real-time black hole + a quiet control column."""
from __future__ import annotations

import math
import time

from PySide6.QtCore import QEvent, QRectF, QPointF, Qt, QTimer
from PySide6.QtGui import (QColor, QCursor, QFontMetrics, QLinearGradient, QPainter, QPen, QPixmap)
from PySide6.QtWidgets import (QDialog, QGraphicsOpacityEffect, QHBoxLayout, QLabel, QPlainTextEdit,
                               QSizeGrip, QStackedWidget, QVBoxLayout, QWidget)

from .backend import Backend
from .gifhub import GifHub
from .theme import font, gray, resource_path
from .view import BHWorker
from .widgets import (NavLink, OptimizeButton, ProfileRow, ResetButton, TextButton, Tween,
                      WinButton)

HEADER_H = 64
FOOT_H = 40

PROFILES = {
    "ULTIMATE": {
        "title": "ULTIMATE V2", "sub": "FULL SYSTEM TUNING", "index": "01",
        "desc": "ปรับแต่งครบทั้งระบบ ทั้งเครือข่าย นโยบายระบบ โหมดเกมและพลังงาน อินพุต และบริการเบื้องหลัง "
                "สำรองค่าเดิมไว้ก่อนทุกครั้ง",
        "features": ["DNS + Network registry", "Group Policy (GPEDIT)",
                     "Game Mode · High Performance · NVIDIA registry",
                     "Mouse / keyboard · Services · Disk Cleanup C:"],
        "speed": 1.0, "intensity": 1.0,
    },
    "PULSE": {
        "title": "PULSE V2", "sub": "MAX · FULL SYSTEM", "index": "02",
        "desc": "โหมดเต็มระบบที่แรงกว่า ULTIMATE: ทุกอย่างของ ULTIMATE แล้วบีบระบบเพิ่มอีกชั้น "
                "ปิดงานเบื้องหลัง ลดโปรเซส และจูนอินพุตกับเครือข่ายสำหรับ FiveM สุดขั้ว "
                "ย้อนกลับได้ด้วย GLOBAL RESET",
        "features": ["ทุกอย่างของ ULTIMATE + หยุด Windows Update · Printing · RDP · File sharing",
                     "Input + system latency (Game DVR off · MMCSS Games)",
                     "QoS DSCP 46 สำหรับ FiveM / GTA (UDP)",
                     "Process reduce (svchost รวม · ปิด WER · Search เว็บ · แอปเบื้องหลัง)"],
        "warn": "HIGH IMPACT",
        "confirm": "PULSE V2 แรงกว่า ULTIMATE และมีผลข้างเคียงชัดเจน: หยุด Windows Update, การพิมพ์, Remote Desktop "
                   "และการแชร์ไฟล์, ปิดรายงานข้อผิดพลาดของ Windows, ปิดค้นหาเว็บ/แอปเบื้องหลัง "
                   "ส่วน Windows Defender และระบบความปลอดภัยหลักไม่ถูกปิด ย้อนกลับได้ด้วย GLOBAL RESET "
                   "(ใช้ backup ร่วมกับ ULTIMATE) เมื่อเสร็จให้รีสตาร์ทเครื่อง ต้องการดำเนินการต่อหรือไม่?",
        "speed": 1.55, "intensity": 1.10,
    },
}
ORDER = ["ULTIMATE", "PULSE"]


# --------------------------------------------------------------------------- #
class Confirm(QDialog):
    def __init__(self, parent, title: str, text: str, ok: str):
        super().__init__(parent, Qt.Dialog | Qt.FramelessWindowHint)
        self.setModal(True)
        self.setFixedWidth(470)
        self.setStyleSheet("background:#050505;")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(32, 28, 32, 26)
        lay.setSpacing(14)
        t = QLabel(title)
        t.setFont(font("display", 15, spacing=1.5))
        t.setStyleSheet("color:#f4f4f4;background:transparent;")
        b = QLabel(text)
        b.setWordWrap(True)
        b.setFont(font("body", 14))
        b.setStyleSheet("color:#b5b5b5;background:transparent;")
        lay.addWidget(t)
        lay.addWidget(b)
        lay.addSpacing(8)
        row = QHBoxLayout()
        row.setSpacing(12)
        c = TextButton("CANCEL")
        o = TextButton(ok, primary=True)
        c.clicked.connect(self.reject)
        o.clicked.connect(self.accept)
        row.addStretch(1)
        row.addWidget(c)
        row.addWidget(o)
        lay.addLayout(row)

    def paintEvent(self, e):
        p = QPainter(self)
        p.fillRect(self.rect(), gray(5))
        p.setPen(QPen(gray(255, 70), 1))
        p.drawRect(self.rect().adjusted(0, 0, -1, -1))
        p.fillRect(QRectF(0, 0, 54, 2), gray(244))

    def showEvent(self, e):
        pw = self.parentWidget()
        if pw:
            g = pw.geometry()
            self.move(pw.mapToGlobal(QPointF(0, 0).toPoint()).x() + (g.width() - self.width()) // 2,
                      pw.mapToGlobal(QPointF(0, 0).toPoint()).y() + (g.height() - self.height()) // 2)


# --------------------------------------------------------------------------- #
class Header(QWidget):
    def __init__(self, win: "MainWindow"):
        super().__init__(win)
        self.win = win
        self.setFixedHeight(HEADER_H)
        self.logo = QPixmap(resource_path("assets", "logo_mark.png"))
        self.nav = {k: NavLink(k, self, w) for k, w in (("HOME", 76), ("GIF HUB", 100), ("LOG", 70), ("ABOUT", 84))}
        for k, w in self.nav.items():
            w.clicked.connect(lambda k=k: win.show_page(k))
        self.btn_min = WinButton("min", self)
        self.btn_max = WinButton("max", self)
        self.btn_close = WinButton("close", self)
        self.btn_min.clicked.connect(win.showMinimized)
        self.btn_max.clicked.connect(win.toggle_max)
        self.btn_close.clicked.connect(win.close)

    def resizeEvent(self, e):
        w = self.width()
        x = w - 18 - 40
        for b in (self.btn_close, self.btn_max, self.btn_min):
            b.move(x, 15)
            x -= 40
        x -= 18
        for k in ("ABOUT", "LOG", "GIF HUB", "HOME"):
            nw = self.nav[k].width()
            self.nav[k].move(x - nw, 15)
            x -= nw + 6

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.SmoothPixmapTransform)
        h = 44
        if not self.logo.isNull():
            lw = int(self.logo.width() * h / self.logo.height())
            p.drawPixmap(QRectF(30, 10, lw, h).toRect(), self.logo)
        else:
            lw = 38
        x = 30 + lw + 16
        p.setPen(gray(246))
        p.setFont(font("display", 13, spacing=3.2))
        p.drawText(QRectF(x, 13, 320, 20), Qt.AlignVCenter | Qt.AlignLeft, "BANNARAKX")
        p.setPen(gray(130))
        p.setFont(font("mono", 9, spacing=3.0))
        p.drawText(QRectF(x, 34, 320, 16), Qt.AlignVCenter | Qt.AlignLeft, "FIVE M · FPS OPTIMIZER")

    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton and self.win.windowHandle():
            self.win.windowHandle().startSystemMove()

    def mouseDoubleClickEvent(self, e):
        self.win.toggle_max()


# --------------------------------------------------------------------------- #
class MainWindow(QWidget):
    def __init__(self, quality: str = "full"):
        super().__init__()
        self.setWindowTitle("BANNARAKX · FIVE M FPS OPTIMIZER")
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)
        self.resize(1280, 780)
        self.setMinimumSize(1060, 700)
        self.setMouseTracking(True)
        self.setAttribute(Qt.WA_OpaquePaintEvent, True)

        self.profile = "ULTIMATE"
        self.status = "READY"
        self.running = False
        self._img = None
        self._bloom = None
        self.quality = quality
        self.bh_failed = False
        self.bh_alpha = Tween(self, 0, 1400, curve=__import__("PySide6.QtCore", fromlist=["QEasingCurve"]).QEasingCurve.InOutSine)
        self.bh_alpha.changed.connect(self.update)
        self.act = Tween(self, 0, 900)
        self.spd = Tween(self, 1.0, 700)
        self.inten = Tween(self, 1.0, 700)
        for t in (self.act, self.spd, self.inten):
            t.changed.connect(self._push_motion)
        self._pulse = 0.0
        self._pt = QTimer(self)
        self._pt.setInterval(60)
        self._pt.timeout.connect(self._pulse_tick)

        self.backend = Backend(self)
        self.backend.line.connect(self._on_line)
        self.backend.finished.connect(self._on_finished)

        # ---------------------------------------------------------------- UI
        self.header = Header(self)
        self.stack = QStackedWidget(self)
        self.stack.setStyleSheet("background:transparent;")
        self.stack.addWidget(self._build_home())
        self.stack.addWidget(self._build_log())
        self.stack.addWidget(self._build_about())
        self.gifhub = GifHub(self)
        self.gifhub.hide()
        self.dim = Tween(self, 1.0, 500)
        self.dim.changed.connect(self.update)
        self._par = QPointF(0, 0)
        self._t0 = time.perf_counter()
        self.grip = QSizeGrip(self)
        self.grip.setFixedSize(16, 16)
        self.header.nav["HOME"].set_active(True)
        self._select(self.profile, instant=True)
        self._start_worker()

    # ------------------------------------------------------------------ pages
    def _label(self, text="", size=14, kind="body", color="#a9a9a9", spacing=0.0, wrap=False):
        l = QLabel(text)
        l.setFont(font(kind, size, spacing=spacing))
        l.setStyleSheet(f"color:{color};background:transparent;")
        l.setWordWrap(wrap)
        l.setTextFormat(Qt.RichText)
        return l

    def _build_home(self) -> QWidget:
        pg = QWidget()
        v = QVBoxLayout(pg)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(0)
        v.addStretch(1)
        v.addWidget(self._label("SELECT PROFILE", 10, "mono", "#7c7c7c", 3.2))
        v.addSpacing(10)
        self.rows = {}
        for k in ORDER:
            d = PROFILES[k]
            r = ProfileRow(d["index"], d["title"], d["sub"])
            r.clicked.connect(lambda k=k: self._select(k))
            r.variant = k.lower()
            self.rows[k] = r
            v.addWidget(r)
        v.addSpacing(20)
        self.info = QWidget()
        self.info.setStyleSheet("background:transparent;")
        iv = QVBoxLayout(self.info)
        iv.setContentsMargins(0, 0, 0, 0)
        iv.setSpacing(12)
        self.desc = self._label("", 14, "body", "#b3b3b3", wrap=True)
        self.feat = self._label("", 13, "body", "#8a8a8a", wrap=True)
        iv.addWidget(self.desc)
        iv.addWidget(self.feat)
        self.fx = QGraphicsOpacityEffect(self.info)
        self.info.setGraphicsEffect(self.fx)
        self.fade = Tween(self, 1.0, 140)
        self.fade.changed.connect(lambda: self.fx.setOpacity(self.fade.value))
        v.addWidget(self.info)
        v.addSpacing(26)
        self.opt = OptimizeButton()
        self.opt.clicked.connect(self._ask_optimize)
        v.addWidget(self.opt)
        v.addSpacing(12)
        self.rst = ResetButton()
        self.rst.clicked.connect(self._ask_reset)
        v.addWidget(self.rst)
        v.addStretch(1)
        return pg

    def _build_log(self) -> QWidget:
        pg = QWidget()
        v = QVBoxLayout(pg)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(10)
        v.addWidget(self._label("LOG", 10, "mono", "#7c7c7c", 3.2))
        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(3000)
        self.log.setFont(font("mono", 11))
        self.log.setPlaceholderText("— no output yet —")
        self.log.setStyleSheet(
            "QPlainTextEdit{background:rgba(255,255,255,10);color:#bdbdbd;border:1px solid rgba(255,255,255,40);"
            "padding:10px;selection-background-color:#dcdcdc;selection-color:#000;}"
            "QScrollBar:vertical{background:transparent;width:8px;margin:0;}"
            "QScrollBar::handle:vertical{background:#555;min-height:24px;}"
            "QScrollBar::add-line,QScrollBar::sub-line{height:0;}")
        v.addWidget(self.log, 1)
        v.addWidget(self._label("ไฟล์ backup / log ของสคริปต์เดิม: C:\\ProgramData\\BannarakxNetForge",
                                12, "body", "#6f6f6f", wrap=True))
        return pg

    def _build_about(self) -> QWidget:
        pg = QWidget()
        v = QVBoxLayout(pg)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(10)
        v.addWidget(self._label("ABOUT", 10, "mono", "#7c7c7c", 3.2))
        html = (
            "<p style='line-height:150%'>"
            "<b style='color:#e8e8e8'>ULTIMATE V2</b> → <span style='color:#cfcfcf'>BANNARAKX_ULTIMATE.ps1</span><br>"
            "<b style='color:#e8e8e8'>PULSE V2</b> → <span style='color:#cfcfcf'>ULTIMATE.ps1 -Plus</span> + reg 04 · 05 · 06 (EXTREME) — แรงกว่า ULTIMATE และมีผลข้างเคียง ไม่รวม 07 (ปิดระบบความปลอดภัย) ใช้ backup ร่วมกับ ULTIMATE</p>"
            "<p style='line-height:150%'>ปุ่มทั้งสองเรียกสคริปต์เดิมโดยไม่แก้ไข ต้องใช้สิทธิ์ผู้ดูแลระบบ (UAC) "
            "และไม่รีสตาร์ทเครื่องให้อัตโนมัติ — เมื่อเสร็จให้รีสตาร์ทเอง "
            "GLOBAL RESET ใช้เมนู Restore ของสคริปต์เดิม คืนเฉพาะค่าที่สคริปต์เคยปรับ</p>"
            "<p style='line-height:150%'>ผลลัพธ์จริงขึ้นกับแต่ละเครื่องและเครือข่าย แอปไม่รับประกัน FPS หรือค่าหน่วง</p>")
        a = self._label(html, 13, "body", "#9b9b9b", wrap=True)
        v.addWidget(a)
        v.addSpacing(8)
        v.addWidget(self._label("BLACK HOLE ANIMATION", 10, "mono", "#7c7c7c", 3.2))
        row = QHBoxLayout()
        row.setSpacing(0)
        self.qlinks = {}
        for k, name in (("full", "FULL"), ("lite", "LITE"), ("still", "STILL")):
            n = NavLink(name)
            n.clicked.connect(lambda k=k: self._set_quality(k))
            n.set_active(k == self.quality)
            self.qlinks[k] = n
            row.addWidget(n)
        row.addStretch(1)
        v.addLayout(row)
        v.addWidget(self._label("LITE ใช้ความละเอียดต่ำกว่าเพื่อลดภาระ CPU · STILL หยุดภาพนิ่ง",
                                12, "body", "#6f6f6f", wrap=True))
        v.addStretch(1)
        return pg

    # ---------------------------------------------------------------- worker
    def _start_worker(self):
        self.bh_failed = False
        q = "full" if self.quality == "still" else self.quality
        self.worker = BHWorker(q)
        self.worker.still = self.quality == "still"
        self.worker.frame.connect(self._on_frame)
        self.worker.ready.connect(lambda: self.bh_alpha.to(1.0))
        self.worker.failed.connect(self._on_bh_failed)
        self._push_motion()
        self.worker.start()

    def _set_quality(self, q: str):
        if q == self.quality:
            return
        self.quality = q
        for k, n in self.qlinks.items():
            n.set_active(k == q)
        old = self.worker
        old.frame.disconnect()
        old.stop()
        self._start_worker()

    def _on_frame(self, main, bloom):
        self._img, self._bloom = main, bloom
        if self.profile == "PULSE":
            self._push_motion()
        lp = self.mapFromGlobal(QCursor.pos())
        tx = (lp.x() / max(self.width(), 1) - 0.5) * -26
        ty = (lp.y() / max(self.height(), 1) - 0.5) * -16
        self._par += (QPointF(tx, ty) - self._par) * 0.07
        self.update()
        self.worker.consumed()

    def _on_bh_failed(self, msg: str):
        self.bh_failed = True
        self._log(f"[black hole renderer stopped] {msg}")

    def _beat(self) -> float:
        """0..1 phase of the PULSE heartbeat (2.4 s)."""
        return ((time.perf_counter() - self._t0) % 2.4) / 2.4

    def _push_motion(self):
        a = self.act.value
        if hasattr(self, "worker"):
            flare = 0.16 * math.exp(-self._beat() * 5.5) if self.profile == "PULSE" else 0.0
            self.worker.speed = self.spd.value * (1.0 + 0.9 * a)
            self.worker.intensity = self.inten.value * (1.0 + 0.10 * a + flare)

    # --------------------------------------------------------------- actions
    def show_page(self, name: str):
        gif = name == "GIF HUB"
        self.gifhub.setVisible(gif)
        self.stack.setVisible(not gif)
        self.dim.to(0.22 if gif else 1.0)
        if gif:
            self.gifhub.raise_()
        else:
            self.stack.setCurrentIndex({"HOME": 0, "LOG": 1, "ABOUT": 2}[name])
        for k, n in self.header.nav.items():
            n.set_active(k == name)

    def _select(self, key: str, instant: bool = False):
        if self.running and not instant:
            return
        changed = key != self.profile or instant
        self.profile = key
        for k, r in self.rows.items():
            r.set_selected(k == key)
        d = PROFILES[key]
        self.opt.sub = d["title"] + ("  ·  " + d["warn"] if d.get("warn") else "")
        self.opt.variant = key.lower()
        self.opt.update()
        self.spd.to(d["speed"])
        self.inten.to(d["intensity"])
        if self.opt.state in ("done", "failed"):
            self.opt.set_state("idle", "OPTIMIZE")
        if instant or not changed:
            self._fill_info()
        else:
            self.fade.to(0.0)
            QTimer.singleShot(150, self._swap_info)

    def _swap_info(self):
        self._fill_info()
        self.fade.to(1.0)

    def _fill_info(self):
        d = PROFILES[self.profile]
        self.desc.setText(d["desc"])
        self.feat.setText("".join(f"<div style='margin-bottom:4px'>—&nbsp;&nbsp;{t}</div>" for t in d["features"]))

    def _ask_optimize(self):
        if self.running:
            return
        d = PROFILES[self.profile]
        dlg = Confirm(self, f"OPTIMIZE · {d['title']}",
                      d.get("confirm") or
                      "แอปจะปรับค่า Windows ตามโปรไฟล์นี้ (ขอสิทธิ์ผู้ดูแลระบบ) โดยสร้างจุดคืนค่าและสำรองค่าเดิมไว้ก่อน "
                      "เมื่อเสร็จแล้วให้รีสตาร์ทเครื่องเพื่อให้ค่าทั้งหมดมีผล ต้องการดำเนินการต่อหรือไม่?", "CONTINUE")
        if dlg.exec() == QDialog.Accepted:
            self._start("optimize")

    def _ask_reset(self):
        if self.running:
            return
        d = PROFILES[self.profile]
        dlg = Confirm(self, f"GLOBAL RESET · {d['title']}",
                      "คืนเฉพาะค่าที่โปรไฟล์นี้เคยปรับไว้ตาม backup ของสคริปต์เดิม (ไม่ใช่การรีเซ็ตทั้งระบบ) "
                      "หมายเหตุ: ไฟล์ที่ Disk Cleanup ลบไปแล้วจะกู้คืนไม่ได้", "RESET")
        if dlg.exec() == QDialog.Accepted:
            self._start("restore")

    def _start(self, mode: str):
        self.log.clear()
        if not self.backend.run(self.profile, mode):
            return
        self.running = True
        self.mode = mode
        for r in self.rows.values():
            r.locked = True
        if mode == "optimize":
            self.opt.set_state("running", "OPTIMIZING")
            self.set_status("RUNNING · waiting for administrator approval")
        else:
            self.rst.set_busy(True)
            self.set_status("RESETTING · waiting for administrator approval")
        self.act.to(1.0)
        self._pt.start()

    def _on_line(self, ln: str):
        self._log(ln)
        txt = ln.strip()
        if txt:
            self.set_status(("RUNNING · " if self.mode == "optimize" else "RESETTING · ") + txt)

    def _on_finished(self, mode: str, code: int, note: str):
        self.running = False
        for r in self.rows.values():
            r.locked = False
        self.act.to(0.0)
        self._pt.stop()
        self.rst.set_busy(False)
        ok = code == 0
        if mode == "optimize":
            if ok:
                self.opt.set_state("done", "DONE")
                self.set_status("COMPLETE · restart your PC to apply")
            elif code == -4:
                self.opt.set_state("idle", "OPTIMIZE")
                self.set_status("CANCELLED")
            else:
                self.opt.set_state("failed", "FAILED")
                self.set_status(f"FAILED · {note or 'exit code ' + str(code)} · see LOG")
            QTimer.singleShot(9000, lambda: self.opt.state in ("done", "failed") and not self.running
                              and self.opt.set_state("idle", "OPTIMIZE"))
        else:
            if ok:
                self.set_status("RESET COMPLETE · restart your PC to apply")
            elif code == -4:
                self.set_status("CANCELLED")
            else:
                self.set_status(f"RESET FAILED · {note or 'exit code ' + str(code)} · see LOG")
        if note:
            self._log(f"[{note}]")

    def _log(self, s: str):
        self.log.appendPlainText(s)

    def set_status(self, s: str):
        self.status = s
        self.update(0, self.height() - FOOT_H, self.width(), FOOT_H)

    def _pulse_tick(self):
        self._pulse = (self._pulse + 0.08) % 1.0
        self.update(0, self.height() - FOOT_H, 240, FOOT_H)

    # ---------------------------------------------------------------- window
    def toggle_max(self):
        self.showNormal() if self.isMaximized() else self.showMaximized()

    def panel_width(self) -> int:
        return int(max(390, min(470, self.width() * 0.30)))

    def resizeEvent(self, e):
        w, h = self.width(), self.height()
        self.header.setGeometry(0, 0, w, HEADER_H)
        pw = self.panel_width()
        self.stack.setGeometry(w - pw - 56, HEADER_H + 12, pw, h - HEADER_H - FOOT_H - 20)
        self.gifhub.setGeometry(0, HEADER_H, w, h - HEADER_H - FOOT_H)
        self.grip.move(w - 16, h - 16)

    def _edges(self, pos):
        m, e = 6, Qt.Edges()
        if pos.x() < m:
            e |= Qt.LeftEdge
        if pos.x() > self.width() - m:
            e |= Qt.RightEdge
        if pos.y() > self.height() - m:
            e |= Qt.BottomEdge
        return e

    def mouseMoveEvent(self, ev):
        e = self._edges(ev.position().toPoint())
        cur = {Qt.LeftEdge: Qt.SizeHorCursor, Qt.RightEdge: Qt.SizeHorCursor, Qt.BottomEdge: Qt.SizeVerCursor}
        self.setCursor(cur.get(e, Qt.ArrowCursor) if e in cur else (Qt.SizeFDiagCursor if e else Qt.ArrowCursor))

    def mousePressEvent(self, ev):
        e = self._edges(ev.position().toPoint())
        if e and ev.button() == Qt.LeftButton and self.windowHandle():
            self.windowHandle().startSystemResize(e)

    def closeEvent(self, ev):
        try:
            self.worker.frame.disconnect()
            self.worker.stop()
        finally:
            super().closeEvent(ev)

    def changeEvent(self, ev):
        if ev.type() == QEvent.WindowStateChange and hasattr(self, "worker"):
            self.worker.paused = self.isMinimized()          # no rendering while minimised
        super().changeEvent(ev)

    # ----------------------------------------------------------------- paint
    def paintEvent(self, e):
        p = QPainter(self)
        W, H = self.width(), self.height()
        p.fillRect(self.rect(), QColor(0, 0, 0))
        dim = self.dim.value
        if self._img is not None and not self.bh_failed:
            p.setRenderHint(QPainter.SmoothPixmapTransform)
            p.setRenderHint(QPainter.Antialiasing)
            av_h = H - HEADER_H - FOOT_H
            aspect = self._img.width() / self._img.height()
            ih = av_h * 1.04
            iw = min(ih * aspect * 0.80, W * 0.78)
            ease = self.bh_alpha.value
            iw *= 0.92 + 0.08 * ease                       # slow "arrival" zoom
            ih = iw / aspect
            cx = W * 0.37 + self._par.x()
            cy = HEADER_H + av_h * 0.50 + self._par.y()
            rect = QRectF(cx - iw / 2, cy - ih / 2, iw, ih)
            a = ease * dim
            p.setOpacity(a)
            p.drawImage(rect, self._img)
            if self._bloom is not None:
                p.setCompositionMode(QPainter.CompositionMode_Plus)
                p.setOpacity(0.62 * a)
                p.drawImage(rect, self._bloom)
            # anamorphic flare along the disk plane, with a hole where the shadow is
            tt = time.perf_counter() - self._t0
            sr = 0.1354 * iw                               # apparent shadow radius (px)
            L = iw * 0.62
            p.setCompositionMode(QPainter.CompositionMode_Plus)
            p.save()
            p.translate(cx, cy)
            p.rotate(-6.0)
            hole = sr * 1.02 / (2 * L)
            for hh, al in ((1.6, 215), (14.0, 34), (60.0, 9)):
                g2 = QLinearGradient(-L, 0, L, 0)
                g2.setColorAt(0.0, gray(255, 0))
                g2.setColorAt(max(0.5 - hole - 0.22, 0.01), gray(255, int(al * 0.55)))
                g2.setColorAt(0.5 - hole, gray(255, al))
                g2.setColorAt(0.5 - hole + 0.0001, gray(255, 0))
                g2.setColorAt(0.5 + hole - 0.0001, gray(255, 0))
                g2.setColorAt(0.5 + hole, gray(255, int(al * 0.8)))
                g2.setColorAt(min(0.5 + hole + 0.22, 0.99), gray(255, int(al * 0.4)))
                g2.setColorAt(1.0, gray(255, 0))
                p.setOpacity((0.30 + 0.07 * math.sin(tt * 0.9)) * a * (1.0 if hh < 5 else 0.8))
                p.fillRect(QRectF(-L, -hh / 2, 2 * L, hh), g2)
            p.restore()
            p.setCompositionMode(QPainter.CompositionMode_SourceOver)
            # restrained technical call-outs (left side only)
            if dim > 0.9 and ease > 0.95:
                lab = gray(150, 150)
                for ang, text in ((-138.0, "SHADOW · 5.2 M"), (146.0, "PHOTON RING")):
                    th = math.radians(ang)
                    p0 = QPointF(cx + math.cos(th) * (sr * 1.04), cy + math.sin(th) * (sr * 1.04))
                    p1 = p0 + QPointF(math.cos(th) * 70, math.sin(th) * 70)
                    end = QPointF(p1.x() - 120, p1.y())
                    p.setOpacity(1.0)
                    p.setPen(QPen(gray(255, 70), 1))
                    p.drawLine(p0, p1)
                    p.drawLine(p1, end)
                    p.setBrush(gray(255, 200))
                    p.setPen(Qt.NoPen)
                    p.drawEllipse(p0, 2.2, 2.2)
                    
                    p.setPen(gray(215))
                    p.setFont(font("mono", 9, spacing=2.2))
                    p.drawText(QRectF(end.x(), p1.y() - 20, 130, 16), Qt.AlignVCenter | Qt.AlignLeft, text)
            if self.profile == "PULSE" and dim > 0.9:          # heartbeat shock ring
                ph = self._beat()
                rr = sr * (1.06 + 1.9 * (1 - (1 - ph) ** 2))
                p.setOpacity(1.0)
                p.setBrush(Qt.NoBrush)
                p.setPen(QPen(gray(255, int(150 * (1 - ph) ** 1.6)), 1.4))
                p.drawEllipse(QPointF(cx, cy), rr, rr)
            p.setOpacity(1.0)
        # calm the area behind the controls
        px = W - self.panel_width() - 56
        sc = max(0.0, min(1.0, (dim - 0.22) / 0.78))
        g = QLinearGradient(px - 150, 0, px + 10, 0)
        g.setColorAt(0, gray(0, 0))
        g.setColorAt(1, gray(0, int(215 * sc)))
        p.fillRect(QRectF(px - 150, 0, W - px + 150, H), g)
        # footer: status
        y = H - FOOT_H
        p.setRenderHint(QPainter.Antialiasing)
        cx0, cy0 = 40, y + FOOT_H / 2
        if self.running:
            r = 3.2 + 2.0 * abs(0.5 - self._pulse) * 2
            p.setPen(Qt.NoPen)
            p.setBrush(gray(255, 90))
            p.drawEllipse(QPointF(cx0, cy0), r + 3, r + 3)
        p.setPen(Qt.NoPen)
        p.setBrush(gray(245) if not self.status.startswith("FAILED") else gray(0))
        p.drawEllipse(QPointF(cx0, cy0), 3.2, 3.2)
        if self.status.startswith("FAILED") or self.status.startswith("RESET FAILED"):
            p.setPen(QPen(gray(245), 1.2))
            p.setBrush(Qt.NoBrush)
            p.drawEllipse(QPointF(cx0, cy0), 3.2, 3.2)
        p.setPen(gray(120))
        p.setFont(font("mono", 10, spacing=2.4))
        p.drawText(QRectF(56, y, 70, FOOT_H), Qt.AlignVCenter | Qt.AlignLeft, "STATUS")
        p.setPen(gray(232))
        f = font("mono", 11, spacing=1.0)
        p.setFont(f)
        txt = QFontMetrics(f).elidedText(self.status, Qt.ElideRight, max(120, int(W - 56 - 130 - 360)))
        p.drawText(QRectF(130, y, W - 130 - 360, FOOT_H), Qt.AlignVCenter | Qt.AlignLeft, txt)
        p.setPen(gray(85))
        p.setFont(font("mono", 9, spacing=2.2))
        p.drawText(QRectF(W - 56 - 300, y, 300, FOOT_H), Qt.AlignVCenter | Qt.AlignRight, "BANNARAKX · v2.0")
