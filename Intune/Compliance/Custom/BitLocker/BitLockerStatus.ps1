# compliance output object
$bitlockerCompliance = New-Object -TypeName PSObject

# checking if BitLocker is enabled
$encryptionStatus = (Get-BitLockerVolume -MountPoint $ENV:SystemDrive | Select-Object -ExpandProperty VolumeStatus)

# bitlocker disabled
if ($encryptionStatus -ne 'FullyEncrypted') {
    [string]$encryptionStatus = 'Decrypted'
    [string]$encryptionMethod = 'Decrypted'
    [string]$encryptionAlgorithm = 'Decrypted'
    [Int64]$encryptionPercentage = 0
}
# bitlocker enabled
else {
    [string]$encryptionStatus = 'Encrypted'
    $encryptionMethodValue = (manage-bde $ENV:SystemDrive -status)[8]
    If ($encryptionMethodValue -like '*Used Space Only Encrypted*') {
        [string]$encryptionMethod = 'Used Space Encryption'
    }
    else {
        [string]$encryptionMethod = 'Full Disk Encryption'
    }
    [string]$encryptionAlgorithm = (Get-BitLockerVolume -MountPoint $ENV:SystemDrive | Select-Object -ExpandProperty EncryptionMethod)
    [Int64]$encryptionPercentage = (Get-BitLockerVolume -MountPoint $ENV:SystemDrive).EncryptionPercentage
}

# build the output object
$bitlockerCompliance | Add-Member -MemberType NoteProperty -Name 'Encryption Status' -Value $encryptionStatus
$bitlockerCompliance | Add-Member -MemberType NoteProperty -Name 'Encryption Method' -Value $encryptionMethod
$bitlockerCompliance | Add-Member -MemberType NoteProperty -Name 'Encryption Algorithm' -Value $encryptionAlgorithm
$bitlockerCompliance | Add-Member -MemberType NoteProperty -Name 'Encryption Percentage' -Value $encryptionPercentage

# return the output object
return $bitlockerCompliance | ConvertTo-Json -Compress