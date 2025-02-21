<#
  .SYNOPSIS
  Captures URLs and IPs from the Microsoft Network Endpoints Webservice and creates Reusable Firewall Settings in Microsoft Intune.

  .DESCRIPTION
  The Invoke-MgReusableFirewall.ps1 script using Graph PowerShell tooling to capture the network endpoints for both URLs and IPs, from the
  Microsoft Endpoint Web Service (https://learn.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-ip-web-service?view=o365-worldwide)
  and grouping them by port or service to create new Reusable Firewall settings in Microsoft Intune.

  .PARAMETER tenantId
  Provide the Id of the tenant to connecto to.

  .PARAMETER tenantId
  Provide the name of the tenant, without the onmicrosoft.com domain, used to populate URLs.

  .PARAMETER instance
  The web service end point insance, choice of
  Worldwide | China | USGovDoD | USGovGCCHigh

  .PARAMETER serviceAreas
  An array of service areas pulled from the web service.
  Approved options: MEM, Common, Exchange, SharePoint, Skype, Store.

  .PARAMETER groupBy
  Option to group the configured Reusable Firewall settings by either ports, or by service.

  .PARAMETER Scopes
  The scopes used to connect to the Graph API using PowerShell.
  Default scopes configured are:
  'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

  .INPUTS
  None. You can't pipe objects to Invoke-MgReusableFirewall.ps1

  .OUTPUTS
  None. Invoke-MgReusableFirewall.ps1 doesn't generate any output.

  .EXAMPLE
  PS> .\Invoke-MgReusableFirewall.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -tenantName 'ennnbeee' -instance Worldwide -serviceAreas 'Common, MEM' -groupBy 'service'

#>
[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String]$appId,

    [Parameter(Mandatory = $false)]
    [String]$appSecret,

    [Parameter(Mandatory = $false)]
    [String]$tenantName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Worldwide', 'China', 'USGovDoD', 'USGovGCCHigh')]
    [String]$instance = 'Worldwide',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Common', 'MEM', 'Skype', 'Exchange', 'SharePoint', 'Store', 'Stream', 'Support', 'Intune', 'Office')]
    [String[]]$serviceAreas = @('Common', 'MEM', 'Skype', 'Exchange', 'SharePoint', 'Store', 'Stream', 'Support', 'Intune', 'Office'),

    [Parameter(Mandatory = $true)]
    [ValidateSet('ports', 'service')]
    [String]$groupBy,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)

<#region testing
$tenantId = '69b2ff03-08b5-4781-b7ea-af7ffbf790c4'
$tenantName = ''
$instance = 'Worldwide'
$serviceAreas = @('MEM')
$groupBy = 'service'
$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'
#endregion testing#>

#region Functions
Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.

.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.

.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.

.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.

.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.

.EXAMPLE
Connect-ToGraph -tenantId $tenantId -appId $app -appSecret $secret

-#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$tenantId,
        [Parameter(Mandatory = $false)] [string]$appId,
        [Parameter(Mandatory = $false)] [string]$appSecret,
        [Parameter(Mandatory = $false)] [string[]]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module microsoft.graph.authentication | Select-Object -ExpandProperty Version).major

        if ($AppId -ne '') {
            $body = @{
                grant_type    = 'client_credentials';
                client_id     = $appId;
                client_secret = $appSecret;
                scope         = 'https://graph.microsoft.com/.default';
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accesstokenfinal
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes -TenantId $tenantId
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}
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
Function New-DeviceReusableSetting() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/reusablePolicySettings'

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
#endregion Functions

#region app auth
$graphModule = 'Microsoft.Graph.Authentication'
Write-Host "Checking for $graphModule PowerShell module..." -ForegroundColor Cyan

If (!(Find-Module -Name $graphModule)) {
    Install-Module -Name $graphModule -Scope CurrentUser
}
Write-Host "PowerShell Module $graphModule found." -ForegroundColor Green

if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$graphModule*")) {
    Import-Module -Name $graphModule -Force
}

