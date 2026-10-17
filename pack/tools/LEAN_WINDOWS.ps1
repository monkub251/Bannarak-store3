# ================================================================================
#  BANNARAKX NETFORGE  ::  LEAN WINDOWS
#  ลดจำนวน Process / Service / Scheduled Task เบื้องหลังให้มากที่สุด
#
#  - Backup สถานะเดิมก่อนแก้ทุกครั้ง (เก็บครั้งแรกไว้เสมอ)  ->  เมนู R คืนค่าได้
#  - ไม่แตะไฟล์ APEX เดิม  (ถ้า APEX ปิด service ไหนไว้แล้ว จะไม่ถูกบันทึกเป็นของเรา
#    และ Restore จะไม่เปิดมันกลับ)
#  - ใช้คู่กับ reg\06_PROCESS_REDUCE.reg  (รวม svchost ให้เหลือน้อยที่สุด)
#
#  สวิตช์: -Plus  โหมด aggressive (ปิด Windows Update / Print / Search / RDP / File sharing)
#         -Restore  คืนค่าเดิม     -Auto  ข้ามเมนู     -NoReboot  ไม่รีสตาร์ท
# ================================================================================
param(
    [switch]$Plus,
    [switch]$Restore,
    [switch]$Auto,
    [switch]$NoReboot
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-IsAdmin)) {
    if (-not $PSCommandPath) { Write-Host '  [X] Save as .ps1 and run from the file' -ForegroundColor Red; Read-Host | Out-Null; exit 1 }
    $argl = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    foreach ($p in @('Plus', 'Restore', 'Auto', 'NoReboot')) { if ((Get-Variable $p).Value) { $argl += (' -' + $p) } }
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $argl -Verb RunAs | Out-Null } catch { Write-Host '  [X] Administrator rights are required' -ForegroundColor Red; Read-Host | Out-Null }
    exit
}

$Script:Root = Join-Path $env:ProgramData 'BannarakxNetForge'
$Script:Bak  = Join-Path $Script:Root 'lean_backup.json'
$Script:Log  = Join-Path $Script:Root ('lean_{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
New-Item -ItemType Directory -Path $Script:Root -Force | Out-Null

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $r = $Host.UI.RawUI; $r.BackgroundColor = 'Black'; $r.ForegroundColor = 'Gray'; $r.WindowTitle = 'BANNARAKX NETFORGE :: LEAN WINDOWS' } catch {}
try { $r = $Host.UI.RawUI; $b = $r.BufferSize; if ($b.Width -lt 100) { $b.Width = 100; $r.BufferSize = $b } } catch {}
try { $r = $Host.UI.RawUI; $w = $r.WindowSize; $w.Width = 100; $w.Height = [math]::Min(46, $r.MaxPhysicalWindowSize.Height); $r.WindowSize = $w } catch {}
try { $r = $Host.UI.RawUI; $b = $r.BufferSize; $b.Width = 100; $b.Height = 3000; $r.BufferSize = $b } catch {}
$Script:W = 88
try { $Script:W = [math]::Max(60, [math]::Min(88, $Host.UI.RawUI.WindowSize.Width - 6)) } catch {}

$Script:C = @{ pink = 'Magenta'; violet = 'DarkMagenta'; cyan = 'Cyan'; lime = 'Green'; amber = 'Yellow'; red = 'Red'; white = 'White'; gray = 'Gray'; dim = 'DarkGray'; ink = 'Black' }
$Script:Art = @(
    '██╗     ███████╗ █████╗ ███╗   ██╗',
    '██║     ██╔════╝██╔══██╗████╗  ██║',
    '██║     █████╗  ███████║██╔██╗ ██║',
    '██║     ██╔══╝  ██╔══██║██║╚██╗██║',
    '███████╗███████╗██║  ██║██║ ╚████║',
    '╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝'
)
$Script:StepNo = 0; $Script:StepNote = ''; $Script:Ok = 0; $Script:Skip = 0

function Log { param([string]$M) try { Add-Content -LiteralPath $Script:Log -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $M) -Encoding UTF8 } catch {} }

