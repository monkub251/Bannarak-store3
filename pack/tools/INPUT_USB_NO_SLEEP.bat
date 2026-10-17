@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INPUT_USB_NO_SLEEP.ps1" %*
