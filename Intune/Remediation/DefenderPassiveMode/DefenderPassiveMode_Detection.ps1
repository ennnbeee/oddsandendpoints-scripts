Try {
    $registry = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    # Checks if the key and ForceDefenderPassiveMode dword exist.
    Try {
        $passiveMode = Get-ItemPropertyValue -Path $registry -Name ForceDefenderPassiveMode
    }
    Catch {
        Write-Warning 'Defender Passive Mode settings not configured.'
        Exit 1
    }

    # if the key and dword exist checks the value.
    if ($passiveMode -ne '0') {
        Write-Warning 'Defender is in Passive Mode.'
        Exit 1
    }
    else {
        Write-Output 'Defender is in Active Mode.'
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}