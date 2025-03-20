[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [ValidateSet('Common', 'MEM', 'Skype', 'Exchange', 'SharePoint')]
    [String]$serviceArea

)

$m365IPs = (Invoke-RestMethod -Uri ("https://endpoints.office.com/endpoints/WorldWide?ServiceAreas=$serviceArea`&`clientrequestid=" + ([GUID]::NewGuid()).Guid)) | Where-Object { $_.ServiceArea -eq $serviceArea -and $_.ips } | Select-Object -Unique -ExpandProperty ips
$exclusionRoutes = @()

foreach ($m365IP in $m365IPs) {
    $exclusionRoute = @"
<Route>
    <Address>$($m365IP.Split('/')[0])</Address>
    <PrefixLength>$($m365IP.Split('/')[1])</PrefixLength>
    <ExclusionRoute>true</ExclusionRoute>
<Route>
"@
    $exclusionRoutes += $exclusionRoute
}

$exclusionRoutes | Out-File -FilePath "M365IPs-$serviceArea.xml" -Encoding utf8
