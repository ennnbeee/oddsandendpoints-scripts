$domain = 'ennbee.local'
$waitTime = '60'

Try {

    $dcInfo = [ADSI]"LDAP://$domain"
    if ($null -eq $dcInfo.Path) {
        Write-Error "No connectivity to $domain"
    }

    $serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
    If (Get-WmiObject -Class win32_battery) {
        $newName = 'L-' + $serial
    }
    Else {
        $newName = 'D-' + $serial
    }

    $newName = $newName.Replace(' ', '')
    if ($newName.Length -ge 15) {
        $newName = $newName.substring(0, 15)
    }

    Rename-Computer -NewName $newName
    $waitSeconds = (New-TimeSpan -Minutes $waitTime).TotalSeconds
    Write-Host "Initiating a restart in $waitime minutes"
    & shutdown.exe /g /t $waitSeconds /f /c "Restarting your computer in $waitTime minutes due to a computer name change. Please save your work."
    Write-Output "Computer renamed from $($details.CsName) to $newName"
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}