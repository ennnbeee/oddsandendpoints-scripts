
Try {
    $productKey = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'
    $licenseParam = @{
        ClassName = 'SoftwareLicensingProduct'
        Filter    = 'PartialProductKey is not null AND name like "windows%" AND LicenseStatus <>1'
    }
    $license = Get-CimInstance @licenseParam
    Get-CimInstance -ClassName SoftwareLicensingService | Invoke-CimMethod -MethodName InstallProductKey @{ ProductKey = $productKey }

    $license | Invoke-CimMethod -MethodName Activate
    Write-Output 'Windows 11 License updated and activated.'
    Exit 0
}

Catch {
    Write-Output 'Windows 11 License not updated.'
    Exit 2000
}