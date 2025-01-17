Try {
    $registry = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    $path = Test-Path $registry
    # checks if the key exists, if not creates the key and ForceDefenderPassiveMode dword.
    if ($path -eq $false) {
        New-Item -Path $registry -Force | Out-Null
        New-ItemProperty -Path $registry -Name ForceDefenderPassiveMode -Value 0 -PropertyType String -Force | Out-Null
        Write-Output 'Defender is in Active Mode.'
        Exit 0
    }
    else {
        # checks if the ForceDefenderPassiveMode dword exists, if not creates it.
        Try {
            # if the ForceDefenderPassiveMode dword exists updates it.
            Get-ItemPropertyValue -Path $registry -Name ForceDefenderPassiveMode
            Set-ItemProperty -Path $registry -Name ForceDefenderPassiveMode -Value 0
            Write-Output 'Defender is in Active Mode.'
            Exit 0
        }
        Catch {
            New-ItemProperty -Path $registry -Name ForceDefenderPassiveMode -Value 0 -PropertyType DWord -Force | Out-Null
            Write-Output 'Defender is in Active Mode.'
            Exit 0
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}