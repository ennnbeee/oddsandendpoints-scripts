<#
.SYNOPSIS
Generates dynamic group rules for phased device groups in Entra ID based on specified criteria.

.DESCRIPTION
Allows for the generation of dynamic group rules for phased device groups in Entra ID based on operating system, device ownership, and the number of groups. The script prompts for percentage allocations for each group and ensures the total equals 100%.

.PARAMETER operatingSystem
Specifies the operating system for which the phased group rules are to be generated. Valid values are 'Windows', 'macOS', 'Android', 'iOS', and 'All'.

.PARAMETER ownership
Specifies the device ownership type for which the phased group rules are to be generated. Valid values are 'Corporate', 'Personal', and 'Both'.

.PARAMETER groups
Specifies the number of phased groups to create. Valid values are integers from 1 to 10.

.EXAMPLE
.\Get-PhasedGroupRules.ps1 -operatingSystem 'Windows' -ownership 'Corporate' -groups 5

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]

param(

    [Parameter(Mandatory = $true, HelpMessage = 'Select the operating system to include in the phased groups')]
    [ValidateSet('Windows', 'macOS', 'Android', 'iOS', 'All')]
    [String]$operatingSystem,

    [Parameter(Mandatory = $true, HelpMessage = 'Select the device ownership to include in the phased groups')]
    [ValidateSet('Corporate', 'Personal', 'Both')]
    [String]$ownership,

    [Parameter(Mandatory = $true, HelpMessage = 'Select the number of phased groups to create (2-10)')]
    [ValidateRange(2, 10)]
    [String]$groups

)

