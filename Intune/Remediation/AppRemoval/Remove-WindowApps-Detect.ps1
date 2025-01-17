$appNames = @(
    'Microsoft.OutlookForWindows'
    'MicrosoftTeams'
    'Microsoft.BingNews'
    'Clipchamp.Clipchamp'
    'Microsoft.Copilot'
)

Try {
    $appInstalled = 0
    foreach ($appName in $appNames) {
        If ($null -ne (Get-AppxPackage -Name $appName -AllUsers)) {
            $appInstalled++
        }
    }

    if ($appInstalled -ne 0) {
        Write-Warning "Found $appInstalled installed of $($appNames.Count) to be removed"
        Exit 1
    }
    else {
        Write-Output "All $($appNames.Count) apps removed."
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}


