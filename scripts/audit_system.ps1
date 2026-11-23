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
Write-Output "-- HKCU Run --"
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Format-List
Write-Output "-- HKLM Run --"
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object * -ExcludeProperty PS* | Format-List

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

Write-Output "`n=== STARTUP LAYER 4: NON-WINDOWS SCHEDULED TASKS (Enabled/Running) ==="
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft\Windows\*" -and $_.State -ne 'Disabled' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize

Write-Output "=== STARTUP LAYER 5: 3RD-PARTY AUTOMATIC SERVICES ==="
Get-CimInstance Win32_Service -Filter "StartMode='Auto'" |
    Where-Object { $_.PathName -and -not $_.PathName.Trim('"').ToLowerInvariant().StartsWith('c:\windows\') } |
    Select-Object Name, DisplayName, State | Format-Table -AutoSize
