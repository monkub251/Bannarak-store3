@echo off
chcp 65001 >nul
title BANNARAKX NETFORGE - SAVE CURRENT (ORIGINAL) VALUES

net session >nul 2>&1
if errorlevel 1 goto :elevate
goto :main
:elevate
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b
:main

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "OUT=%USERPROFILE%\Documents\NETFORGE_ORIGINAL_BACKUP\%TS%"
mkdir "%OUT%" >nul 2>&1

echo.
echo   Saving your CURRENT registry values (run this BEFORE applying the .reg files)
echo   Folder: %OUT%
echo.
reg export "HKCU\Control Panel\Mouse" "%OUT%\01_mouse.reg" /y >nul 2>&1 && (echo   [OK]   mouse) || (echo   [skip] mouse  ^(key does not exist - nothing to save^))
reg export "HKCU\Control Panel\Keyboard" "%OUT%\02_keyboard.reg" /y >nul 2>&1 && (echo   [OK]   keyboard) || (echo   [skip] keyboard  ^(key does not exist - nothing to save^))
reg export "HKCU\Control Panel\Accessibility" "%OUT%\03_accessibility.reg" /y >nul 2>&1 && (echo   [OK]   accessibility) || (echo   [skip] accessibility  ^(key does not exist - nothing to save^))
reg export "HKCU\System\GameConfigStore" "%OUT%\04_gameconfigstore.reg" /y >nul 2>&1 && (echo   [OK]   gameconfigstore) || (echo   [skip] gameconfigstore  ^(key does not exist - nothing to save^))
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" "%OUT%\05_gamedvr.reg" /y >nul 2>&1 && (echo   [OK]   gamedvr) || (echo   [skip] gamedvr  ^(key does not exist - nothing to save^))
reg export "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" "%OUT%\06_usergpuprefs.reg" /y >nul 2>&1 && (echo   [OK]   usergpuprefs) || (echo   [skip] usergpuprefs  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "%OUT%\07_mouclass.reg" /y >nul 2>&1 && (echo   [OK]   mouclass) || (echo   [skip] mouclass  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "%OUT%\08_kbdclass.reg" /y >nul 2>&1 && (echo   [OK]   kbdclass) || (echo   [skip] kbdclass  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\USB" "%OUT%\09_usb.reg" /y >nul 2>&1 && (echo   [OK]   usb) || (echo   [skip] usb  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "%OUT%\10_priorityctl.reg" /y >nul 2>&1 && (echo   [OK]   priorityctl) || (echo   [skip] priorityctl  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "%OUT%\11_kernel.reg" /y >nul 2>&1 && (echo   [OK]   kernel) || (echo   [skip] kernel  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "%OUT%\12_powerthrottling.reg" /y >nul 2>&1 && (echo   [OK]   powerthrottling) || (echo   [skip] powerthrottling  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "%OUT%\13_mmcss.reg" /y >nul 2>&1 && (echo   [OK]   mmcss) || (echo   [skip] mmcss  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "%OUT%\14_tcpip.reg" /y >nul 2>&1 && (echo   [OK]   tcpip) || (echo   [skip] tcpip  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "%OUT%\15_tcpip6.reg" /y >nul 2>&1 && (echo   [OK]   tcpip6) || (echo   [skip] tcpip6  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" "%OUT%\16_tcpip_qos.reg" /y >nul 2>&1 && (echo   [OK]   tcpip_qos) || (echo   [skip] tcpip_qos  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "%OUT%\17_dnscache.reg" /y >nul 2>&1 && (echo   [OK]   dnscache) || (echo   [skip] dnscache  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "%OUT%\18_pol_dnsclient.reg" /y >nul 2>&1 && (echo   [OK]   pol_dnsclient) || (echo   [skip] pol_dnsclient  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" "%OUT%\19_pol_psched.reg" /y >nul 2>&1 && (echo   [OK]   pol_psched) || (echo   [skip] pol_psched  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS" "%OUT%\20_pol_qos.reg" /y >nul 2>&1 && (echo   [OK]   pol_qos) || (echo   [skip] pol_qos  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "%OUT%\21_pol_do.reg" /y >nul 2>&1 && (echo   [OK]   pol_do) || (echo   [skip] pol_do  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "%OUT%\22_pol_wu_au.reg" /y >nul 2>&1 && (echo   [OK]   pol_wu_au) || (echo   [skip] pol_wu_au  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "%OUT%\23_pol_appprivacy.reg" /y >nul 2>&1 && (echo   [OK]   pol_appprivacy) || (echo   [skip] pol_appprivacy  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "%OUT%\24_pol_v6transition.reg" /y >nul 2>&1 && (echo   [OK]   pol_v6transition) || (echo   [skip] pol_v6transition  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" "%OUT%\25_pol_store.reg" /y >nul 2>&1 && (echo   [OK]   pol_store) || (echo   [skip] pol_store  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Peernet" "%OUT%\26_pol_peernet.reg" /y >nul 2>&1 && (echo   [OK]   pol_peernet) || (echo   [skip] pol_peernet  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" "%OUT%\27_wifisense.reg" /y >nul 2>&1 && (echo   [OK]   wifisense) || (echo   [skip] wifisense  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "%OUT%\28_memmgmt.reg" /y >nul 2>&1 && (echo   [OK]   memmgmt) || (echo   [skip] memmgmt  ^(key does not exist - nothing to save^))
reg export "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" "%OUT%\29_deviceguard.reg" /y >nul 2>&1 && (echo   [OK]   deviceguard) || (echo   [skip] deviceguard  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "%OUT%\30_wer.reg" /y >nul 2>&1 && (echo   [OK]   wer) || (echo   [skip] wer  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "%OUT%\31_pol_wer.reg" /y >nul 2>&1 && (echo   [OK]   pol_wer) || (echo   [skip] pol_wer  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "%OUT%\32_pol_search.reg" /y >nul 2>&1 && (echo   [OK]   pol_search) || (echo   [skip] pol_search  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "%OUT%\33_pol_system.reg" /y >nul 2>&1 && (echo   [OK]   pol_system) || (echo   [skip] pol_system  ^(key does not exist - nothing to save^))
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "%OUT%\34_pol_cloudcontent.reg" /y >nul 2>&1 && (echo   [OK]   pol_cloudcontent) || (echo   [skip] pol_cloudcontent  ^(key does not exist - nothing to save^))
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" "%OUT%\35_hkcu_search.reg" /y >nul 2>&1 && (echo   [OK]   hkcu_search) || (echo   [skip] hkcu_search  ^(key does not exist - nothing to save^))
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "%OUT%\36_hkcu_bgapps.reg" /y >nul 2>&1 && (echo   [OK]   hkcu_bgapps) || (echo   [skip] hkcu_bgapps  ^(key does not exist - nothing to save^))

echo.
echo   ------------------------------------------------------------
echo    Done. To go back: double-click the .reg files in that folder.
echo    Note: a .reg restore re-writes saved values but cannot delete
echo    values that did not exist before - use the *_UNDO.reg for those.
echo   ------------------------------------------------------------
echo.
start "" explorer "%OUT%"
pause
