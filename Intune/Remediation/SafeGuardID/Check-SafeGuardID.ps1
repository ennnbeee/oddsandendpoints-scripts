#$featureUpdate = 'GE25H2' # Windows 11 25H2
$featureUpdate = 'GE24H2' # Windows 11 24H2
#$featureUpdate = 'NI23H2' # Windows 11 23H2

try {
    $registry = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators\$featureUpdate"
    try {
        $safeGuardId = Get-ItemPropertyValue -Path $registry -Name GatedBlockId -ErrorAction SilentlyContinue
        $safeGuardReason = Get-ItemPropertyValue -Path $registry -Name GatedBlockReason -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "App Compat not run for Windows 11 $featureUpdate"
        exit 0
    }

    if ($safeGuardId -eq 'None' -or $null -eq $safeGuardId) {
        Write-Output "No SafeGuard hold found for Windows 11 $featureUpdate"
        exit 0
    }
    else {
        Write-Output "SafeGuard ID $safeGuardId reason $safeGuardReason for Windows 11 $featureUpdate"
        exit 1
    }
}
catch {
    Write-Error $_.Exception
    exit 2000
}