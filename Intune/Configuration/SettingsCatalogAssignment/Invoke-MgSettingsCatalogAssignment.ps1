#region Functions
[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)
Function Get-MDMGroup() {

    <#
    .SYNOPSIS
    This function is used to get AAD groups using Graph API
    .DESCRIPTION
    The function gets Azure AD groups by searching for the group display name
    .EXAMPLE
    Get-MDMGroup -Name 'SG_MEM'
    Get-MDMGroup -Name 'SG_MEM_Devices_Coporate_POC'
    .NOTES
    NAME: Get-MDMGroup
    #>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$GroupName
    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        $searchterm = 'search="displayName:' + $GroupName + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
        (Invoke-MgGraphRequest -Uri $uri -Method Get -Headers @{ConsistencyLevel = 'eventual' }).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceFilter() {

    <#
    .SYNOPSIS
    This function is used to get Intune Device Filters groups using Graph API
    .DESCRIPTION
    The function gets All Device Filters, or a specific Device Filter based on name or id
    .EXAMPLE
    Get-DeviceFilter
    Get-DeviceFilter -Name 'Corporate_All'
    Get-DeviceFilter -Id 'dee985c2-0e4e-4c70-9a13-186f3313fc14'
    .NOTES
    NAME: Get-DeviceFilter
    #>

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/assignmentFilters'

    try {
        if ($id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($Name) {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value | Where-Object { ($_.displayName).contains("$Name") }
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
Function Get-DeviceSettingsCatalogAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $Id
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/configurationPolicies/$Id/assignments"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method Get).value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceSettingsCatalog() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'beta'
    $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has 'mdm'"

    try {
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value | Where-Object { ($_.Name).contains("$Name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-DeviceSettingsCatalogAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$Id,

        [parameter(Mandatory = $false)]
        [string]$GroupId,

        [parameter(Mandatory = $true)]
        [ValidateSet('Include', 'Exclude')]
        [string]$AssignmentType,

        [parameter(Mandatory = $false)]
        [string]$FilterId,

        [parameter(Mandatory = $false)]
        [ValidateSet('Include', 'Exclude')]
        [string]$FilterType,

        [parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Devices')]
        [string]$All,

        [parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'Add')]
        $AssignmentAction
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/configurationPolicies/$Id/assign"

    try {
        # Stopping assignmnent of All Users or All Devices as an exclude assignment
        if (($All -ne '') -and ($AssignmentType -eq 'Exclude')) {
            Write-Warning 'You cannot All Devices or All Users groups as an exclude assignment'
            break
        }
        # Stopping assignment of group and All Devices/Users
        if (($All -ne '') -and ($GroupId -ne '')) {
            Write-Warning 'You cannot assign to All Devices or All Users, and groups'
            break
        }
        # Stopping assignment of group with filter as an exclude assignment
        if (($AssignmentType -eq 'Exclude') -and ($GroupId -ne '') -and ($FilterId -ne '')) {
            Write-Warning 'You cannot assign a group with a filter as an exclude assignment'
            break
        }

        # If Adding an assignment to existing assignments
        If ($AssignmentAction -eq 'Add') {
            # Checking if there are Assignments already configured
            $Assignments = Get-DeviceSettingsCatalogAssignment -Id $Id
            if ($Assignments.count -ge 1) {
                # Checking if the group is already assigned
                If (($GroupId -ne '') -and ($GroupId -in $Assignments.target.groupId)) {
                    Write-Warning 'The policy is already assigned to the Group'
                    break
                }
                # Checking if already assigned to All Devices
                ElseIf (($All -eq 'Devices') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allDevicesAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to the All Devices group'
                    break
                }
                # Checking if aleady assigned to All users
                ElseIf (($All -eq 'Users') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allLicensedUsersAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to the All Users group'
                    break
                }
                # Checking if already assigned to groups when assigning 'All' assignment
                ElseIf (($All -ne '') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.groupAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to a group(s), and cannot be assigned to All Devices or All Users groups'
                    break
                }
                # Checking if already assigned to 'All' when assigning groups
                ElseIf (($GroupId -ne '') -and (($Assignments.target.'@odata.type' -contains '#microsoft.graph.allDevicesAssignmentTarget') -or ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allLicensedUsersAssignmentTarget'))) {
                    Write-Warning 'The policy is already assigned to All Devices or All Users groups, and cannot be assigned to a group'
                    break
                }
                # If new assignment viable, captures existing assignments
                Else {
                    # Creates an array for the existing assignments
                    $TargetGroups = @()
                    foreach ($Assignment in $Assignments) {
                        $TargetGroup = New-Object -TypeName psobject

                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $Assignment.target.'@odata.type'

                        if ($Assignment.target.'@odata.type' -like '*groupAssignmentTarget*') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value $Assignment.target.groupId
                        }

                        if ($Assignment.target.deviceAndAppManagementAssignmentFilterType -ne 'none') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterId
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterType
                        }

                        $Target = New-Object -TypeName psobject
                        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
                        $TargetGroups += $Target
                    }
                }
            }
        }

        # Creates the new assignment
        $TargetGroup = New-Object -TypeName psobject

        if ($GroupId) {
            if ($AssignmentType -eq 'Exclude') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
            }
            elseif ($AssignmentType -eq 'Include') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
            }

            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value "$GroupId"
        }
        else {
            if ($All -eq 'Users') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allLicensedUsersAssignmentTarget'
            }
            ElseIf ($All -eq 'Devices') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allDevicesAssignmentTarget'
            }
        }

        if ($FilterType) {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $FilterId
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $FilterType
        }

        $Target = New-Object -TypeName psobject
        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
        $TargetGroups += $Target

        # Creating JSON object to pass to Graph
        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'assignments' -Value @($TargetGroups)
        $JSON = $Output | ConvertTo-Json -Depth 3

        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
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

# Get Settings Catalog
$Policy = Get-DeviceSettingsCatalog | Where-Object { $_.Name -eq 'Corporate_Configuration_Policy_Conflict' }

$id = $Policy.id

Get-DeviceSettingsCatalogAssignment -Id '0565e69e-7bba-455a-bfaa-4ca6680a02b5' | Format-List

# Getting group to assign
$Group = Get-MDMGroup -GroupName 'SG_MDM_Devices_Corporate_POC'

# Getting Device Filter
$Filter = Get-DeviceFilter -Name 'Corporate_Windows_All'

# Adding an include Group assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -GroupId $group.id

# Adding an include Group assignment with include filter
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -GroupId $group.id -FilterType Include -FilterID $Filter.id

# Adding an exclude Group assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Exclude -GroupId $group.id

# Adding an Include All Devices assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -All Devices

# Adding an Include All Devices assignment with filter
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -All Devices -FilterType Include -FilterID $Filter.id

# Replacing all assignment and adding an Include All Users assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Replace -AssignmentType Include -All Users
