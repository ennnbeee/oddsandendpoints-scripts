$appName = 'MicrosoftTeams'
If ($null -eq (Get-AppxPackage -Name $appName -AllUsers)) {
    Write-Output "$appName not installed"
    Exit 0
}
Else {
    Write-Output "$appName installed"
    Exit 1
}