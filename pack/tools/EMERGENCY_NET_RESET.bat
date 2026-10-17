@echo off
chcp 65001 >nul
title BANNARAKX NETFORGE - EMERGENCY NETWORK RESET
color 0B

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [!] Requesting Administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo   ============================================================
echo    BANNARAKX NETFORGE  ::  EMERGENCY NETWORK RESET
echo   ============================================================
echo    Use this if the internet stops working after tuning.
echo    It does NOT touch the registry tweaks of NETFORGE or APEX.
echo   ============================================================
echo.

echo   [1/5] DNS on all adapters  ^>  Automatic (DHCP)
powershell -NoProfile -Command "Get-NetAdapter | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses }" >nul 2>&1
echo         done

echo   [2/5] Flush DNS / ARP / NetBIOS caches
ipconfig /flushdns >nul 2>&1
netsh int ip delete arpcache >nul 2>&1
nbtstat -R >nul 2>&1
nbtstat -RR >nul 2>&1
echo         done

echo   [3/5] TCP global settings  ^>  Windows standard
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global ecncapability=disabled >nul 2>&1
netsh int tcp set global timestamps=disabled >nul 2>&1
powershell -NoProfile -Command "Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enabled" >nul 2>&1
echo         done

echo   [4/5] Reset Winsock catalog
netsh winsock reset >nul 2>&1
echo         done

echo.
echo   [5/5] OPTIONAL: Reset the whole TCP/IP stack  (netsh int ip reset)
echo         Fixes deeper problems, but may clear a STATIC IP address
echo         you set manually. Skip it if you use a static IP.
choice /c YN /n /m "         Run it now? [Y/N] : "
if errorlevel 2 goto :skipip
netsh int ip reset >nul 2>&1
echo         done
:skipip

echo.
echo   ------------------------------------------------------------
echo    Finished. A restart is required for Winsock reset to apply.
echo   ------------------------------------------------------------
choice /c YN /n /m "   Restart now? [Y/N] : "
if errorlevel 2 goto :end
shutdown /r /t 5 /c "BANNARAKX NETFORGE : emergency network reset"
:end
echo.
pause
