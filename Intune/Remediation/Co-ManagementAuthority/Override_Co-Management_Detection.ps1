Try {
    $Registry = 'HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server'
    $Path = Test-Path $Registry
    $Authority = Get-ItemPropertyValue -Path $Registry -Name ConfigInfo -ErrorAction SilentlyContinue

    if ($Path -eq $False) {
        Write-Warning 'Co-Management Authority Not Confgured'
        Exit 1
    }
    else {
        if ($Authority -ne '1') {
            Write-Warning 'Co-Management Authority set to Configuration Manager'
            Exit 1
        }
        else {
            Write-Output 'Co-Management Authority set to Intune'
            Exit 0
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}

