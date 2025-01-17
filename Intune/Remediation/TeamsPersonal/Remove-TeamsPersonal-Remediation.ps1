$appName = 'MicrosoftTeams'
if ($null -eq (Get-AppxPackage -Name $appName -AllUsers)) {
    Write-Output "$appName not installed"
    Exit 0
}
else {
    try {
        Write-Output "Removing $appName"
        if (Get-Process msteams -ErrorAction SilentlyContinue) {
            try {
                Write-Output 'Stopping Microsoft Teams Personal app process'
                Stop-Process msteams -Force Write-Output 'Stopped'
            }
            catch {
                Write-Output 'Unable to stop process, trying to remove anyway'
            }
        }
        Get-AppxPackage -Name $appName -AllUsers | Remove-AppPackage -AllUsers
        Write-Output "$appName removed successfully"
    }
    catch {
        Write-Error "Error removing $appName"
        Exit 2000
    }
}