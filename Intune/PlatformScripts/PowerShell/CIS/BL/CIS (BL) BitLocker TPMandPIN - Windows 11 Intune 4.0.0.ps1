$transcriptPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs" # log file location
$transcriptName = 'BitLockerTPMandPIN.log' # log file name
New-Item $transcriptPath -ItemType Directory -Force

# Stops orphaned transcripts
try {
    Stop-Transcript | Out-Null
}
catch [System.InvalidOperationException]
{}

Start-Transcript -Path $transcriptPath\$transcriptName -Append

Try {
    $osVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }

    # Detects and removes existing TpmPin key protectors as there can only be one
    if ($osVolume.KeyProtector.KeyProtectorType -contains 'TpmPin') {
        Write-Output "Existing TpmPin key protector found, removing it."
        $osVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' } | ForEach-Object {
            Remove-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
        }
    }

    # Detects and removes existing Tpm key protectors to ensure the PIN is required
    if ($osVolume.KeyProtector.KeyProtectorType -contains 'Tpm') {
        Write-Output "Existing Tpm key protector found, removing it."
        $osVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' } | ForEach-Object {
            Remove-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
        }
    }

    # Sets a recovery password key protector if one doesn't exist, needed for TpmPin key protector
    if ($osVolume.KeyProtector.KeyProtectorType -notcontains 'RecoveryPassword') {
        Write-Output "No RecoveryPassword key protector found, adding one."
        Enable-BitLocker -MountPoint $osVolume.MountPoint -RecoveryPasswordProtector
    }

    # Configures the PIN and Enables BitLocker using the TpmPin key protector
    $deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
    If ($deviceSerial.length -gt 14) {
        $deviceSerial = $deviceSerial.Substring(0, 14) # Reduce to 14 characters if longer
    }

    $devicePIN = ConvertTo-SecureString $deviceSerial -AsPlainText -Force
    Write-Output "Configuring BitLocker with TPM and PIN protector."
    Enable-BitLocker -MountPoint $osVolume.MountPoint -Pin $devicePIN -TpmAndPinProtector -ErrorAction SilentlyContinue | Out-Null

    # Gets the recovery key and escrows to Entra
    (Get-BitLockerVolume).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | ForEach-Object {
        Write-Output "Escrowing Recovery Password to Azure AD."
        BackupToAAD-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
    }
    Stop-Transcript
    Exit 0
}
Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Warning $ErrorMessage
    Stop-Transcript
    Exit 1
}