function Paint {
    param([string]$T, [string]$Fg = 'white', [string]$Bg = '', [switch]$NoNL)
    $a = @{ Object = $T; NoNewline = [bool]$NoNL; ForegroundColor = [string]$Script:C[$Fg] }
    if ($Bg) { $a['BackgroundColor'] = [string]$Script:C[$Bg] }
    Write-Host @a
}
function Chip { param([string]$T, [string]$Fg = 'ink', [string]$Bg = 'cyan', [switch]$NoNL) Paint (' ' + $T + ' ') $Fg $Bg -NoNL:$NoNL }
function Cut { param([string]$S, [int]$N) $S = ($S -replace '[^\x20-\x7E\u00B7]', '?'); if ($S.Length -gt $N) { return ($S.Substring(0, [math]::Max(0, $N - 1)) + '~') }; return $S }

function Show-ArtLine {
    param([string]$Line, [string[]]$Cols)
    $n = $Line.Length; $cur = 'Cyan'; $sb = New-Object System.Text.StringBuilder; $blk = [char]0x2588
    for ($i = 0; $i -lt $n; $i++) {
        $ch = $Line[$i]
        if ($ch -eq $blk) { $col = $Cols[[math]::Min($Cols.Count - 1, [int][math]::Floor($i * $Cols.Count / $n))] }
        elseif ($ch -eq ' ') { $col = $cur } else { $col = 'DarkGray' }
        if (($col -ne $cur) -and ($sb.Length -gt 0)) { Write-Host $sb.ToString() -NoNewline -ForegroundColor $cur; [void]$sb.Clear() }
        $cur = $col; [void]$sb.Append($ch)
    }
    if ($sb.Length -gt 0) { Write-Host $sb.ToString() -NoNewline -ForegroundColor $cur }
    Write-Host ''
}
function Show-Banner {
    try { Clear-Host } catch {}
    Paint ''
    Paint '   ' -NoNL; Paint 'B A N N A R A K X   N E T F O R G E' 'pink'
    Paint ''
    foreach ($l in $Script:Art) { Write-Host '   ' -NoNewline; Show-ArtLine $l @('Magenta', 'DarkMagenta', 'Blue', 'DarkCyan', 'Cyan'); Start-Sleep -Milliseconds 40 }
    Paint ''
    Paint '   ' -NoNL; Paint 'WINDOWS PROCESS REDUCER' 'white' -NoNL; Paint '   v1.0.0' 'dim'
    Paint ''
}
function Box-Top { param([string]$T, [string]$Col = 'cyan') $in = $Script:W - 2; $h = ' ' + $T + ' '; Paint '  ╔═' $Col -NoNL; Paint $h 'white' -NoNL; Paint (('═' * [math]::Max(1, $in - 1 - $h.Length)) + '╗') $Col }
function Box-Row { param([string]$K, [string]$V, [string]$VCol = 'white', [string]$Col = 'cyan') $kw = 18; $vw = ($Script:W - 2) - 2 - $kw; $V = Cut $V $vw; Paint '  ║ ' $Col -NoNL; Paint $K.PadRight($kw) 'gray' -NoNL; Paint $V.PadRight($vw) $VCol -NoNL; Paint ' ║' $Col }
function Box-Bottom { param([string]$Col = 'cyan') Paint ('  ╚' + ('═' * ($Script:W - 2)) + '╝') $Col }
function Sector {
    param([string]$No, [string]$Title, [string]$Sub = '', [string]$Col = 'cyan')
    $h = ('PHASE {0}  {1}' -f $No, $Title)
    Paint ''; Paint '  ■ ' $Col -NoNL; Paint $h 'white' -NoNL; Paint ' ' -NoNL; Paint ('─' * [math]::Max(4, $Script:W - 5 - $h.Length)) 'dim'
    if ($Sub) { Paint ('    ' + $Sub) 'gray' }
    Paint ''
}
function Say {
    param([string]$T, [string]$Kind = 'info')
    switch ($Kind) {
        'ok'    { Paint '   √ ' 'lime' -NoNL; Paint $T 'white' }
        'warn'  { Paint '   ▲ ' 'amber' -NoNL; Paint $T 'amber' }
        'bad'   { Paint '   × ' 'red' -NoNL; Paint $T 'red' }
        'dim'   { Paint ('     ' + $T) 'dim' }
        default { Paint '   ♦ ' 'cyan' -NoNL; Paint $T 'gray' }
    }
    Log $T
}
function Step {
    param([string]$Title, [scriptblock]$Do)
    $Script:StepNo++; $tag = '{0:00}' -f $Script:StepNo
    Paint ('   {0} ' -f $tag) 'dim' -NoNL; Paint '[ .... ] ' 'amber' -NoNL; Paint $Title 'gray' -NoNL
    $ok = $true; $Script:StepNote = ''; $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $r = @(& $Do); if ($r.Count -gt 0 -and $r[$r.Count - 1] -is [bool]) { $ok = $r[$r.Count - 1] } } catch { $ok = $false; Log ('STEP FAIL ' + $Title + ' :: ' + $_.Exception.Message) }
    $sw.Stop()
    Write-Host "`r" -NoNewline
    Paint ('   {0} ' -f $tag) 'dim' -NoNL
    if ($ok) { Paint '[  OK  ] ' 'lime' -NoNL; Paint $Title 'white' -NoNL; $Script:Ok++ } else { Paint '[ SKIP ] ' 'amber' -NoNL; Paint $Title 'gray' -NoNL; $Script:Skip++ }
    Paint ('  {0} ms' -f [int]$sw.Elapsed.TotalMilliseconds) 'dim'
    if ($Script:StepNote) { Paint ('            └ ' + $Script:StepNote) 'gray' }
    Log ('{0} => {1}' -f $Title, $ok)
}

