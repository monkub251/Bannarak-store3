"""BANNARAKX · FIVE M FPS OPTIMIZER  (PySide6)."""
import argparse
import sys

from PySide6.QtGui import QFont, QIcon
from PySide6.QtWidgets import QApplication

from app import theme
from app.window import MainWindow


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quality", choices=["full", "lite", "still"], default="full")
    args, qt_args = ap.parse_known_args()
    app = QApplication([sys.argv[0]] + qt_args)
    theme.load_fonts()
    base = theme.font("body", 14)
    app.setFont(base)
    app.setWindowIcon(QIcon(theme.resource_path("assets", "icon.ico")))
    win = MainWindow(args.quality)
    win.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
