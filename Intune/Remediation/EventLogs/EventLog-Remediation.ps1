$logs = @()
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/EXE and DLL'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/MSI and Script'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Deployment'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Execution'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-CodeIntegrity/Operational'; Size = 10MB }

try {s
    foreach ($log in $logs) {
        $eventLog = Get-WinEvent -ListLog $log.Name -ErrorAction SilentlyContinue
        if ($eventLog) {
            if ($eventLog.MaximumSizeInBytes -ne $log.Size) {
                $eventLog.MaximumSizeInBytes = $log.Size
                $eventLog.SaveChanges()
                Write-Output "Remediated event log $($log.Name) to size $($log.Size)."
            }
        }
        else {
            continue
        }
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 2000
}