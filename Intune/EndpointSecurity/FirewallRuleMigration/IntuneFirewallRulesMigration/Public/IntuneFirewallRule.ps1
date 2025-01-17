. "$PSScriptRoot\..\Private\Strings.ps1"
# An intermediate representation of an Intune firewall rule. The official definition of the firewall can be found here:
# https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windowsfirewallrule?view=graph-rest-beta
class IntuneFirewallRule {
    [String] $displayName
    [String] $description
    [String] $packageFamilyName
    [String] $filePath
    [String] $serviceName
    [Int32] $protocol
    [String[]] $localPortRanges
    [String[]] $remotePortRanges
    [String[]] $actualLocalAddressRanges
    [String[]] $actualRemoteAddressRanges
    [String[]] $profileTypes
    [String] $action
    [String] $trafficDirection
    [String[]] $interfaceTypes
    [String] $localUserAuthorizations
    [Bool] $useAnyRemoteAddressRange
    [Bool] $useAnyLocalAddressRange


}

class IntuneFirewallRuleDC {
    [String] $displayName
    [String] $description
    [String] $packageFamilyName
    [String] $filePath
    [String] $serviceName
    [Int32] $protocol
    [String[]] $localPortRanges
    [String[]] $remotePortRanges
    [String[]] $localAddressRanges
    [String[]] $remoteAddressRanges
    [String] $profileTypes
    [String] $action
    [String] $trafficDirection
    [String] $interfaceTypes
    [String] $localUserAuthorizations
    [String] $edgeTraversal
}
function New-IntuneFirewallRuleDC {
    <#
    .SYNOPSIS
    Creates a new Intune firewall object.

    .DESCRIPTION
    New-IntuneFirewallRule will create a blank IntuneFirewallRule object that can be used to set data values for importing to Intune Device Configuration.

    .EXAMPLE
    New-IntuneFirewallRule

    .OUTPUTS
    IntuneFirewallRule
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param()
    If ($PSCmdlet.ShouldProcess('', $Strings.NewIntuneFirewallRuleShouldProcessMessage)) {
        return New-Object -TypeName IntuneFirewallRuleDC
    }
}
function New-IntuneFirewallRule {
    <#
    .SYNOPSIS
    Creates a new Intune firewall object.

    .DESCRIPTION
    New-IntuneFirewallRule will create a blank IntuneFirewallRule object that can be used to set data values for importing to Intune.

    .EXAMPLE
    New-IntuneFirewallRule

    .OUTPUTS
    IntuneFirewallRule
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param()
    If ($PSCmdlet.ShouldProcess('', $Strings.NewIntuneFirewallRuleShouldProcessMessage)) {
        return New-Object -TypeName IntuneFirewallRule
    }
}
function format-ArrString {
    <#
    .SYNOPSIS
    Properly format arrays to fit the intune firewall rule json format

    .DESCRIPTION
    format-ArrString will create a new array string that is compatible with the Intune firewall format
    .EXAMPLE
    format-ArrString $arraystring to be formatted

    .OUTPUTS
    Json array string
    #>
    param(

        $string
    )
    if ($string) {
        $splitString = ($string -split ',')
        $JsonString = ConvertTo-Json @($splitString)
        $replaceCharacters = $JsonString.replace("`r", '').replace("`n", '').replace(' ', '')

        return $replaceCharacters
    }
    else {
        return -split (ConvertTo-Json @()) -join ''
    }


}
function ConvertTo-IntuneFirewallRuleString {
    <#
    .SYNOPSIS
    Creates a new Intune firewall string.

    .DESCRIPTION
    A string would be created to represent the intunefirewallrule. This would be formatted in the same way a json serializer would format an object

    .EXAMPLE
    New-IntuneFirewallRule

    .OUTPUTS
    Json String
    #>

    Param(
        [Parameter(Mandatory = $true)]
        $firewallObject
    )

    return (@'
{{"displayName":{0},"description":{1},"trafficDirection":{2}, "action" :{3},"profileTypes":{4},"packageFamilyName":{5},"filePath":{6}, "serviceName" : {7},"protocol":{8},"localPortRanges": {9},"remotePortRanges": {10},"interfaceTypes" : {11},"localUserAuthorizations":{12},"useAnyLocalAddressRange": {13},"actualLocalAddressRanges" : {14},"useAnyRemoteAddressRange" :{15},"actualRemoteAddressRanges":{16}}}
'@ -f $(if ($firewallObject.displayName) { $firewallObject.displayName | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.description) { $firewallObject.description | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.trafficDirection) { $firewallObject.trafficDirection | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.action) { $firewallObject.action | ConvertTo-Json }else { "`"notConfigured`"" }),
       (format-ArrString $firewallObject.profileTypes),
        $(if ($firewallObject.packageFamilyName) { $firewallObject.packageFamilyName | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.filePath) { $firewallObject.filePath | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.serviceName) { $firewallObject.serviceName | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.protocol) { $firewallObject.protocol }else { 'null' }),
       (format-ArrString $firewallObject.localPortRanges),
       (format-ArrString $firewallObject.remotePortRanges),
       (format-ArrString $firewallObject.interfaceTypes),
        $(if ($firewallObject.localUserAuthorizations) { $firewallObject.localUserAuthorizations | ConvertTo-Json }else { "`"`"" }),
        $(if ($firewallObject.useAnyLocalAddressRange) { 'true' }else { 'false' }),
       (format-ArrString $firewallObject.actualLocalAddressRanges),
        $(if ($firewallObject.useAnyRemoteAddressRange) { 'true' }else { 'false' }),
       (format-ArrString $firewallObject.actualRemoteAddressRanges)
    )
}

