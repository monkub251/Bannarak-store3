"""
Bridge to the ORIGINAL optimisation scripts in ./pack (they are not modified).

  ULTIMATE V2  ->  pack/BANNARAKX_ULTIMATE.ps1   (-Auto)       / menu "R" = restore
  PULSE V2     ->  pack/BANNARAKX_NETFORGE.ps1   (-Auto)       / menu "R" = restore

The scripts need Administrator rights.  When this program is already elevated
(recommended: build with --uac-admin) they run directly; otherwise they are
started through the Windows UAC "runas" prompt.  Output is written to a log
file which is tailed into the LOG page.  -NoReboot is always passed so the PC
never restarts behind a hidden window.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import threading
import time

from PySide6.QtCore import QObject, Signal

from .theme import resource_path

IS_WIN = sys.platform.startswith("win")
DEMO = os.environ.get("BANNARAKX_DEMO") == "1"      # UI test mode, never used by default

# ULTIMATE V2 : the ULTIMATE script as-is.
# PULSE V2    : MAX / full-system.  ULTIMATE+ (-Plus: also stops Windows Update, printing,
#               RDP, file sharing) followed by the pack's EXTREME .reg files.  Every piece
#               already exists in the pack and has its own UNDO.  07_OPTIONAL_SECURITY_OFF
#               (mitigations / VBS) is deliberately NOT included.
PROFILES = {
    "ULTIMATE": {"script": "BANNARAKX_ULTIMATE.ps1", "extra": "",
                 "regs": []},
    "PULSE": {"script": "BANNARAKX_ULTIMATE.ps1", "extra": " -Plus",
              "regs": ["04_INPUT_SYSTEM_EXTREME", "05_GPEDIT_INTERNET_EXTREME", "06_PROCESS_REDUCE"]},
}

_ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def pack_dir() -> str:
    return resource_path("pack")


def work_dir() -> str:
    base = os.environ.get("ProgramData") or os.path.join(os.path.expanduser("~"), ".bannarakx")
    d = os.path.join(base, "BannarakxOptimizerGUI")
    os.makedirs(d, exist_ok=True)
    return d


def is_admin() -> bool:
    if not IS_WIN:
        return False
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


class Backend(QObject):
    line = Signal(str)
    finished = Signal(str, int, str)        # mode, exit code, note

    def __init__(self, parent=None):
        super().__init__(parent)
        self.busy = False

    # -- public -----------------------------------------------------------
    def run(self, profile: str, mode: str) -> bool:
        """mode: 'optimize' | 'restore'.  Returns False if already busy."""
        if self.busy:
            return False
        self.busy = True
        threading.Thread(target=self._guard, args=(profile, mode), daemon=True).start()
        return True

    # -- internals --------------------------------------------------------
    def _guard(self, profile: str, mode: str) -> None:
        try:
            code, note = self._execute(profile, mode)
        except Exception as e:                       # never let the GUI hang
            code, note = -1, f"{type(e).__name__}: {e}"
        self.busy = False
        self.finished.emit(mode, code, note)

    def _execute(self, profile: str, mode: str) -> tuple[int, str]:
        if DEMO:
            return self._demo(profile, mode)
        if not IS_WIN:
            return -3, "Windows only"
        script = os.path.join(pack_dir(), PROFILES[profile]["script"])
        if not os.path.isfile(script):
            return -2, "script not found: " + os.path.basename(script)
        for name in PROFILES[profile]["regs"]:
            for suffix in ("", "_UNDO"):
                if not os.path.isfile(os.path.join(pack_dir(), "reg", name + suffix + ".reg")):
                    return -2, f"file not found: {name}{suffix}.reg"

        wd = work_dir()
        log = os.path.join(wd, "run.log")
        codef = os.path.join(wd, "run.code")
        wrapper = os.path.join(wd, "run.cmd")
        for f in (log, codef):
            try:
                os.remove(f)
            except OSError:
                pass

        prof = PROFILES[profile]
        regdir = os.path.join(pack_dir(), "reg")
        ps_args = f'-NoProfile -ExecutionPolicy Bypass -File "{script}" -NoReboot'
        lines = ["@echo off", "chcp 65001 >nul", "set RC=0"]
        if mode == "optimize":
            lines.append(f'powershell.exe {ps_args}{prof["extra"]} -Auto < NUL > "{log}" 2>&1')
            lines.append("if errorlevel 1 set RC=1")
            for name in prof["regs"]:
                f = os.path.join(regdir, name + ".reg")
                lines.append(f'echo [PULSE] import {name} >> "{log}"')
                lines.append(f'reg.exe import "{f}" >> "{log}" 2>&1')
                lines.append("if errorlevel 1 set RC=1")
        else:  # restore: feed the script's own menu with "R", then the UNDO files
            lines.append(f'(echo R) | powershell.exe {ps_args} > "{log}" 2>&1')
            lines.append("if errorlevel 1 set RC=1")
            for name in reversed(prof["regs"]):
                f = os.path.join(regdir, name + "_UNDO.reg")
                lines.append(f'echo [PULSE] import {name}_UNDO >> "{log}"')
                lines.append(f'reg.exe import "{f}" >> "{log}" 2>&1')
                lines.append("if errorlevel 1 set RC=1")
        lines.append(f'echo %RC%> "{codef}"')
        with open(wrapper, "w", encoding="utf-8", newline="\r\n") as fh:
            fh.write("\n".join(lines) + "\n")

        if is_admin():
            proc = subprocess.Popen(["cmd.exe", "/d", "/c", wrapper],
                                    creationflags=0x08000000)      # CREATE_NO_WINDOW
            waiter = lambda: proc.poll() is not None
            cleanup = lambda: None
        else:
            waiter, cleanup, err = self._runas(wrapper)
            if waiter is None:
                return (-4, "cancelled") if err == 1223 else (-1, f"could not start (error {err})")

        pos = 0
        while True:
            pos = self._tail(log, pos)
            if waiter():
                time.sleep(0.3)
                self._tail(log, pos)
                break
            time.sleep(0.25)
        cleanup()
        try:
            with open(codef, "r", encoding="ascii", errors="ignore") as fh:
                code = int(fh.read().strip() or "-1")
        except Exception:
            code = -1
        return code, ""

    def _tail(self, path: str, pos: int) -> int:
        try:
            with open(path, "rb") as fh:
                fh.seek(pos)
                data = fh.read()
        except OSError:
            return pos
        if not data:
            return pos
        text = data.decode("utf-8", errors="replace").replace("﻿", "")
        for ln in _ANSI.sub("", text).splitlines():
            ln = ln.rstrip()
            if ln.strip():
                self.line.emit(ln)
        return pos + len(data)

    def _runas(self, wrapper: str):
        import ctypes
        from ctypes import wintypes

        class SEI(ctypes.Structure):
            _fields_ = [("cbSize", wintypes.DWORD), ("fMask", wintypes.ULONG), ("hwnd", wintypes.HWND),
                        ("lpVerb", wintypes.LPCWSTR), ("lpFile", wintypes.LPCWSTR),
                        ("lpParameters", wintypes.LPCWSTR), ("lpDirectory", wintypes.LPCWSTR),
                        ("nShow", ctypes.c_int), ("hInstApp", wintypes.HINSTANCE),
                        ("lpIDList", ctypes.c_void_p), ("lpClass", wintypes.LPCWSTR),
                        ("hkeyClass", wintypes.HKEY), ("dwHotKey", wintypes.DWORD),
                        ("hIcon", wintypes.HANDLE), ("hProcess", wintypes.HANDLE)]

        sei = SEI()
        sei.cbSize = ctypes.sizeof(SEI)
        sei.fMask = 0x00000040                      # SEE_MASK_NOCLOSEPROCESS
        sei.lpVerb = "runas"
        sei.lpFile = "cmd.exe"
        sei.lpParameters = f'/d /s /c ""{wrapper}""'
        sei.nShow = 0                               # SW_HIDE
        if not ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
            return None, None, ctypes.windll.kernel32.GetLastError()
        h = sei.hProcess

        def waiter():
            return ctypes.windll.kernel32.WaitForSingleObject(h, 0) == 0

        def cleanup():
            ctypes.windll.kernel32.CloseHandle(h)

        return waiter, cleanup, 0

    def _demo(self, profile: str, mode: str) -> tuple[int, str]:
        steps = ["[DEMO] this is a UI simulation - nothing was changed",
                 f"[DEMO] profile {profile} / {mode}",
                 "[DEMO] step 1/3 ...", "[DEMO] step 2/3 ...", "[DEMO] step 3/3 ..."]
        for s in steps:
            self.line.emit(s)
            time.sleep(0.6)
        return 0, ""
