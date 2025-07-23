#$featureUpdate = 'GE25H2' # Windows 11 25H2
$featureUpdate = 'GE24H2' # Windows 11 24H2
#$featureUpdate = 'NI23H2' # Windows 11 23H2

try {
    $registry = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators\$featureUpdate"
    # Checks if the key exists and the last run of the App Compat
    try {
        $safeGuardId = Get-ItemPropertyValue -Path $registry -Name GatedBlockId -ErrorAction SilentlyContinue
        $safeGuardReason = Get-ItemPropertyValue -Path $registry -Name GatedBlockReason -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "App Compat not run for Windows 11 $featureUpdate"
        exit 0
    }

    if ($safeGuardId -ne 'None') {
        Write-Output "SafeGuard ID $safeGuardId with $safeGuardReason for Windows 11 $featureUpdate"
    }
    else {
        Write-Output "No SafeGuard ID found for Windows 11 $featureUpdate"
    }
    exit 0
}
catch {
    Write-Error $_.Exception
    exit 2000
}