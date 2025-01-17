Try {
    # Name Prefix
    $namePrefix = 'ENB-'

    # Get device information, removes non alphabet characters, sets to uppercase.
    $deviceDetails = Get-ComputerInfo
    $deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
    $deviceName = $namePrefix + $deviceSerial

    If ($deviceDetails.CsName -ne $deviceName) {
        Write-Warning "Existing Computer name $($deviceDetails.CsName) should be $deviceName"
        Exit 1
    }
    Else {
        Write-Output "Computer has correct name: $deviceName"
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}