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

Write-Output "`n=== DISPLAY & GPU ROUTING ==="
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
$procs = Get-CimInstance Win32_Process
Write-Output "Total Processes: $($procs.Count)"
$procs | Group-Object Name | ForEach-Object {
    [PSCustomObject]@{
        Name  = $_.Name
        Count = $_.Count
        RamMB = [math]::Round((($_.Group | Measure-Object WorkingSetSize -Sum).Sum) / 1MB, 1)
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