if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}
if ((!$appId -and !$appSecret) -or ($appId -and !$appSecret) -or (!$appId -and $appSecret)) {
    Write-Host 'Missing App Details, connecting using user authentication' -ForegroundColor Yellow
    Connect-ToGraph -tenantId $tenantId -Scopes $scopes
    $existingScopes = (Get-MgContext).Scopes
    Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
    Disconnect-MgGraph
    Write-Host 'Connecting to Graph' -ForegroundColor Cyan
    Connect-ToGraph -tenantId $tenantId -Scopes $existingScopes
}
else {
    Write-Host 'Connecting using App authentication' -ForegroundColor Yellow
    Connect-ToGraph -tenantId $tenantId -appId $appId -appSecret $appSecret
}
#endregion app auth

#region script

Write-Host 'Microsoft Online Reusable Firewall Setting Creator' -ForegroundColor Red

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$reusableSettings = @()

foreach ($serviceArea in $serviceAreas) {

    if ($tenantName) {
        #Removes the onmicrosoft crap
        $tenantName = $tenantName.Split('.')[0]

        $webService = ("https://endpoints.office.com/endpoints/$instance`?`TenantName=$tenantName`&`ServiceAreas=$serviceArea`&`clientrequestid=" + ([GUID]::NewGuid()).Guid)
    }
    else {
        $webService = ("https://endpoints.office.com/endpoints/$instance`?`ServiceAreas=$serviceArea`&`clientrequestid=" + ([GUID]::NewGuid()).Guid)
    }

    Write-Host "Getting Network Endpoints for $serviceArea Service" -ForegroundColor Cyan
    # URLs and IPs that don't exist in the Web Service
    if ($serviceArea -in 'Store', 'Stream', 'Support', 'Intune', 'Office') {
        if ($serviceArea -eq 'Store') {
            $urlsStore = @(
                'displaycatalog.md.mp.microsoft.com',
                'purchase.md.mp.microsoft.com',
                'licensing.mp.microsoft.com'
                '*.displaycatalog.mp.microsoft.com',
                'purchase.mp.microsoft.com',
                'storecatalogrevocation.storequality.microsoft.com',
                'img-prod-cms-rt-microsoft-com.akamaized.net',
                '*.md.mp.microsoft.com',
                'pti.store.microsoft.com',
                'markets.books.microsoft.com',
                'storeedgefd.dsx.mp.microsoft.com',
                'livetileedge.dsx.mp.microsoft.com',
                'share.microsoft.com',
                '*.microsoft.com.akadns.net',
                'clientconfig.passport.net windowsphone.com',
                '*.microsoft.com',
                '*.s-microsoft.com',
                'manage.devcenter.microsoft.com'
            ) | Sort-Object | Get-Unique
            $reusableSettings += [pscustomobject]@{displayName = 'Microsoft Store URLs'; description = 'Network Endpoints for Microsoft Store on TCP Ports(s) 80,443'; urls = $urlsStore; ips = $null; ipsName = $null }
            Write-Host "Found 1 Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host
        }
        if ($serviceArea -eq 'Stream') {
            $urlsStream = @(
                '*.cloudapp.net',
                '*.api.microsoftstream.com',
                '*.notification.api.microsoftstream.com',
                'amp.azure.net',
                'api.microsoftstream.com'
                'az416426.vo.msecnd.net',
                's0.assets-yammer.com',
                'vortex.data.microsoft.com',
                'web.microsoftstream.com'
            ) | Sort-Object | Get-Unique

            $reusableSettings += [pscustomobject]@{displayName = 'Microsoft Stream URLs'; description = 'Network Endpoints for Microsoft Stream on TCP Ports(s) 80,443'; urls = $urlsStream; ips = $null; ipsName = $null }
            Write-Host "Found 1 Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host
        }
        if ($serviceArea -eq 'Support') {
            $urlsSupport = @(
                'autodiscover.outlook.com',
                'officecdn.microsoft.com',
                'api.diagnostics.office.com',
                'apibasic.diagnostics.office.com',
                'autodiscover-s.outlook.com',
                'cloudcheckenabler.azurewebsites.net',
                'login.live.com',
                'login.microsoftonline.com',
                'login.windows.net',
                'o365diagtelemetry.trafficmanager.net',
                'odc.officeapps.live.com',
                'offcatedge.azureedge.net',
                'officeapps.live.com',
                'outlook.office365.com',
                'outlookdiagnostics.azureedge.net',
                'sara.api.support.microsoft.com',
                '*.msappproxy.net',
                '*.vortex-win.data.microsoft.com',
                'cs11.wpc.v0cdn.net',
                'cs1137.wpc.gammacdn.net',
                'settings.data.microsoft.com',
                'settings-win.data.microsoft.com'
            ) | Sort-Object | Get-Unique

            $reusableSettings += [pscustomobject]@{displayName = 'Microsoft Support URLs'; description = 'Network Endpoints for Microsoft Support on TCP Ports(s) 80,443'; urls = $urlsSupport; ips = $null; ipsName = $null }
            Write-Host "Found 1 Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host
        }
        if ($serviceArea -eq 'Intune') {
            $urlsIntune = @(
                'dmd.metaservices.microsoft.com',
                'ztd.dds.microsoft.com',
                'cs.dds.microsoft.com',
                '*.microsoftaik.azure.net',
                'activation.sls.microsoft.com',
                'validation.sls.microsoft.com',
                'activation-v2.sls.microsoft.com',
                'validation-v2.sls.microsoft.com',
                'licensing.mp.microsoft.com',
                'licensing.md.mp.microsoft.com',
                'cs9.wac.phicdn.net',
                'hwcdn.net',
                '*geo-prod.do.dsp.mp.microsoft.com',
                'wdcp.microsoft.com',
                'definitionupdates.microsoft.com',
                '*.smartscreen.microsoft.com',
                '*.smartscreen-prod.microsoft.com',
                'checkappexec.microsoft.com',
                'login.msa.akadns6.net',
                'us.configsvc1.live.com.akadns.net',
                'wd-prod-fe.cloudapp.azure.com',
                'accountalt.azureedge.net',
                'secure.aadcdn.microsoftonline-p.com',
                'ris-prod-atm.trafficmanager.net',
                'validation-v2.sls.trafficmanager.net',
                'ctldl.windowsupdate.com',
                'wu-bg-shim.trafficmanager.net'
                'wu.azureedge.net',
                'wu.ec.azureedge.net'
            ) | Sort-Object | Get-Unique

            $reusableSettings += [pscustomobject]@{displayName = 'Microsoft Intune URLs'; description = 'Network Endpoints for Microsoft Intune on TCP Ports(s) 80,443'; urls = $urlsIntune; ips = $null; ipsName = $null }
            Write-Host "Found 1 Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host
        }
        if ($serviceArea -eq 'Office') {
            $urlsOffice = @(
                '*.c-msedge.net',
                '*.e-msedge.net',
                '*.s-msedge.net',
                'nexusrules.officeapps.live.com',
                'ocos-office365-s2s.msedge.net',
                'officeclient.microsoft.com',
                'outlook.office365.com',
                'client-office365-tas.msedge.net',
                'www.office.com',
                'onecollector.cloudapp.aria',
                'v10.events.data.microsoft.com',
                'self.events.data.microsoft.com',
                'to-do.microsoft.com',
                'g.live.com',
                'msagfx.live.com',
                'oneclient.sfx.ms',
                'logincdn.msauth.net',
                'blobs.officehome.msocdn.com',
                'officehomeblobs.blob.core.windows.net',
                'outlookmobile-office365-tas.msedge.net',
                'config.teams.microsoft.com',
                'iecvlist.microsoft.com',
                'msedge.api.cdp.microsoft.com'
                '*.deploy.static.akamaitechnologies.com'
                '*.akamai.net',
                'f.c2r.ts.cdn.office.net',
                '*.trafficmanager.net',
                'officec2r.azureedge.net',
                'officec2r.ec.azureedge.net',
                'lb.apr-15cd6a.edgecastdns.net',
                'scdn29004.wpc.15cd6a.iotacdn.net',
                'sni1gl.wpc.iotacdn.net',
                'nf.smartscreen.microsoft.com',
                'go.microsoft.com.edgekey.net',
                '*.dspg.akamaiedge.net',
                'ocsp.digicert.com',
                'ocsp.edge.digicert.com',
                'sv.symcb.com',
                'crl-symcprod.digicert.com',
                'crl.edge.digicert.com',
                's1.symcb.com',
                'crl.verisign.com',
                'e11290.dspg.akamaiedge.net',
                'mpki-ocsp.digicert.com',
                's2.symcb.com'
            ) | Sort-Object | Get-Unique

            $reusableSettings += [pscustomobject]@{displayName = 'Microsoft Office App URLs'; description = 'Network Endpoints for Microsoft Office Apps on TCP Ports(s) 80,443'; urls = $urlsOffice; ips = $null; ipsName = $null }
            Write-Host "Found 1 Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host
        }
    }
    else {
        try {
            $endpointSets = (Invoke-RestMethod -Uri $webService) | Where-Object { $_.serviceArea -eq $serviceArea }
            Write-Host "Found $($endpointSets.Count) Network Endpoints for $serviceArea Service" -ForegroundColor Green
            Write-Host

        }
        catch {
            Write-Host "Unable to get Network Endpoints for $serviceArea from $webService" -ForegroundColor Red
            Write-Error $_.ErrorDetails
            break
        }

        if ($groupBy -eq 'ports') {

            $endpointSets.ForEach({

                    if ($_.tcpPorts) {
                        $_.tcpPorts = $(($_.tcpPorts.Replace(' ', '').Split(',') | Sort-Object) -join ',')
                    }
                    if ($_.udpPorts) {
                        $_.udpPorts = $(($_.udpPorts.Replace(' ', '').Split(',') | Sort-Object) -join ',')
                    }
                })

            $tcpSets = $endpointSets | Group-Object tcpPorts

            foreach ($tcpSet in $tcpSets) {

                Clear-Variable -Name ('displayName', 'description', 'urls', 'ips', 'ipsName', 'tcpPorts') -ErrorAction Ignore

                $urls = $tcpSet.Group.urls | Sort-Object | Get-Unique
                $ips = $tcpSet.Group.ips | Sort-Object | Get-Unique
                $tcpPorts = $tcpSet.Name
                $name = $tcpSet.Group.serviceAreaDisplayName | Sort-Object | Get-Unique
                $displayName = $name + ' URLs and IPs' + ' TCP ' + $tcpPorts
                $description = "All URL and IP Network Endpoints for $name on TCP Port(s) $($tcpSet.Name)"
                $ipsName = "IP Addresses for $name"

                # Plus one as IPs only count as a single setting
                if (($urls.Count + 1) -le 100) {
                    $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urls; ips = $ips; ipsName = $ipsName }
                }
                else {
                    $displayName = $name + ' IPs' + ' TCP ' + $tcpPorts
                    $description = "All IP Network Endpoints for $name on TCP Port(s) $($tcpSet.Name)"
                    $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $null; ips = $ips; ipsName = $ipsName }

                    $counter = [pscustomobject] @{ Value = 0 }
                    $groupSize = 100
                    $urlSubSets = $urls | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }

                    foreach ($urlSubSet in $urlSubSets) {
                        $displayName = $name + ' URLs IPs' + ' TCP ' + $tcpPorts + ' ' + $urlSubSet.Name
                        $description = "All URL Network Endpoints for $name on TCP Port(s) $($tcpSet.Name)"
                        $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urlSubSet.Group; ips = $null; ipsName = $null }
                    }
                }
            }


            $udpSets = $endpointSets | Where-Object { $null -ne $_.udpPorts } | Group-Object udpPorts

            foreach ($udpSet in $udpSets) {

                Clear-Variable -Name ('displayName', 'description', 'urls', 'ips', 'ipsName', 'udpPorts') -ErrorAction Ignore

                $urls = $udpSet.Group.urls | Sort-Object | Get-Unique
                $ips = $udpSet.Group.ips | Sort-Object | Get-Unique
                $udpPorts = $udpSet.Name
                $name = $udpSet.Group.serviceAreaDisplayName | Sort-Object | Get-Unique
                $displayName = $name + ' URLs and IPs' + ' UDP ' + $udpPorts
                $description = "All URL and IP Network Endpoints for $name on UDP Port(s) $($udpSet.Name)"
                $ipsName = "IP Addresses for $name"

                # Plus one as IPs only count as a single setting
                if (($urls.Count + 1) -le 100) {
                    $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urls; ips = $ips; ipsName = $ipsName }
                }
                else {
                    $displayName = $name + ' IPs' + ' UDP ' + $udpPorts
                    $description = "All IP Network Endpoints for $name on UDP Port(s) $($udpSet.Name)"
                    $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $null; ips = $ips; ipsName = $ipsName }

                    $counter = [pscustomobject] @{ Value = 0 }
                    $groupSize = 100
                    $urlSubSets = $urls | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }

                    foreach ($urlSubSet in $urlSubSets) {
                        $displayName = $name + ' URLs IPs' + ' UDP ' + $udpPorts + ' ' + $urlSubSet.Name
                        $description = "All URL Network Endpoints for $name on UDP Port(s) $($udpSet.Name)"
                        $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urlSubSet.Group; ips = $null; ipsName = $null }
                    }
                }
            }
        }
        else {

            Clear-Variable -Name ('displayName', 'description', 'urls', 'ips', 'ipsName') -ErrorAction Ignore

            $urls = $endpointSets.urls | Sort-Object | Get-Unique
            $ips = $endpointSets.ips | Sort-Object | Get-Unique
            $name = $endpointSets.serviceAreaDisplayName | Sort-Object | Get-Unique
            $displayName = $name + ' URLs and IPs'
            $description = "All URL and IP Network Endpoints for $name"
            $ipsName = "IP Addresses for $name"

            # Plus one as IPs only count as a single setting
            if (($urls.Count + 1) -le 100) {
                $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urls; ips = $ips; ipsName = $ipsName }
            }
            else {
                $displayName = $name + ' IPs'
                $description = "IP Network Endpoints for $name"
                $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $null; ips = $ips; ipsName = $ipsName }

                $counter = [pscustomobject] @{ Value = 0 }
                $groupSize = 100
                $urlSubSets = $urls | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }

                foreach ($urlSubSet in $urlSubSets) {
                    $displayName = $name + ' URLs ' + $urlSubSet.Name
                    $description = "URL Network Endpoints for $name"
                    $reusableSettings += [pscustomobject]@{displayName = $displayName; description = $description; urls = $urlSubSet.Group; ips = $null; ipsName = $null }
                }
            }
        }
    }
}

