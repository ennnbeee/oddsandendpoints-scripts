[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)

#region Functions
Function Add-GoogleApplication() {

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        $PackageID
    )

    $graphApiVersion = 'Beta'
    $App_resource = 'deviceManagement/androidManagedStoreAccountEnterpriseSettings/approveApps'

    try {

        $PackageID = 'app:' + $PackageID
        $Packages = New-Object -TypeName psobject
        $Packages | Add-Member -MemberType NoteProperty -Name 'approveAllPermissions' -Value 'true'
        $Packages | Add-Member -MemberType NoteProperty -Name 'packageIds' -Value @($PackageID)
        $JSON = $Packages | ConvertTo-Json -Depth 3

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($App_resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -ContentType 'application/json' -Body $JSON
        Write-Host "Successfully added $PackageID from Managed Google Store" -ForegroundColor Green

    }

    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }

}
Function Invoke-SyncGoogleApplication() {

    [cmdletbinding()]

    $graphApiVersion = 'Beta'
    $App_resource = '/deviceManagement/androidManagedStoreAccountEnterpriseSettings/syncApps'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($App_resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -ContentType 'application/json' -Body $JSON
        Write-Host 'Successfully synchronised Google Apps' -ForegroundColor Green

    }

    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }

}

#endregion Functions

#region authentication
if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}
$moduleName = 'Microsoft.Graph'
$Module = Get-InstalledModule -Name $moduleName
if ($Module.count -eq 0) {
    Write-Host "$moduleName module is not available" -ForegroundColor yellow
    $Confirm = Read-Host Are you sure you want to install module? [Y] Yes [N] No
    if ($Confirm -match '[yY]') {
        Install-Module -Name $moduleName -AllowClobber -Scope AllUsers -Force
    }
    else {
        Write-Host "$moduleName module is required. Please install module using 'Install-Module $moduleName -Scope AllUsers -Force' cmdlet." -ForegroundColor Yellow
        break
    }
}
else {
    If ($IsMacOS) {
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId

    }
    ElseIf ($IsWindows) {
        Connect-MgGraph -Scopes $scopes -UseDeviceCode -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }
    Else {
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication

#region Script
$AndroidAppIds = New-Object -TypeName System.Collections.ArrayList
$AndroidAppIds.AddRange(@(
        'com.azure.authenticator',
        'com.microsoft.emmx',
        'com.microsoft.office.excel',
        'com.microsoft.skydrive',
        'com.microsoft.office.onenote',
        'com.microsoft.office.outlook',
        'com.microsoft.planner',
        'com.microsoft.office.powerpoint',
        'com.microsoft.sharepoint',
        'com.microsoft.stream',
        'com.microsoft.teams',
        'com.microsoft.todos',
        'com.microsoft.office.word',
        'com.yammer.v1'
    )
)

foreach ($AndroidAppId in $AndroidAppIds) {
    Add-GoogleApplication -PackageID $AndroidAppId
}
Invoke-SyncGoogleApplication
#endregion Script