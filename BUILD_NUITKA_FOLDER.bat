@echo off
cd /d "%~dp0"
echo [1/2] Installing build requirements...
python -m pip install -r requirements_nuitka.txt || goto :fail
echo [2/2] Compiling (folder mode: opens faster, flagged by antivirus less often)...
python -m nuitka --standalone --enable-plugin=pyside6 --include-qt-plugins=sensible,imageformats --windows-console-mode=disable --windows-uac-admin --windows-icon-from-ico=assets\icon.ico --include-data-dir=assets=assets --include-data-dir=pack=pack --include-data-dir=cache=cache --include-data-dir=gifs=gifs --nofollow-import-to=tkinter --nofollow-import-to=PySide6.QtWebEngineCore --company-name=BANNARAKX --product-name="FiveM FPS Optimizer" --file-description="FiveM FPS Optimizer" --file-version=1.0.0.0 --product-version=1.0.0.0 --assume-yes-for-downloads --output-dir=dist_nuitka --output-filename=FiveM_FPS_Optimizer.exe main.py || goto :fail
echo.
echo [OK] dist_nuitka\main.dist\FiveM_FPS_Optimizer.exe  (copy the whole main.dist folder)
pause
exit /b 0
:fail
echo [X] Build failed - use Python 3.11 or 3.12 (64-bit)
pause
exit /b 1