Write-Host 'Please review the Microsoft Intune Reusable Firewall Settings' -ForegroundColor Yellow
Write-Host
Write-Host 'Reusable Firewall Setting Names:' -ForegroundColor Cyan
Write-Host "$($reusableSettings.displayName)" -ForegroundColor Magenta
Write-Host
Write-Host 'Reusable Firewall Setting URls:' -ForegroundColor Cyan
Write-Host "$($reusableSettings.urls)" -ForegroundColor Magenta
Write-Host
Write-Host 'Reusable Firewall Setting IP:' -ForegroundColor Cyan
Write-Host "$($reusableSettings.ips)" -ForegroundColor Magenta
Write-Host
Write-Warning 'Please review the above and confirm you are happy to continue.' -WarningAction Inquire
Write-Host

foreach ($reusableSetting in $reusableSettings) {

    Write-Host "Building JSON for $($reusableSetting.displayName) with $($reusableSetting.urls.Count) URLs and $($reusableSetting.ips.Count) IPs." -ForegroundColor Cyan

    Clear-Variable *JSON

    $startJSON = @"
    {
        "displayName": "$($reusableSetting.displayName)",
        "description": "$($reusableSetting.description)",
        "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}",
        "settingInstance": {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}",
            "groupSettingCollectionValue": [

"@

    if (-not ([string]::IsNullOrEmpty($($reusableSetting.urls)))) {
        $urlsJSON = @()
        foreach ($url in $($reusableSetting.urls)) {
            if (([string]::IsNullOrEmpty($($reusableSetting.ips)))) {
                if ($url -eq $($reusableSetting.urls)[0] -and $($reusableSetting.urls).Count -eq 1) {
                    # no comma
                    $urlJSON = @"
                {
                    "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve_true",
                                "children": []
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_keyword",
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$url"
                            }
                        }
                    ]
                }

"@
                }
                elseif ($url -eq $($reusableSetting.urls)[-1]) {
                    # no comma
                    $urlJSON = @"
                {
                    "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve_true",
                                "children": []
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_keyword",
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$url"
                            }
                        }
                    ]
                }

"@
                }
                else {
                    # comma
                    $urlJSON = @"
                {
                    "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve_true",
                                "children": []
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_keyword",
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$url"
                            }
                        }
                    ]
                },

