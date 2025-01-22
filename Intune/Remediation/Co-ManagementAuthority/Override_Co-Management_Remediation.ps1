Try {
    $Registry = 'HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP\Provider\MS DM Server'
    $Path = Test-Path $Registry
    $Authority = Get-ItemPropertyValue -Path $Registry -Name ConfigInfo -ErrorAction SilentlyContinue

    if ($Path -eq $false) {
        New-Item -Path $Registry -Force | Out-Null
        New-ItemProperty -Path $Registry -Name ConfigInfo -Value 1 -PropertyType String -Force
    }
    else {
        if ($Authority -ne '1') {
            New-ItemProperty -Path $Registry -Name ConfigInfo -Value 1 -PropertyType String -Force
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}