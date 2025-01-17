Try {
    Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
    Write-Output "Windows Store Apps updated."
    Exit 0
}
Catch {
    Write-Output "Windows Store Apps not updated."
    Exit 2000
}