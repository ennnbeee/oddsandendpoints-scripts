try {
    $wmiObj = Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01"
    if ($wmiObj.LastScanError -ne '0') {
        Write-Output "Windows Store Apps not updated."
        Exit 1
    }
    else {
        Write-Output "Windows Store Apps updated."
        Exit 0
    }
}
catch {
    Write-Output "Unable to query Store App Update status."
    Exit 2000
}