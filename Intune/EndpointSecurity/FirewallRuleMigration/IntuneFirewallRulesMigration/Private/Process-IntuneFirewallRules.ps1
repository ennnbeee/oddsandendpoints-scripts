. "$PSScriptRoot\..\Public\IntuneFirewallRule.ps1"
. "$PSScriptRoot\Use-HelperFunctions.ps1"
. "$PSScriptRoot\Strings.ps1"

# This file contains helper functions that deal with parsing IntuneFirewallRule objects.

function Test-IntuneFirewallRuleSplit {
    <#
    .SYNOPSIS
    Determines if the firewall rule has multiple attributes set for PackageFamilyName, FilePath, or ServiceName

    .DESCRIPTION
    Test-IntuneFirewallRuleSplit will take the provided firewall rule object and return True if a firewall object
    has at least two of the elements in the set (PackageFamilyName, FilePath, ServiceName) filled as a non-empty value.
    Intune Graph API does not accept firewall rule objects if multiple properties in this set are filled out.

    .EXAMPLE
    Test-IntuneFirewallRuleSplit $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windowsfirewallrule?view=graph-rest-beta

    .INPUTS
    IntuneFirewallRule

    The Intune firewall rule to check if it needs to be split

    .OUTPUTS
    Boolean

    Whether or not the provided IntuneFirewallRule object has multiple attributes filled for PackageFamilyName, FilePath, or ServiceName
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRule]
        $firewallObject
    )

    $attributesFilled = 0
    If ($firewallObject.packageFamilyName) {
        $attributesFilled++
    }
    If ($firewallObject.filePath) {
        $attributesFilled++
    }
    If ($firewallObject.serviceName) {
        $attributesFilled++
    }
    # One attribute (or less) is allowed by the Graph.
    return $attributesFilled -gt 1
}

function Split-IntuneFirewallRule {
    <#
    .SYNOPSIS
    Splits firewall objects up into multiple new objects if they have multiple attributes set for PackageFamilyName, FilePath, or ServiceName

    .DESCRIPTION
    Split-FirewallObject will take a firewall object with multiple attributes set for PackageFamilyName, FilePath, or ServiceName and create new objects
    where only one attribute is set for each attribute. For instance, an IntuneFirewallRule with PackageFamilyName and FilePath attributes set will result in
    two new IntuneFirewallRule objects: one with PackageFamilyName set, another with FilePath set. This can be used in scenarios where firewall rules with
    multiple of these attributes are discovered on the host.

    .EXAMPLE
    Split-FirewallObject -firewallObject $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windowsfirewallrule?view=graph-rest-beta

    .NOTES
    Split-IntuneFirewallRule should be used when a split has been found, but it is possible to have the function return the same object passed to it.
    If the firewall rule object does not have any of these attributes, however, it will not return the object, so it is best used when a split has
    been found.

    .INPUTS
    IntuneFirewallRule
    The Intune firewall rule object to split

    .OUTPUTS
    IntuneFirewallRule[]

    A stream of exported firewall rules represented via the intermediate IntuneFirewallRule class
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRule]
        $firewallObject
    )

    $newFirewallRuleObjects = @()
    # Since we have a reference to the original firewall object, we can split the firewall rule
    # on each individual property if they exist based on the original firewall's properties
    If ($firewallObject.packageFamilyName) {
        $newFirewallRule = Copy-IntuneFirewallRule -firewallObject $firewallObject
        $newFirewallRule.filePath = $null
        $newFirewallRule.serviceName = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    If ($firewallObject.filePath) {
        $newFirewallRule = Copy-IntuneFirewallRule -firewallObject $firewallObject
        $newFirewallRule.packageFamilyName = $null
        $newFirewallRule.serviceName = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    If ($firewallObject.serviceName) {
        $newFirewallRule = Copy-IntuneFirewallRule -firewallObject $firewallObject
        $newFirewallRule.packageFamilyName = $null
        $newFirewallRule.filePath = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    return $newFirewallRuleObjects
}

function Copy-IntuneFirewallRule {
    <#
    .SYNOPSIS
    Copies the properties of the provided firewall rule into a new firewall rule object.

    .DESCRIPTION
    Copy-IntuneFirewallRule will copy the properties of the firewallObject argument and return a new IntuneFirewallRule object
    with the same properties.

    .EXAMPLE
    Copy-IntuneFirewallRule -firewallObject $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-member?view=powershell-6#examples

    .NOTES
    Copy-FirewallRule will follow the same copy scheme that Add-Member performs. This means that if Add-Member performs
    a shallow copy or deep copy, Copy-FirewallRule will mimic this behavior. This means that arrays are shallowly copied.
    Operations using the shallow copy of an array should be considered carefully when using this function.

    .INPUTS
    IntuneFirewallRule

    The Intune firewall rule object to copy

    .OUTPUTS
    IntuneFirewallRule

    A copy of the Intune firewall rule object provided
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRule]
        $firewallObject
    )

    # Follows a similar pattern to Example #5 in the provided link
    $newFirewallRule = New-IntuneFirewallRule
    ForEach ($property in $firewallObject.PsObject.Properties) {
        # We have to use the -Force option to overwrite the default values
        # that were initialized when Net-IntuneFirewallRule was called
        $newFirewallRule | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value -Force
    }
    return $newFirewallRule
}

