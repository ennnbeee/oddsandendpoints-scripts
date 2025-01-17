<#
.SYNOPSIS
    Adds a specific value to an extension attribute on a computer object in AD
.DESCRIPTION
    Used to add device extension attributes to computer objects during a ConfigMgr OSD
.AUTHOR
    Nick Benton - memv.ennbee.uk
.VERSION
    1.0.0 - Original
.EXAMPLE
    .\Set-ADComputerAttributes.ps1 -computerName $env:ComputerName -extensionAttribute 15 -attributeValue %SCCMOSDVARIABLE%
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$computerName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [String]$extensionAttribute,

    [Parameter(Mandatory = $true)]
    [string]$attributeValue

)

Try {

    # creates the attribute from the supplied number
    $attribute = 'extensionAttribute' + $extensionAttribute

    # adds in the required windows capability
    Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'

    # clears the existing attribute value
    Set-ADComputer -Identity $computerName -Clear $attribute

    # adds the new attribute value
    Set-ADComputer -Identity -Add @{$attribute = $attributeValue }

    # remoes the required windows capability
    Remove-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0' -ErrorAction SilentlyContinue
    Exit 0
}
Catch {

    Write-Error $Error[0].ErrorDetails.Message
    Exit 1
}