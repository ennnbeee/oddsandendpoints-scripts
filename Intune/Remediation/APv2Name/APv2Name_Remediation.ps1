# Name Prefix
$namePrefix = 'ENB-'
$restartTimeMins = '60'

# Get device information, removes non alphabet characters, sets to uppercase.
$deviceDetails = Get-ComputerInfo
$deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
$deviceName = $namePrefix + $deviceSerial

# Shortens device name
if ($deviceName.Length -ge 15) {
    $deviceName = $deviceName.substring(0, 15)
}

try {
    Rename-Computer -NewName $deviceName
    # If in OOBE force restart
    if ($deviceDetails.CsUserName -match 'defaultUser') {
        Exit 1641
    }
    else {
        $restartTimeSecs = (New-TimeSpan -Minutes $restartTimeMins).TotalSeconds
        & shutdown.exe /g /t $restartTimeSecs /f /c "Restarting your computer in $restartTimeMins minutes due to a computer name change. Please save your work."
        Exit 0
    }
}
catch {
    Write-Error $_.Exception
    Exit 2000
}