function Get-SplitIntuneFirewallRuleChoice {
    <#
    .SYNOPSIS
    Prompts the user for a choice to split IntuneFirewallRules objects and returns their choice as a string enumeration.

    .DESCRIPTION
    Get-SplitIntuneFirewallRuleChoice will prompt the user to pick a choice to split a firewall rule (Yes, No, Yes To All, Continue).
    If provided the -splitFirewallRules argument as true, the function will default to Yes.

    .EXAMPLE
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject -splitFirewallRules $true
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject -splitFirewallRules $false

    .PARAMETER splitConflictingAttributes A boolean denoting whether or not the user wanted to split firewall rules
    .PARAMETER firewallObject The firewall object.

    .NOTES
    Get-SplitIntuneFirewallRuleChoice returns the user's choice as a string, but does not actually perform the splitting

    .OUTPUTS
    String

    A string from the enumeration consisting of {"Yes", "No", "Yes To All", "Continue"}
    #>
    Param(
        # Previous flag marked splitting firewall rule as okay
        [bool] $splitConflictingAttributes,
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRule] $firewallObject
    )
    # If provided, skips the prompts and returns a yes for the operation
    If (-not($splitConflictingAttributes)) {
        return $Strings.Yes
    }

    $splitTitle = $Strings.SplitFirewallRuleTitle
    $splitFirewallRuleInformation = $Strings.SplitFirewallRuleDisplayName -f $firewallObject.displayName
    # To make it clearer to users that we are splitting up firewall rules based on the properties that are set,
    # we only display the ones that have set values
    If ($firewallObject.packageFamilyName) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRulePackageFamilyName -f $firewallObject.packageFamilyName
    }
    If ($firewallObject.filePath) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRuleFilePath -f $firewallObject.filePath
    }
    If ($firewallObject.serviceName) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRuleServiceName -f $firewallObject.serviceName
    }

    $splitMessage = $Strings.SplitFirewallRuleMessage -f $splitFirewallRuleInformation

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', $Strings.SplitFirewallRuleYes
    $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', $Strings.SplitFirewallRuleNo
    $all = New-Object System.Management.Automation.Host.ChoiceDescription 'Yes to &All', $Strings.SplitFirewallRuleYesToAll
    $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', $Strings.SplitFirewallRuleContinue
    $splitOptions = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all, $continue)
    $choice = Get-UserPrompt -promptTitle $splitTitle `
        -promptMessage $splitMessage `
        -promptOptions $splitOptions `
        -defaultOption 0

    # Choice is the index of the option
    Switch ($choice) {
        0 { return $Strings.Yes }
        1 { return $Strings.No }
        2 { return $Strings.YesToAll }
        3 { return $Strings.Continue }
    }
}




#-----------------------------------------------------------------------------------------------------------------------------------------------------
# The function below are identical to the functions above only that these are specifically targeted toward the device configuration format
#----------------------------------------------------------------------------------------------------------------------------------------------------
function Test-IntuneFirewallRuleSplitDC {
    <#
    .SYNOPSIS
    Determines if the firewall rule has multiple attributes set for PackageFamilyName, FilePath, or ServiceName for Device Config

    .DESCRIPTION
    Test-IntuneFirewallRuleSplit will take the provided firewall rule object and return True if a firewall object
    has at least two of the elements in the set (PackageFamilyName, FilePath, ServiceName) filled as a non-empty value.
    Intune Graph API does not accept firewall rule objects if multiple properties in this set are filled out.

    .EXAMPLE
    Test-IntuneFirewallRuleSplit $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windowsfirewallrule?view=graph-rest-beta

    .INPUTS
    IntuneFirewallRule

    The Intune firewall rule to check if it needs to be split

    .OUTPUTS
    Boolean

    Whether or not the provided IntuneFirewallRule object has multiple attributes filled for PackageFamilyName, FilePath, or ServiceName
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRuleDC]
        $firewallObject
    )

    $attributesFilled = 0
    If ($firewallObject.packageFamilyName) {
        $attributesFilled++
    }
    If ($firewallObject.filePath) {
        $attributesFilled++
    }
    If ($firewallObject.serviceName) {
        $attributesFilled++
    }
    # One attribute (or less) is allowed by the Graph.
    return $attributesFilled -gt 1
}

function Split-IntuneFirewallRuleDC {
    <#
    .SYNOPSIS
    Splits firewall objects up into multiple new objects if they have multiple attributes set for PackageFamilyName, FilePath, or ServiceName

    .DESCRIPTION
    Split-FirewallObject will take a firewall object with multiple attributes set for PackageFamilyName, FilePath, or ServiceName and create new objects
    where only one attribute is set for each attribute. For instance, an IntuneFirewallRule with PackageFamilyName and FilePath attributes set will result in
    two new IntuneFirewallRule objects: one with PackageFamilyName set, another with FilePath set. This can be used in scenarios where firewall rules with
    multiple of these attributes are discovered on the host.

    .EXAMPLE
    Split-FirewallObject -firewallObject $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windowsfirewallrule?view=graph-rest-beta

    .NOTES
    Split-IntuneFirewallRule should be used when a split has been found, but it is possible to have the function return the same object passed to it.
    If the firewall rule object does not have any of these attributes, however, it will not return the object, so it is best used when a split has
    been found.

    .INPUTS
    IntuneFirewallRule
    The Intune firewall rule object to split

    .OUTPUTS
    IntuneFirewallRule[]

    A stream of exported firewall rules represented via the intermediate IntuneFirewallRule class
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRuleDC]
        $firewallObject
    )

    $newFirewallRuleObjects = @()
    # Since we have a reference to the original firewall object, we can split the firewall rule
    # on each individual property if they exist based on the original firewall's properties
    If ($firewallObject.packageFamilyName) {
        $newFirewallRule = Copy-IntuneFirewallRuleDC -firewallObject $firewallObject
        $newFirewallRule.filePath = $null
        $newFirewallRule.serviceName = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    If ($firewallObject.filePath) {
        $newFirewallRule = Copy-IntuneFirewallRuleDC -firewallObject $firewallObject
        $newFirewallRule.packageFamilyName = $null
        $newFirewallRule.serviceName = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    If ($firewallObject.serviceName) {
        $newFirewallRule = Copy-IntuneFirewallRuleDC -firewallObject $firewallObject
        $newFirewallRule.packageFamilyName = $null
        $newFirewallRule.filePath = $null
        $newFirewallRuleObjects += $newFirewallRule
    }

    return $newFirewallRuleObjects
}

function Copy-IntuneFirewallRuleDC {
    <#
    .SYNOPSIS
    Copies the properties of the provided firewall rule into a new firewall rule object.

    .DESCRIPTION
    Copy-IntuneFirewallRule will copy the properties of the firewallObject argument and return a new IntuneFirewallRule object
    with the same properties.

    .EXAMPLE
    Copy-IntuneFirewallRule -firewallObject $firewallObject

    .PARAMETER firewallObject The firewall object.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-member?view=powershell-6#examples

    .NOTES
    Copy-FirewallRule will follow the same copy scheme that Add-Member performs. This means that if Add-Member performs
    a shallow copy or deep copy, Copy-FirewallRule will mimic this behavior. This means that arrays are shallowly copied.
    Operations using the shallow copy of an array should be considered carefully when using this function.

    .INPUTS
    IntuneFirewallRule

    The Intune firewall rule object to copy

    .OUTPUTS
    IntuneFirewallRule

    A copy of the Intune firewall rule object provided
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRuleDC]
        $firewallObject
    )

    # Follows a similar pattern to Example #5 in the provided link
    $newFirewallRule = New-IntuneFirewallRuleDC
    ForEach ($property in $firewallObject.PsObject.Properties) {
        # We have to use the -Force option to overwrite the default values
        # that were initialized when Net-IntuneFirewallRule was called
        $newFirewallRule | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value -Force
    }
    return $newFirewallRule
}

function Get-SplitIntuneFirewallRuleChoiceDC {
    <#
    .SYNOPSIS
    Prompts the user for a choice to split IntuneFirewallRules objects and returns their choice as a string enumeration.

    .DESCRIPTION
    Get-SplitIntuneFirewallRuleChoice will prompt the user to pick a choice to split a firewall rule (Yes, No, Yes To All, Continue).
    If provided the -splitFirewallRules argument as true, the function will default to Yes.

    .EXAMPLE
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject -splitFirewallRules $true
    Get-SplitIntuneFirewallRuleChoice -firewallObject $firewallObject -splitFirewallRules $false

    .PARAMETER splitConflictingAttributes A boolean denoting whether or not the user wanted to split firewall rules
    .PARAMETER firewallObject The firewall object.

    .NOTES
    Get-SplitIntuneFirewallRuleChoice returns the user's choice as a string, but does not actually perform the splitting

    .OUTPUTS
    String

    A string from the enumeration consisting of {"Yes", "No", "Yes To All", "Continue"}
    #>
    Param(
        # Previous flag marked splitting firewall rule as okay
        [bool] $splitConflictingAttributes,
        [Parameter(Mandatory = $true)]
        [IntuneFirewallRuleDC] $firewallObject
    )
    # If provided, skips the prompts and returns a yes for the operation
    If ($splitConflictingAttributes) {
        return $Strings.Yes
    }

    $splitTitle = $Strings.SplitFirewallRuleTitle
    $splitFirewallRuleInformation = $Strings.SplitFirewallRuleDisplayName -f $firewallObject.displayName
    # To make it clearer to users that we are splitting up firewall rules based on the properties that are set,
    # we only display the ones that have set values
    If ($firewallObject.packageFamilyName) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRulePackageFamilyName -f $firewallObject.packageFamilyName
    }
    If ($firewallObject.filePath) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRuleFilePath -f $firewallObject.filePath
    }
    If ($firewallObject.serviceName) {
        $splitFirewallRuleInformation += $Strings.SplitFirewallRuleServiceName -f $firewallObject.serviceName
    }

    $splitMessage = $Strings.SplitFirewallRuleMessage -f $splitFirewallRuleInformation

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', $Strings.SplitFirewallRuleYes
    $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', $Strings.SplitFirewallRuleNo
    $all = New-Object System.Management.Automation.Host.ChoiceDescription 'Yes to &All', $Strings.SplitFirewallRuleYesToAll
    $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', $Strings.SplitFirewallRuleContinue
    $splitOptions = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all, $continue)
    $choice = Get-UserPrompt -promptTitle $splitTitle `
        -promptMessage $splitMessage `
        -promptOptions $splitOptions `
        -defaultOption 0

    # Choice is the index of the option
    Switch ($choice) {
        0 { return $Strings.Yes }
        1 { return $Strings.No }
        2 { return $Strings.YesToAll }
        3 { return $Strings.Continue }
    }
}