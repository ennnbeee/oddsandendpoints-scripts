Try {
    $osVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }

    # Detects and removes existing TpmPin key protectors as there can only be one
    if ($osVolume.KeyProtector.KeyProtectorType -contains 'TpmPin') {
        $osVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' } | ForEach-Object {
            Remove-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
        }
    }

    # Detects and removes existing Tpm key protectors to ensure the PIN is required
    if ($osVolume.KeyProtector.KeyProtectorType -contains 'Tpm') {
        $osVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' } | ForEach-Object {
            Remove-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
        }
    }

    # Sets a recovery password key protector if one doesn't exist, needed for TpmPin key protector
    if ($osVolume.KeyProtector.KeyProtectorType -notcontains 'RecoveryPassword') {
        Enable-BitLocker -MountPoint $osVolume.MountPoint -RecoveryPasswordProtector
    }

    # Configures the PIN and Enables BitLocker using the TpmPin key protector
    $deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
    If ($deviceSerial.length -gt 14) {
        $deviceSerial = $deviceSerial.Substring(0, 14) # Reduce to 14 characters if longer
    }

    $devicePIN = ConvertTo-SecureString $deviceSerial -AsPlainText -Force
    Enable-BitLocker -MountPoint $osVolume.MountPoint -Pin $devicePIN -TpmAndPinProtector -ErrorAction SilentlyContinue | Out-Null

    # Gets the recovery key and escrows to Entra
    (Get-BitLockerVolume).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | ForEach-Object {
        BackupToAAD-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
    }
    Exit 0
}
Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Warning $ErrorMessage
    Exit 1
}