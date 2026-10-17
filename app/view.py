"""Background render thread for the black hole (never touches the GUI thread)."""
from __future__ import annotations

import os
import threading
import time

import numpy as np
from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QImage

from . import blackhole as bh
from .theme import resource_path

QUALITY = {
    "full": (bh.Params(), 30),
    "lite": (bh.Params(width=500, height=300), 24),
}


def _user_cache() -> str:
    base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "BannarakxFiveM", "cache")


class BHWorker(QObject):
    frame = Signal(object, object)      # main QImage, bloom QImage
    ready = Signal()
    failed = Signal(str)

    def __init__(self, quality: str = "full"):
        super().__init__()
        self.quality = quality if quality in QUALITY else "full"
        self.speed = 1.0
        self.intensity = 1.0
        self.paused = False
        self.still = False
        self._stop = False
        self._ack = threading.Event()
        self._ack.set()
        self._thr: threading.Thread | None = None
        self.ms_last = 0.0

    def start(self) -> None:
        self._thr = threading.Thread(target=self._run, daemon=True, name="blackhole")
        self._thr.start()

    def stop(self) -> None:
        self._stop = True
        self._ack.set()
        if self._thr:
            self._thr.join(timeout=2)

    def consumed(self) -> None:
        self._ack.set()

    # ------------------------------------------------------------------
    def _run(self) -> None:
        try:
            params, fps = QUALITY[self.quality]
            shipped = resource_path("cache")
            if os.path.exists(os.path.join(shipped, params.key() + ".npz")):
                data = bh.load_or_build(params, shipped)
            else:
                data = bh.load_or_build(params, _user_cache())
            rend = bh.BlackHoleRenderer(params, data)
        except Exception as e:                      # rendering problems never affect the optimiser
            self.failed.emit(f"{type(e).__name__}: {e}")
            return
        self.ready.emit()
        W, H = params.width, params.height
        phase = 0.0
        last = time.perf_counter()
        sent_still = False
        while not self._stop:
            now = time.perf_counter()
            dt = min(now - last, 0.1)
            last = now
            if self.paused or (self.still and sent_still):
                time.sleep(0.1)
                continue
            phase += dt * self.speed
            t0 = time.perf_counter()
            try:
                gray = rend.render(phase, 1.0, self.intensity)
                main = QImage(gray.data, W, H, W, QImage.Format_Grayscale8).copy()
                small = gray.reshape(H // 4, 4, W // 4, 4).mean(axis=(1, 3)).astype(np.float32)
                for _ in range(3):                               # soft bloom source
                    small = (small + np.roll(small, 1, 0) + np.roll(small, -1, 0)
                             + np.roll(small, 1, 1) + np.roll(small, -1, 1)) / 5.0
                b8 = np.ascontiguousarray(np.clip(small * 0.95, 0, 255).astype(np.uint8))
                bloom = QImage(b8.data, b8.shape[1], b8.shape[0], b8.shape[1],
                               QImage.Format_Grayscale8).copy()
            except Exception as e:
                self.failed.emit(f"{type(e).__name__}: {e}")
                return
            self._ack.clear()
            self.frame.emit(main, bloom)
            sent_still = True
            self._ack.wait(0.25)
            el = time.perf_counter() - t0
            self.ms_last = el * 1000
            time.sleep(max(0.0, 1.0 / fps - el))