"@
                }
            }
            else {
                $urlJSON = @"
                {
                    "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve_true",
                                "children": []
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_keyword",
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$url"
                            }
                        }
                    ]
                },

"@
            }
            $urlsJSON += $urlJSON
        }
    }

    if (-not ([string]::IsNullOrEmpty($($reusableSetting.ips)))) {

        $ipStartJSON = @'
                {
                    "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_autoresolve_false",
                                "children": [
                                    {
                                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                                        "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_addresses",
                                        "simpleSettingCollectionValue": [

'@
        $ipsJSON = @()
        foreach ($ip in $($reusableSetting.ips)) {
            if ($ip -eq $($reusableSetting.ips)[0] -and $($reusableSetting.ips).Count -eq 1) {
                $ipJSON = @"
                                            {
                                                "value": "$ip",
                                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            }

"@
            }
            elseif ($ip -eq $($reusableSetting.ips)[-1]) {
                $ipJSON = @"
                                            {
                                                "value": "$ip",
                                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            }

"@
            }
            else {
                $ipJSON = @"
                                            {
                                                "value": "$ip",
                                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            },

"@
            }
            $ipsJSON += $ipJSON
        }

        $ipEndJSON = @"
                                                ]
                                        }
                                    ]
                                }
                            },
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                                "settingDefinitionId": "vendor_msft_firewall_mdmstore_dynamickeywords_addresses_{id}_keyword",
                                "simpleSettingValue": {
                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                    "value": "$($reusableSetting.ipsName)"
                                }
                            }
                        ]
                    }

"@

        $ipFullJSON = $ipStartJSON + $ipsJSON + $ipEndJSON
    }

    $endJSON = @'
                ]
        },
        "@odata.type": "#microsoft.graph.deviceManagementReusablePolicySetting",
        "id": "73d46494-6e54-4fbc-9707-e69bfef7d538"
    }
'@


    Try {
        $JSON = $startJSON + $urlsJSON + $ipFullJSON + $endJSON
        #$outfile = $($reusableSetting.displayName) + '.json'
        #$JSON | Out-File $outfile
        Write-Host "Creating Reusable Firewall Setting for $($reusableSetting.displayName) in Microsoft Intune" -ForegroundColor Cyan
        New-DeviceReusableSetting -JSON $JSON
        Write-Host "Successfully created Reusable Firewall Setting for $($reusableSetting.displayName) in Microsoft Intune" -ForegroundColor Green
        Write-Host
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        Write-Warning $ErrorMessage
        Disconnect-MgGraph
        break
    }

}

#endregion script