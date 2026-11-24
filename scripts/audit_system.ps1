$ErrorActionPreference = 'SilentlyContinue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$os = Get-CimInstance Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build
$winGen = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
$uptime = (Get-Date) - $os.LastBootUpTime
$totalRam = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRam = [math]::Round($totalRam - $freeRam, 2)
$usedPct = [math]::Round(($usedRam / $totalRam) * 100, 1)

Write-Output "=== SYSTEM OVERVIEW ==="
Write-Output "OS: $($os.Caption) ($winGen, Build $build) | IsAdmin: $isAdmin"
Write-Output "Uptime: $([math]::Round($uptime.TotalHours, 1)) hours (LastBoot: $($os.LastBootUpTime))"
Write-Output "RAM: $usedRam / $totalRam GB ($usedPct%)"
Write-Output "Power Plan: $(powercfg /getactivescheme)"

Write-Output "`n=== CPU & PERFORMANCE STATE ==="
Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage, CurrentClockSpeed, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors | Format-List
$hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode).HwSchMode
$gm   = (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name AutoGameModeEnabled).AutoGameModeEnabled
$hvci = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name Enabled).Enabled
$devM = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense).AllowDevelopmentWithoutDevLicense
Write-Output "HAGS (HwSchMode): $(if ($null -eq $hags) {'Not Set'} else {$hags}) | GameMode: $(if ($null -eq $gm) {'Default'} else {$gm}) | HVCI: $(if ($null -eq $hvci) {'Not Set'} else {$hvci}) | DevMode: $(if ($null -eq $devM) {'0'} else {$devM})"
Write-Output "NTFS Trim/LastAccess: $((fsutil behavior query DisableDeleteNotify) -join '; ') | $(fsutil behavior query disablelastaccess)"
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize

Write-Output "=== DISPLAY & GPU ROUTING ==="
Get-CimInstance Win32_VideoController | Select-Object Name, VideoModeDescription, CurrentRefreshRate, DriverVersion | Format-Table -AutoSize

Write-Output "=== WIDGETS / FEEDS POLICY CHECK ==="
if ($build -ge 22000) {
    $dsh = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name AllowNewsAndInterests).AllowNewsAndInterests
    Write-Output "AllowNewsAndInterests (Win11 Widgets): $(if ($null -eq $dsh) { 'Not Set (Enabled)' } else { $dsh })"
} else {
    $feeds = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name EnableFeeds).EnableFeeds
    Write-Output "EnableFeeds (Win10 News): $(if ($null -eq $feeds) { 'Not Set (Enabled)' } else { $feeds })"
}

Write-Output "`n=== KNOWN FOLDERS (ONEDRIVE SAFETY CHECK) ==="
$usf = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
foreach ($prop in @("Desktop", "Personal", "My Pictures")) {
    $val = $usf.$prop
    $warn = if ($val -match 'OneDrive') { " [WARNING: Redirected to OneDrive!]" } else { "" }
    Write-Output "$prop : $val$warn"
}

Write-Output "`n=== TOP RUNNING APPS (BY RAM) ==="
$p1 = Get-Process | Select-Object Id, ProcessName, CPU
Start-Sleep -Seconds 2
$p2 = Get-Process | Select-Object Id, ProcessName, CPU
$cpuMap = @{}
foreach ($p in $p2) {
    $prev = $p1 | Where-Object { $_.Id -eq $p.Id }
    if ($prev -and $null -ne $p.CPU -and $null -ne $prev.CPU) {
        $delta = ($p.CPU - $prev.CPU) / 2.0 / [Environment]::ProcessorCount * 100.0
        if (-not $cpuMap.ContainsKey($p.ProcessName)) { $cpuMap[$p.ProcessName] = 0.0 }
        $cpuMap[$p.ProcessName] += $delta
    }
}
$procs = Get-CimInstance Win32_Process
Write-Output "Total Processes: $($procs.Count)"
$procs | Group-Object Name | ForEach-Object {
    $base = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $cpuPct = if ($cpuMap.ContainsKey($base)) { [math]::Round($cpuMap[$base], 1) } else { 0 }
    [PSCustomObject]@{
        Name   = $_.Name
        Count  = $_.Count
        RamMB  = [math]::Round((($_.Group | Measure-Object WorkingSetSize -Sum).Sum) / 1MB, 1)
        CpuPct = $cpuPct
    }
} | Sort-Object RamMB -Descending | Select-Object -First 20 | Format-Table -AutoSize

Write-Output "=== STARTUP LAYER 1: REGISTRY RUN ==="
function Get-StartupApprovedMap($regPath) {
    $map = @{}
    if (Test-Path $regPath) {
        $props = Get-ItemProperty $regPath
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -notlike 'PS*' -and $p.Value -is [byte[]] -and $p.Value.Length -ge 1) {
                # First byte: 2 or 6 = Enabled, 3 or odd = Disabled in Task Manager
                $map[$p.Name] = if (($p.Value[0] % 2) -eq 1) { "Disabled in TaskMgr" } else { "Enabled" }
            }
        }
    }
    return $map
}
$hkcuApproved = Get-StartupApprovedMap "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$hklmApproved = Get-StartupApprovedMap "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$wowApproved  = Get-StartupApprovedMap "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"

