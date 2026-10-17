@echo off
cd /d "%~dp0"
echo Installing build requirements...
python -m pip install -r requirements.txt || goto :fail
echo Building FiveM_FPS_Optimizer.exe (asks for Administrator when launched)...
python -m PyInstaller --noconfirm --clean --onefile --windowed --uac-admin ^
  --name FiveM_FPS_Optimizer --icon assets\icon.ico ^
  --add-data "assets;assets" --add-data "pack;pack" --add-data "cache;cache" --add-data "gifs;gifs" ^
  --exclude-module tkinter --exclude-module PySide6.QtWebEngineCore main.py || goto :fail
echo.
echo [OK] dist\FiveM_FPS_Optimizer.exe
pause
exit /b 0
:fail
echo [X] Build failed
pause
exit /b 1