# ------------------------------------------------------------------ BACKUP
$Script:B = [ordered]@{ Tool = 'LEAN'; Created = (Get-Date).ToString('o'); Services = (New-Object System.Collections.ArrayList); Tasks = (New-Object System.Collections.ArrayList); Split = $null; SplitSaved = $false }
$Script:Seen = @{}
function Load-Bak {
    if (-not (Test-Path -LiteralPath $Script:Bak)) { return }
    try {
        $d = Get-Content -LiteralPath $Script:Bak -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($d.Tool -ne 'LEAN') { return }
        foreach ($s in @($d.Services)) { if ($s) { [void]$Script:B['Services'].Add($s); $Script:Seen['S|' + ([string]$s.Name).ToLower()] = $true } }
        foreach ($t in @($d.Tasks))    { if ($t) { [void]$Script:B['Tasks'].Add($t);    $Script:Seen['T|' + ([string]$t.Path + [string]$t.Name).ToLower()] = $true } }
        if ($d.SplitSaved) { $Script:B['Split'] = $d.Split; $Script:B['SplitSaved'] = $true }
        if ($d.Created) { $Script:B['Created'] = $d.Created }
    } catch { Log ('Load-Bak failed: ' + $_.Exception.Message) }
}
function Save-Bak {
    try {
        $tmp = $Script:Bak + '.tmp'
        ($Script:B | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $tmp -Encoding UTF8
        $t = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($t.Tool -ne 'LEAN') { throw 'validate' }
        Move-Item -LiteralPath $tmp -Destination $Script:Bak -Force
        return $true
    } catch { Log ('Save-Bak failed: ' + $_.Exception.Message); return $false }
}

# ------------------------------------------------------------------ SERVICES / TASKS
function Get-SvcReg { param([string]$N) $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $N; if (-not (Test-Path -LiteralPath $k)) { return $null }; $p = Get-ItemProperty -LiteralPath $k; if ($null -eq $p.Start) { return $null }; return [pscustomobject]@{ Key = $k; Start = [int]$p.Start; Delayed = $p.DelayedAutostart } }

function Disable-Svc {
    param([string]$N)
    $s = Get-SvcReg $N
    if (-not $s) { return 'missing' }
    if ($s.Start -eq 4) { return 'already' }
    $k = 'S|' + $N.ToLower()
    if (-not $Script:Seen.ContainsKey($k)) {
        $Script:Seen[$k] = $true
        $dl = $null; if ($null -ne $s.Delayed) { $dl = [int]$s.Delayed }
        [void]$Script:B['Services'].Add([pscustomobject]@{ Name = $N; Start = $s.Start; Delayed = $dl })
    }
    try { Set-ItemProperty -LiteralPath $s.Key -Name 'Start' -Value 4 -Type DWord -ErrorAction Stop } catch { return 'denied' }
    foreach ($x in @(Get-Service -Name $N, ($N + '_*') -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })) { try { Stop-Service -InputObject $x -Force -ErrorAction SilentlyContinue } catch {} }
    return 'done'
}

function Disable-Task {
    param([string]$Path, [string]$Name)
    $t = Get-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $t) { return 'missing' }
    if ([string]$t.State -eq 'Disabled') { return 'already' }
    $k = 'T|' + ($Path + $Name).ToLower()
    if (-not $Script:Seen.ContainsKey($k)) { $Script:Seen[$k] = $true; [void]$Script:B['Tasks'].Add([pscustomobject]@{ Path = $Path; Name = $Name; State = [string]$t.State }) }
    try { Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null; return 'done' } catch { return 'denied' }
}

