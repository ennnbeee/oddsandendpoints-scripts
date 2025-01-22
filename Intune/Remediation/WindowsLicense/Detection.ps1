try {
    $licenseParam = @{
        ClassName = 'SoftwareLicensingProduct'
        Filter    = 'PartialProductKey is not null AND name like "windows%"'
    }

    $license = Get-CimInstance @licenseParam
    if ($license.LicenseStatus -ne '1') {
        Write-Output 'Windows is not activated.'
        Exit 1
    }
    else {
        Write-Output 'Windows is activated.'
        Exit 0
    }
}
catch {
    Write-Output 'Unable to query Windows activation status.'
    Exit 2000
}