function Show-RunKey($label, $regPath, $approvedMap) {
    Write-Output "-- $label --"
    $item = Get-ItemProperty $regPath
    if ($item) {
        foreach ($p in $item.PSObject.Properties) {
            if ($p.Name -notlike 'PS*') {
                $st = if ($approvedMap.ContainsKey($p.Name)) { $approvedMap[$p.Name] } else { "Enabled" }
                Write-Output "$($p.Name) [$st] : $($p.Value)"
            }
        }
    }
}

Show-RunKey "HKCU Run" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" $hkcuApproved
Show-RunKey "HKLM Run" "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" $hklmApproved
Show-RunKey "HKLM WOW6432Node Run" "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" $wowApproved

Write-Output "=== STARTUP LAYER 2: STARTUP FOLDERS ==="
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" | Select-Object Name
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" | Select-Object Name

Write-Output "=== STARTUP LAYER 3: STORE APPS (State=2 Enabled) ==="
Get-ChildItem "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData" | ForEach-Object {
    $pkg = $_.PSChildName
    Get-ChildItem $_.PSPath | ForEach-Object {
        $st = (Get-ItemProperty $_.PSPath -Name State).State
        if ($st -eq 2) { Write-Output "$pkg | $($_.PSChildName) | State=$st" }
    }
}

Write-Output "`n=== STARTUP LAYER 4: NON-WINDOWS & TELEMETRY SCHEDULED TASKS (Enabled/Running) ==="
Get-ScheduledTask | Where-Object {
    $_.State -ne 'Disabled' -and (
        $_.TaskPath -notlike "\Microsoft\Windows\*" -or
        $_.TaskName -match 'Compatibility Appraiser|Consolidator|UsbCeip|SustainabilityTelemetry|MapsToastTask|ShowFeedbackToast'
    )
} | Select-Object TaskName, TaskPath, State | Format-Table -AutoSize

Write-Output "=== STARTUP LAYER 5: 3RD-PARTY AUTOMATIC SERVICES ==="
Get-CimInstance Win32_Service -Filter "StartMode='Auto'" |
    Where-Object { $_.PathName -and -not $_.PathName.Trim('"').ToLowerInvariant().StartsWith('c:\windows\') } |
    ForEach-Object {
        $exe = $_.PathName.Trim()
        if ($exe.StartsWith('"')) {
            $exe = ($exe -split '"')[1]
        } else {
            $exe = ($exe -split '\s+(?=-|/)')[0]
            if (-not (Test-Path $exe) -and $exe -match '^(.+?\.exe)\b') { $exe = $Matches[1] }
        }
        $missing = if ($exe -and -not (Test-Path $exe)) { "YES (Orphaned)" } else { "No" }
        $msix    = if ($_.PathName -match '\\WindowsApps\\') { "Yes" } else { "No" }
        [PSCustomObject]@{ Name = $_.Name; State = $_.State; MissingBinary = $missing; MsixProtected = $msix; DisplayName = $_.DisplayName }
    } | Format-Table -AutoSize -Wrap

Write-Output "=== TARGETED CHECKS (MICROSOFT / CHROME / VENDOR / GAMING) ==="
$svcTargets = @(
    @{ Name = 'DiagTrack'; Role = 'MS Telemetry (Safe to disable)' },
    @{ Name = 'MapsBroker'; Role = 'MS Offline Maps (Safe if unused)' },
    @{ Name = 'lfsvc'; Role = 'MS Geolocation (Safe if unused)' },
    @{ Name = 'WSearch'; Role = 'Windows Search Indexer (Keep if using Start/Explorer search)' },
    @{ Name = 'edgeupdate'; Role = 'Edge Background Updater (Safe to set Manual)' },
    @{ Name = 'ClickToRunSvc'; Role = 'Office Click-to-Run (Safe to set Manual)' },
    @{ Name = 'GamingServices'; Role = 'Gaming: Xbox/Game Pass (Keep if playing Game Pass/MS Store games)' },
    @{ Name = 'GamingServicesNet'; Role = 'Gaming: Xbox/Game Pass Net (Keep if playing Game Pass/MS Store games)' },
    @{ Name = 'XboxService'; Role = 'Gaming: Xbox Input/App (Keep if Game Pass; safe to Manual if Steam-only)' },
    @{ Name = 'GameInputRedistService'; Role = 'Gaming: Controller Input (Keep if using gamepads/controllers)' },
    @{ Name = 'OptionsPlusUpdaterService'; Role = 'Logitech Options+ Updater (Keep if using custom mouse profiles)' }
)
$svcCheck = foreach ($t in $svcTargets) {
    $s = Get-Service -Name $t.Name -ErrorAction SilentlyContinue
    if ($s) {
        [PSCustomObject]@{ Service = $s.Name; Status = $s.Status; StartType = $s.StartType; Guidance = $t.Role }
    }
}
$svcCheck | Format-Table -AutoSize -Wrap

Write-Output "-- Targeted Process Presence (Browsers / Widgets / Gaming / Updaters) --"
$procPattern = '^(chrome|msedge|msedgewebview2|WidgetService|MicrosoftStartFeedProvider|OneDrive|GoogleUpdate|GoogleUpdater|gamingservices|XboxService|GameInputRedistService|vgc|EasyAntiCheat)'
$procs | Where-Object { $_.Name -match $procPattern } | Group-Object Name | ForEach-Object {
    [PSCustomObject]@{
        Process = $_.Name
        Count   = $_.Count
        RamMB   = [math]::Round((($_.Group | Measure-Object WorkingSetSize -Sum).Sum) / 1MB, 1)
    }
} | Sort-Object RamMB -Descending | Format-Table -AutoSize