function Test-SystemSsd {
    try {
        $d = Get-Partition -DriveLetter ($env:SystemDrive.Substring(0, 1)) | Get-Disk | Get-PhysicalDisk
        return (@($d | Where-Object { [string]$_.MediaType -eq 'SSD' }).Count -gt 0)
    } catch { return $false }
}

$Script:Tier1 = @(
    'DiagTrack', 'dmwappushservice', 'MapsBroker', 'lfsvc', 'RetailDemo', 'WerSvc', 'PcaSvc', 'wisvc',
    'XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc', 'Fax', 'WMPNetworkSvc', 'RemoteRegistry',
    'icssvc', 'PhoneSvc', 'SmsRouter', 'WalletService', 'SEMgrSvc', 'WpcMonSvc', 'MixedRealityOpenXRSvc',
    'SharedRealitySvc', 'perceptionsimulation', 'spectrum', 'AJRouter', 'ALG', 'WFDSConMgrSvc',
    'p2pimsvc', 'p2psvc', 'PNRPsvc', 'PNRPAutoReg', 'NcdAutoSetup', 'TrkWks', 'StiSvc', 'Wecsvc', 'WinRM',
    'diagnosticshub.standardcollector.service', 'DPS', 'WdiServiceHost', 'WdiSystemHost', 'TroubleshootingSvc',
    'SSDPSRV', 'upnphost', 'FDResPub', 'fdPHost', 'CDPSvc', 'edgeupdate', 'edgeupdatem',
    'MicrosoftEdgeElevationService', 'GraphicsPerfSvc', 'WSearch',
    'CDPUserSvc', 'OneSyncSvc', 'MessagingService', 'PimIndexMaintenanceSvc', 'UnistoreSvc', 'UserDataSvc'
)
$Script:Tier2 = @(
    'wuauserv', 'UsoSvc', 'BITS', 'DoSvc', 'Spooler', 'PrintNotify', 'TermService', 'SessionEnv', 'UmRdpService',
    'LanmanServer', 'WpnUserService', 'InstallService', 'ShellHWDetection'
)
$Script:Tasks = @(
    @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
    @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
    @('\Microsoft\Windows\Application Experience\', 'PcaPatchDbTask'),
    @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
    @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
    @('\Microsoft\Windows\Customer Experience Improvement Program\', 'KernelCeipTask'),
    @('\Microsoft\Windows\Autochk\', 'Proxy'),
    @('\Microsoft\Windows\Windows Error Reporting\', 'QueueReporting'),
    @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'),
    @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
    @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload'),
    @('\Microsoft\Windows\Maps\', 'MapsToastTask'),
    @('\Microsoft\Windows\Maps\', 'MapsUpdateTask')
)

function Get-Load {
    $os = Get-CimInstance Win32_OperatingSystem
    return [pscustomobject]@{
        Proc = @(Get-Process).Count
        Svc  = @(Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
        Ram  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
    }
}

function Start-Countdown {
    param([int]$Sec = 20)
    Paint ''; Paint ('  ' + ('═' * $Script:W)) 'amber'
    Paint '   ► ' 'amber' -NoNL; Paint 'Restarting automatically so every change takes full effect' 'white'
    Paint '     Save your open work first  ·  press ' 'gray' -NoNL; Chip 'C' 'ink' 'red' -NoNL; Paint ' to cancel' 'gray'
    Paint ''
    for ($i = $Sec; $i -ge 1; $i--) {
        $w = 30; $f = [int][math]::Round($w * $i / $Sec)
        Write-Host "`r" -NoNewline
        Paint '   RESTART IN ' 'amber' -NoNL; Paint ('{0,2}s  ' -f $i) 'white' -NoNL; Paint ('█' * $f) 'amber' -NoNL; Paint ('░' * ($w - $f)) 'dim' -NoNL; Paint '   ' -NoNL
        for ($t = 0; $t -lt 10; $t++) {
            Start-Sleep -Milliseconds 100
            try { if ([Console]::KeyAvailable) { $k = [Console]::ReadKey($true); if ($k.Key -eq [ConsoleKey]::C) { Paint ''; Paint ''; Say 'Restart cancelled - restart manually to finish' 'warn'; return $false } } } catch {}
        }
    }
    Paint ''; Paint ''; Say 'Restarting...' 'ok'
    shutdown.exe /r /t 3 /f /c 'BANNARAKX NETFORGE LEAN WINDOWS : restarting' | Out-Null
    Start-Sleep -Seconds 6
    return $true
}

# ------------------------------------------------------------------ APPLY
function Start-Lean {
    param([bool]$IncludePlus)
    $Script:Ok = 0; $Script:Skip = 0; $Script:StepNo = 0
    $before = Get-Load
    Load-Bak

    Sector '1/3' 'SERVICES' 'Disable background services you do not need for gaming' 'cyan'
    $script:dis = 0; $script:already = 0; $script:denied = 0

    Step 'Core reduction list (telemetry · Xbox · peer · diagnostics ...)' {
        $names = @($Script:Tier1)
        if (Test-SystemSsd) { $names += 'SysMain' }
        foreach ($n in $names) {
            switch (Disable-Svc $n) { 'done' { $script:dis++ } 'already' { $script:already++ } 'denied' { $script:denied++ } default { } }
        }
        [void](Save-Bak)
        $Script:StepNote = ('{0} disabled now  ·  {1} already off  ·  {2} protected/denied' -f $script:dis, $script:already, $script:denied)
        return ($script:dis + $script:already -gt 0)
    }

    if ($IncludePlus) {
        Step 'PLUS list (Windows Update · Print · RDP · File sharing ...)' {
            $d2 = 0
            foreach ($n in $Script:Tier2) { if ((Disable-Svc $n) -eq 'done') { $d2++ } }
            [void](Save-Bak)
            $Script:StepNote = ('{0} more services disabled  -  Windows Update will NOT run until you restore' -f $d2)
            return $true
        }
    }

    Sector '2/3' 'TASKS + SVCHOST' 'Telemetry tasks · merge svchost processes' 'pink'

    Step 'Disable telemetry / diagnostic scheduled tasks' {
        $n = 0
        foreach ($t in $Script:Tasks) { if ((Disable-Task $t[0] $t[1]) -eq 'done') { $n++ } }
        [void](Save-Bak)
        $Script:StepNote = ('{0} tasks disabled now' -f $n)
        return $true
    }

    Step 'Merge svchost processes (SvcHostSplitThresholdInKB)' {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control'
        if (-not $Script:B['SplitSaved']) {
            $cur = (Get-ItemProperty -LiteralPath $k -Name 'SvcHostSplitThresholdInKB' -ErrorAction SilentlyContinue).SvcHostSplitThresholdInKB
            if ($null -ne $cur) { $Script:B['Split'] = [int]$cur } else { $Script:B['Split'] = $null }
            $Script:B['SplitSaved'] = $true
        }
        New-ItemProperty -LiteralPath $k -Name 'SvcHostSplitThresholdInKB' -Value 134217728 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        [void](Save-Bak)
        $Script:StepNote = 'Takes effect after restart - far fewer svchost.exe'
        return $true
    }

    Sector '3/3' 'RESULT' 'Measure again' 'lime'
    Start-Sleep -Seconds 2
    $after = Get-Load
    Paint ''
    Box-Top 'LEAN RESULT' 'lime'
    Box-Row 'PROCESSES' ('{0}  ->  {1}   (more after restart)' -f $before.Proc, $after.Proc) 'lime' 'lime'
    Box-Row 'RUNNING SERVICES' ('{0}  ->  {1}' -f $before.Svc, $after.Svc) 'lime' 'lime'
    Box-Row 'RAM IN USE' ('{0} GB  ->  {1} GB' -f $before.Ram, $after.Ram) 'white' 'lime'
    Box-Row 'MODE' $(if ($IncludePlus) { 'LEAN+  (aggressive)' } else { 'LEAN' }) 'white' 'lime'
    Box-Row 'BACKUP' $Script:Bak 'gray' 'lime'
    Box-Bottom 'lime'
    Paint ''
    Say 'Run again and choose R to restore everything.' 'dim'
    if ($NoReboot) { Say 'Auto-restart disabled (-NoReboot)' 'warn'; return $false }
    return (Start-Countdown 20)
}

# ------------------------------------------------------------------ RESTORE
function Invoke-RestoreLean {
    $Script:Ok = 0; $Script:Skip = 0; $Script:StepNo = 0
    if (-not (Test-Path -LiteralPath $Script:Bak)) { Paint ''; Say 'No backup found - nothing to restore' 'warn'; return $false }
    $d = $null
    try { $d = Get-Content -LiteralPath $Script:Bak -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ((-not $d) -or ($d.Tool -ne 'LEAN')) { Paint ''; Say 'Backup file is damaged' 'bad'; return $false }

    Sector 'R' 'RESTORE' 'Return services, tasks and svchost to the saved state' 'amber'
    Step 'Services' {
        $n = 0
        foreach ($s in @($d.Services)) {
            if (-not $s) { continue }
            $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + [string]$s.Name
            if (-not (Test-Path -LiteralPath $k)) { continue }
            try {
                Set-ItemProperty -LiteralPath $k -Name 'Start' -Value ([int]$s.Start) -Type DWord -ErrorAction Stop
                if ($null -ne $s.Delayed) { Set-ItemProperty -LiteralPath $k -Name 'DelayedAutostart' -Value ([int]$s.Delayed) -Type DWord -ErrorAction SilentlyContinue }
                $n++
            } catch {}
        }
        $Script:StepNote = ('{0} services restored' -f $n)
        return ($n -gt 0)
    }
    Step 'Scheduled tasks' {
        $n = 0
        foreach ($t in @($d.Tasks)) {
            if (-not $t) { continue }
            if ([string]$t.State -ne 'Disabled') { try { Enable-ScheduledTask -TaskPath ([string]$t.Path) -TaskName ([string]$t.Name) -ErrorAction Stop | Out-Null; $n++ } catch {} }
        }
        $Script:StepNote = ('{0} tasks re-enabled' -f $n)
        return $true
    }
    Step 'svchost threshold' {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control'
        if ($d.SplitSaved) {
            if ($null -ne $d.Split) { New-ItemProperty -LiteralPath $k -Name 'SvcHostSplitThresholdInKB' -Value ([int]$d.Split) -PropertyType DWord -Force | Out-Null }
            else { Remove-ItemProperty -LiteralPath $k -Name 'SvcHostSplitThresholdInKB' -Force -ErrorAction SilentlyContinue }
        }
        return $true
    }
    try { Move-Item -LiteralPath $Script:Bak -Destination (Join-Path $Script:Root ('lean_backup.restored.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.json')) -Force } catch {}
    Paint ''
    Box-Top 'RESTORED' 'amber'
    Box-Row 'STEPS' ('{0} OK  ·  {1} skipped' -f $Script:Ok, $Script:Skip) 'white' 'amber'
    Box-Bottom 'amber'
    if ($NoReboot) { Say 'Auto-restart disabled (-NoReboot)' 'warn'; return $false }
    return (Start-Countdown 15)
}

# ------------------------------------------------------------------ START
Show-Banner
$choice = 'S'
if ($Restore) { $choice = 'R' }
elseif (-not $Auto) {
    Box-Top 'CHOOSE MODE'
    Box-Row 'LEAN' 'telemetry, Xbox, peer, diagnostics, search, tasks, svchost merge' 'white'
    Box-Row 'LEAN+' 'LEAN + stops Windows Update, printing, RDP, file sharing' 'amber'
    Box-Row 'RESTORE' 'put everything back from the saved backup' 'gray'
    Box-Bottom
    Paint ''
    Paint '   ' -NoNL; Chip '  1  ' 'ink' 'lime' -NoNL; Paint '  LEAN  (recommended)' 'white'
    Paint '   ' -NoNL; Chip '  2  ' 'ink' 'amber' -NoNL; Paint '  LEAN+  (aggressive)' 'gray'
    Paint '   ' -NoNL; Chip '  R  ' 'ink' 'pink' -NoNL; Paint '  RESTORE' 'gray'
    Paint '   ' -NoNL; Chip '  Q  ' 'ink' 'red' -NoNL; Paint '  QUIT' 'gray'
    Paint ''
    Paint '   ► ' 'cyan' -NoNL
    $a = Read-Host
    if ($a -match '^[Rr]') { $choice = 'R' } elseif ($a -match '^[Qq]') { $choice = 'Q' } elseif ($a -match '^2') { $choice = 'P' } else { $choice = 'S' }
} elseif ($Plus) { $choice = 'P' }

$rebooted = $false
switch ($choice) {
    'S' { $rebooted = Start-Lean $false }
    'P' { $rebooted = Start-Lean $true }
    'R' { $rebooted = Invoke-RestoreLean }
    default { }
}
if ($rebooted) { exit }
Paint ''
if ($choice -eq 'Q') { Say 'Bye' 'dim' } else { Paint '   ' -NoNL; Chip 'ENTER' 'ink' 'dim' -NoNL; Paint ' CLOSE' 'dim'; Read-Host | Out-Null }
