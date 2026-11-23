$ErrorActionPreference = 'SilentlyContinue'

Write-Output "=== HARDWARE & BIOS ==="
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model | Format-Table -AutoSize
$bios = Get-CimInstance Win32_BIOS
$bios | Select-Object SMBIOSBIOSVersion, @{N='ReleaseDate';E={if($_.ReleaseDate){$_.ReleaseDate.ToString('yyyy-MM-dd')}}} | Format-Table -AutoSize
if ($bios.ReleaseDate -and $bios.ReleaseDate -lt (Get-Date).AddDays(-365)) {
    $ageDays = [int]((Get-Date) - $bios.ReleaseDate).TotalDays
    Write-Output "[ADVISORY] BIOS is $ageDays days old ($($bios.ReleaseDate.ToString('yyyy-MM-dd'))); check vendor support for newer microcode/BIOS updates."
}

Write-Output "`n=== DEVICES WITH DRIVER ERRORS ==="
$errDevs = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
if ($errDevs) {
    $errDevs | Select-Object Name, PNPClass, ConfigManagerErrorCode | Format-Table -AutoSize
} else {
    Write-Output "None (all PnP devices report ConfigManagerErrorCode = 0)"
}

Write-Output "=== KEY SIGNED DRIVERS ==="
Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceClass -in @('DISPLAY', 'NET', 'MEDIA', 'SCSIAdapter', 'Bluetooth') -and
    $_.DriverVersion -and
    $_.DeviceName -notmatch '^WAN Miniport|^Microsoft Kernel|^Microsoft Wi-Fi|^Bluetooth Device \(Personal|^Generic '
} | Select-Object DeviceClass, DeviceName, DriverVersion, @{N='Date';E={if($_.DriverDate){$_.DriverDate.ToString('yyyy-MM-dd')}}} |
    Sort-Object DeviceClass, DeviceName, DriverVersion -Unique | Format-Table -AutoSize

Write-Output "=== WINDOWS UPDATE PENDING DRIVERS ==="
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $res = $searcher.Search("IsInstalled=0 and Type='Driver'")
    Write-Output "Pending Windows Update Drivers: $($res.Updates.Count)"
    foreach ($u in $res.Updates) {
        Write-Output "- $($u.Title)"
    }
} catch {
    Write-Output "Windows Update driver search failed: $_"
}
