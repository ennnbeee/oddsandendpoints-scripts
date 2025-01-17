Try {
    $details = Get-ComputerInfo
    if (-not $details.CsPartOfDomain) {
        Write-Output 'Not Domain Joined'
        Exit 0
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

    If ($details.CsName -ne $newName) {
        Write-Warning "Existing Computer name $($details.CsName) should be $newName"
        Exit 1
    }
    Else {
        Write-Output "Computer has correct name: $($details.CsName)"
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}

