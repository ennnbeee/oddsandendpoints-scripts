[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId = '437e8ffb-3030-469a-99da-e5b527908010',

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementApps.Read.All'

)

#region Functions
Function Test-JSON() {
    <#
        .SYNOPSIS
        This function is used to test if the JSON passed to a REST Post request is valid
        .DESCRIPTION
        The function tests if the JSON passed to the REST Post is valid
        .EXAMPLE
        Test-JSON -JSON $JSON
        Test if the JSON is valid before calling the Graph REST interface
        .NOTES
        NAME: Test-JSON
        #>
    param (
        $JSON
    )
    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
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
Function Get-AppCategory() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-AppCategory() {
    [cmdletbinding()]
    param
    (
        $Name
    )
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
    try {
        if ($Name -eq '' -or $null -eq $Name) {
            Write-Host 'No name specified, please specify valid Name for the App Category...' -f Red
            break
        }
        else {
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.mobileAppCategory'
            $Output | Add-Member -MemberType NoteProperty 'displayName' -Value $Name
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MobileApps() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileApps'
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MobileAppsCategory() {
    [cmdletbinding()]
    param
    (
        $Id
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Id specified, please specify valid Id for the Mobile App...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $value = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/mobileAppCategories/$CategoryId"
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.id' -Value $value
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Remove-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/$CategoryId/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Delete
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
#endregion

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
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication

Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and (!($_.'@odata.type').Contains('android')) }