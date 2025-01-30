# Group Prefix Variables
$groupPrefixes = ('SG-MDM', 'SG-ENT')

# Connect to tenant using MgGraph
$graphModules = ('Microsoft.Graph.Authentication', 'Microsoft.Graph.Identity.DirectoryManagement')

foreach ($graphModule in $graphModules) {
    Write-Host "Checking for $graphModule PowerShell module..." -ForegroundColor Cyan

    If (!(Find-Module -Name $graphModule)) {
        Install-Module -Name $graphModule -Scope CurrentUser
    }
    Write-Host "PowerShell Module $graphModule found." -ForegroundColor Green

    if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$graphModule*")) {
        Import-Module -Name $graphModule -Force
    }
}

Connect-MgGraph

# Get the tenant/organization details
$tenant = Get-MgOrganization -Property DisplayName
$tenantName = $tenant.DisplayName -replace '[^a-zA-Z0-9]', '_'  # Sanitize the tenant name for use in a file name

#variables
$groupsAll = @()
# Create the CSV file name using the tenant name
$csvFileName = "$tenantName-GroupExport.csv"

foreach ($groupPrefix in $groupPrefixes) {

    # Define the filter for dynamic groups starting with SG_Intune or SG_MDM
    $filterDynamic = "groupTypes/any(x:x eq 'dynamicmembership') and (startswith(displayName, '$groupPrefix'))"

    # Get dynamic groups that match the filter
    $groupsDynamic = Get-MgGroup -Filter $filterDynamic -All | Select-Object Id, DisplayName, MembershipRule

    $groupsAll += $groupsDynamic

    # Get assigned groups that start with SG_Intune or SG_MDM
    $filterAssigned = "startswith(displayName, '$groupPrefix')"
    $groupsAssigned = Get-MgGroup -Filter $filterAssigned -All | Where-Object { $_.GroupTypes -notcontains 'DynamicMembership' } | Select-Object Id, DisplayName, @{Name = 'MembershipRule'; Expression = { 'Assigned' } }

    $groupsAll += $groupsAssigned

}

# Export the combined results to a CSV file
$groupsAll | Export-Csv -NoTypeInformation -Path $csvFileName

Write-Host "Exported group data to $csvFileName"