#region functions
function Get-PhasedDynamicGroups {
    param (
        [int[]]$percentages
    )

    # Validate total percentage
    $total = ($percentages | Measure-Object -Sum).Sum
    if ($total -ne 100) {
        throw "Total percentage must equal 100. Current total: $total"
    }

    $hexValues = 0..255
    $groupSizes = $percentages | ForEach-Object { [math]::Round($_ * 256 / 100) }

    # Adjust rounding to ensure total is exactly 256
    $diff = 256 - ($groupSizes | Measure-Object -Sum).Sum
    if ($diff -ne 0) {
        $groupSizes[0] += $diff
    }

    $startIndex = 0
    $groupRules = @()

    for ($i = 0; $i -lt $groupSizes.Count; $i++) {
        $size = $groupSizes[$i]
        $prefixes = $hexValues[$startIndex..($startIndex + $size - 1)] | ForEach-Object {
            $_.ToString('x2')
        }
        $startIndex += $size

        # Group prefixes by first hex digit
        $grouped = $prefixes | Group-Object { $_.Substring(0, 1) }

        $regexParts = $grouped | ForEach-Object {
            $firstChar = $_.Name
            $secondChars = $_.Group | ForEach-Object { $_.Substring(1, 1) }
            $charClass = ($secondChars | Sort-Object -Unique) -join ''
            "^$firstChar[$charClass]"
        }

        $rule = ($regexParts | ForEach-Object {
                "(device.deviceId -match `"$($_)`")"
            }) -join ' -or '

        $groupRules += [PSCustomObject]@{
            Group = "$($i + 1)"
            Rule  = $rule
        }
    }

    return $groupRules
}
function Read-YesNoChoice {
    <#
        .SYNOPSIS
        Prompt the user for a Yes No choice.

        .DESCRIPTION
        Prompt the user for a Yes No choice and returns 0 for no and 1 for yes.

        .PARAMETER Title
        Title for the prompt

        .PARAMETER Message
        Message for the prompt

		.PARAMETER DefaultOption
        Specifies the default option if nothing is selected

        .INPUTS
        None. You cannot pipe objects to Read-YesNoChoice.

        .OUTPUTS
        Int. Read-YesNoChoice returns an Int, 0 for no and 1 for yes.

        .EXAMPLE
        PS> $choice = Read-YesNoChoice -Title "Please Choose" -Message "Yes or No?"

		Please Choose
		Yes or No?
		[N] No  [Y] Yes  [?] Help (default is "N"): y
		PS> $choice
        1

		.EXAMPLE
        PS> $choice = Read-YesNoChoice -Title "Please Choose" -Message "Yes or No?" -DefaultOption 1

		Please Choose
		Yes or No?
		[N] No  [Y] Yes  [?] Help (default is "Y"):
		PS> $choice
        1

        .LINK
        Online version: https://www.chriscolden.net/2024/03/01/yes-no-choice-function-in-powershell/
    #>

    param (
        [Parameter(Mandatory = $true)][String]$Title,
        [Parameter(Mandatory = $true)][String]$Message,
        [Parameter(Mandatory = $false)][Int]$DefaultOption = 0
    )

    $No = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'No'
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes'
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($No, $Yes)

    return $host.ui.PromptForChoice($Title, $Message, $Options, $DefaultOption)
}
#endregion functions

#region variables
$ruleManaged = '(device.deviceManagementAppId -ne null)'
$ruleOS = switch ($operatingSystem) {
    'Windows' { '(device.deviceOSType -eq "Windows")' }
    'macOS' { '(device.deviceOSType -eq "macmdm")' }
    'Android' { '(device.deviceOSType -eq "Android")' }
    'iOS' { '((device.deviceOSType -eq "iPhone") or (device.deviceOSType -eq "iPad"))' }
    'All' { $null }
}

$ruleOwnership = switch ($ownership) {
    'Corporate' { '(device.deviceOwnership -eq "Company")' }
    'Personal' { '(device.deviceOwnership -eq "Personal")' }
    'Both' { $null }
}
#endregion variables

#region group percentages
do {
    $groupPercentages = @()
    while (($groupPercentages | Measure-Object -Sum).Sum -ne 100) {
        $groupPercentages = @()
        $phaseGroups = 1..$groups
        Write-Host "`nYou have selected $groups phase groups. Please enter in the percentage of devices to include in each group. The total must equal 100%.`n" -ForegroundColor Cyan
        foreach ($phaseGroup in $phaseGroups) {
            $groupPercentage = Read-Host -Prompt "For Group $phaseGroup enter in the percentage of devices to include (1-99)"
            while ($groupPercentage -notmatch '^(\d?[1-9]|[1-9]0)$') {
                $groupPercentage = Read-Host "For Group $phaseGroup enter in the percentage of devices to include (1-99)"
            }
            $groupPercentages += $groupPercentage
        }
        if (($groupPercentages | Measure-Object -Sum).Sum -ne 100) {
            Write-Host "`nThe total percentage must equal 100%. You entered a total of $($($groupPercentages | Measure-Object -Sum).Sum)%. Please try again." -ForegroundColor Yellow
        }
    }
    Write-Host "`nYou have configured the following $groupNumber group percentages:`n" -ForegroundColor White
    $groupPercentages

    $decisionPercentage = Read-YesNoChoice -Title 'Review the above settings before proceeding' -Message 'Are you happy with the number of groups and the percentages?' -DefaultOption 1
}
until ($decisionPercentage -eq 1)
#endregion group percentages

#region group rules
$rulesComplete = @()
$groupRules = Get-PhasedDynamicGroups -Percentages $groupPercentages
foreach ($groupRule in $groupRules) {
    if ($null -ne $ruleOS) {
        if ($null -ne $ruleOwnership) {
            $ruleComplete = "$ruleManaged and $ruleOS and $ruleOwnership and ($($groupRule.Rule))"
        }
        else {
            $ruleComplete = "$ruleManaged and $ruleOS and ($($groupRule.Rule))"
        }
    }
    else {
        if ($null -ne $ruleOwnership) {
            $ruleComplete = "$ruleManaged and $ruleOwnership and ($($groupRule.Rule))"
        }
        else {
            $ruleComplete = "$ruleManaged and ($($groupRule.Rule))"
        }
    }
    $rulesComplete += [PSCustomObject]@{
        Group      = $($groupRule.Group)
        Percentage = $groupPercentages[$($groupRule.Group - 1)]
        Rule       = $ruleComplete
    }
}

Write-Host "`nThe following rules can be used to create group in Entra ID:`n" -ForegroundColor White
$rulesComplete | Format-List
#endregion group rules