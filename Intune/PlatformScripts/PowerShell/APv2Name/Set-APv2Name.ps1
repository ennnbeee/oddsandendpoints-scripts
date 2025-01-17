# Name Prefix
$namePrefix = 'ENB-'

# Get device information, removes non alphabet characters, sets to uppercase.
$deviceDetails = Get-ComputerInfo
$deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
$deviceName = $namePrefix + $deviceSerial

# Shortens device name
if ($deviceName.Length -ge 15) {
    $deviceName = $deviceName.substring(0, 15)
}

if ($deviceDetails.CsName -ne $deviceName) {
    try {
        Rename-Computer -NewName $deviceName
        Exit 1641
    }
    catch {
        Exit 1
    }
}
else {
    Exit 0
}