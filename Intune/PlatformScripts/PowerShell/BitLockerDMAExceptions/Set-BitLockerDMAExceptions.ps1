# Allow for silent and automatic BitLocker Encryption
# https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-bitlocker#un-allowed-dma-capable-busdevices-detected

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses'
$dmaDevices = @()

$devicesLenovo = @('20UACTO1WW', '20KG0005AU')
$devicesDell = @('Latitude 7320','Latitude 5320')
$devicesHP = @('HP EliteBook 8540p')

Try {

    $deviceModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model

    if ($deviceModel -in $devicesDell) {
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) LPC Controller - 519D'; value = 'PCI\VEN_8086&DEV_519D'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #10 - 51B1'; value = 'PCI\VEN_8086&DEV_51B1'}
    }
    elseif ($deviceModel -in $devicesLenovo) {
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #20 - A343'; value = 'PCI\VEN_8086&DEV_A343'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #9 - A330'; value = 'PCI\VEN_8086&DEV_A330'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) Xeon(R) E3 - 1200/1500 v5/6th Gen Intel(R) Core(TM) PCIe Controller (x16) - 1901'; value = 'PCI\VEN_8086&DEV_1901'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #15 - A336'; value = 'PCI\VEN_8086&DEV_A336'}
    }
    elseif ($deviceModel -in $devicesHP ){
        $dmaDevices += [pscustomobject]@{name = 'PCI Express Upstream Switch Port - 15EF'; value = 'PCI\VEN_8086&DEV_15EF'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #17 - A340'; value = 'PCI\VEN_8086&DEV_A340'}
    }

    foreach ($dmaDevice in $dmaDevices) {
        New-ItemProperty -Path $regPath -Name $dmaDevice.name -Value $dmaDevice.value -PropertyType String -Force
    }
    Exit 0

}
Catch {
    Write-Error $_.ErrorDetails
    Exit 1
}