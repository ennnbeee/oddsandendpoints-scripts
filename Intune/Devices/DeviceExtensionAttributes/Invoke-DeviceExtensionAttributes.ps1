[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All',

    [Parameter(Mandatory = $true)]
    [ValidateSet('Update', 'Remove')]
    [String]$Mode

)

#region Functions
Function Test-JSON() {

    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $TestJSON | Out-Null
        $validJson = $true
    }
    catch {
        $validJson = $false
        $_.Exception
    }
    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }

}
Function Get-DeviceAAD() {

    [cmdletbinding()]

    param
    (

    )

    $graphApiVersion = 'beta'
    $Resource = 'devices'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $GraphResults = Invoke-MgGraphRequest -Method GET -Uri $uri

        $Results = @()
        $Results += $GraphResults.value

        $Pages = $GraphResults.'@odata.nextLink'
        while ($null -ne $Pages) {

            $Additional = Invoke-MgGraphRequest -Method GET -Uri $Pages

            if ($Pages) {
                $Pages = $Additional.'@odata.nextLink'
            }
            $Results += $Additional.value
        }
        $Results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-DeviceAttribute() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON,

        [parameter(Mandatory = $true)]
        $deviceID
    )

    $graphApiVersion = 'Beta'
    $Resource = "devices/$deviceID"

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
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

If ($Mode -eq 'Update') {
    $attributeValue = Read-Host 'Enter in the attribute value to be assigned to devices...'
}
else {
    Clear-Variable attributeValue
}

$Devices = @(Get-DeviceAAD | Select-Object displayName, operatingSystem, manufacturer, model, id, deviceId | Out-GridView -PassThru -Title 'Select Devices to update extension attributes...')

$extensionAttributes = @()
for ($i = 1; $i -le 15; $i++) {
    $extensionAttributes += 'extensionAttribute' + $i
}
$Attribute = @($extensionAttributes | Out-GridView -PassThru -Title 'Select only one attribute you wish to update...')

while ($Attribute.count -gt 1) {
    Write-Host 'Only select one attribute to update' -ForegroundColor Yellow
    $Attribute = @($extensionAttributes | Out-GridView -PassThru -Title 'Select only one attribute you wish to update...')
}

if ($Devices.count -ne 0) {
    if ($Mode -eq 'Update') {
        Write-Host "$($Devices.count) devices have been selected and will have the data in $Attribute updated to $attributeValue" -ForegroundColor Cyan
    }
    else {
        Write-Host "$($Devices.count) devices have been selected and will have the data in $Attribute removed." -ForegroundColor Cyan
    }
    Write-Warning 'Please confirm you are happy with these settings before continuing' -WarningAction Inquire

    foreach ($Device in $Devices) {

        $JSON = @"
    {
        "extensionAttributes": {
            "$Attribute": "$attributeValue"
        }
    }
"@

        Add-DeviceAttribute -deviceID $device.id -JSON $JSON
        Write-Host "Successfully updated $Attribute for device object $($Device.displayName)" -ForegroundColor Green
    }
    #Disconnect-MgGraph
}
else {
    Write-Host 'Script Cancelled due to zero devices selected' -ForegroundColor Red
    break
}