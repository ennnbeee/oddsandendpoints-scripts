$appNames = @(
    'Microsoft.OutlookForWindows'
    'MicrosoftTeams'
    'Microsoft.BingNews'
    'Clipchamp.Clipchamp'
    'Microsoft.Copilot'
)
Try {
    foreach ($appName in $appNames) {
        If ($null -ne (Get-AppxPackage -Name $appName -AllUsers)) {
            Get-AppxPackage -Name $appName -AllUsers | Remove-AppPackage -AllUsers
        }
    }
    Write-Output "All $($appNames.Count) apps removed"
    Exit 0
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}