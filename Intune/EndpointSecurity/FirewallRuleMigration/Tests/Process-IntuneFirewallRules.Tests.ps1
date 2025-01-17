. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Public\IntuneFirewallRule.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Process-IntuneFirewallRules.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Strings.ps1"

Describe 'Test-IntuneFirewallRuleSplit' {
    It 'Should return True if serviceName, filePath, and packageFamilyName are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.filePath = 'filePathFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeTrue
    }

    It 'Should return True if filePath, and packageFamilyName are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.filePath = 'filePathFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeTrue
    }

    It 'Should return True if serviceName and packageFamilyName are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeTrue
    }

    It 'Should return True if serviceName, filePath are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.filePath = 'filePathFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeTrue
    }

    It 'Should return False if only serviceName is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.serviceName = 'serviceNameFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeFalse
    }

    It 'Should return False if only packageFamilyName is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeFalse
    }

    It 'Should return False if only filePath is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.filePath = 'filePathFoo'

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeFalse
    }

    It 'Should return False if none are filled' {
        $firewallRule = New-IntuneFirewallRule

        Test-IntuneFirewallRuleSplit -firewallObject $firewallRule | Should -BeFalse
    }
}

Describe 'Split-IntuneFirewallRule' {
    It 'Should split firewall object into three objects if serviceName, filePath, and packageFamilyName are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.filePath = 'filePathFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 3
    }

    It 'Should split firewall object into two objects if serviceName and filePath are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.filePath = 'filePathFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 2
    }

    It 'Should split firewall object into two objects if packageFamilyName and filePath are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.filePath = 'filePathFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 2
    }

    It 'Should split firewall object into two objects if packageFamilyName and serviceName are filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $firewallRule.serviceName = 'serviceNameFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 2
    }

    It 'Should split firewall object into one object if packageFamilyName is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.packageFamilyName = 'packageFamilyNameFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 1
    }

    It 'Should split firewall object into one object if filePath is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.filePath = 'filePathFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 1
    }

    It 'Should split firewall object into one object if serviceName is filled' {
        $firewallRule = New-IntuneFirewallRule
        $firewallRule.serviceName = 'serviceNameFoo'

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 1
    }

    It 'should return nothing if no desired property is filled' {
        $firewallRule = New-IntuneFirewallRule

        Split-IntuneFirewallRule -firewallObject $firewallRule | Should -HaveCount 0
    }
}

Describe 'Copy-IntuneFirewallRule' {
    It 'Should copy expected attributes from firewall object' {
        $oldFirewallRule = New-IntuneFirewallRule
        $oldFirewallRule.displayName = 'displayNameFoo'
        $oldFirewallRule.description = 'descriptionFoo'
        $oldFirewallRule.packageFamilyName = 'packageFamilyNameFoo'
        $oldFirewallRule.serviceName = 'serviceNameFoo'
        $oldFirewallRule.protocol = 2
        $oldFirewallRule.localPortRanges = @('foo', 'bar', 'baz')
        $oldFirewallRule.remotePortRanges = @('remoteFoo')
        $oldFirewallRule.localAddressRanges = @('localAddr', 'foo')
        $oldFirewallRule.remoteAddressRanges = @('remoteAddr', 'bar', 'baz')
        $oldFirewallRule.profileTypes = 'profileTypesFoo'
        $oldFirewallRule.action = 'actionFoo'
        $oldFirewallRule.trafficDirection = 'trafficDirectionFoo'
        $oldFirewallRule.interfaceTypes = 'interfaceTypesFoo'
        $oldFirewallRule.localUserAuthorizations = 'localUserAuthFoo'
        $oldFirewallRule.edgeTraversal = 'edgeTraversalFoo'

        $newFirewall = Copy-IntuneFirewallRule -firewallObject $oldFirewallRule
        ForEach ($property in $newFirewall.PSObject.Properties) {
            $property.Value | Should -Be $oldFirewallRule.($property.Name)
        }
    }

    It "Should not cause a copied object's strings to change if changing an attribute" {
        $oldFirewallRule = New-IntuneFirewallRule
        $oldFirewallRule.displayName = 'displayNameFoo'
        $newFirewall = Copy-IntuneFirewallRule -firewallObject $oldFirewallRule

        $oldFirewallRule.displayName = 'somethingDifferent'
        $oldFirewallRule.displayName | Should -Be 'somethingDifferent'
        $newFirewall.displayName | Should -Be 'displayNameFoo'
    }

    It "Should not cause a copied object's string arrays to change if changing to a new array" {
        $oldFirewallRule = New-IntuneFirewallRule
        $oldFirewallRule.localPortRanges = @('foo', 'bar', 'baz')
        $newFirewall = Copy-IntuneFirewallRule -firewallObject $oldFirewallRule

        $oldFirewallRule.localPortRanges = @('newArr')
        $oldFirewallRule.localPortRanges | Should -Be @('newArr')
        $newFirewall.localPortRanges | Should -Be @('foo', 'bar', 'baz')
    }

    It "Should mutate a copied object's array if mutating their own array" {
        $oldFirewallRule = New-IntuneFirewallRule
        $oldFirewallRule.localPortRanges = @('foo', 'bar', 'baz')
        $newFirewall = Copy-IntuneFirewallRule -firewallObject $oldFirewallRule

        $oldFirewallRule.localPortRanges[0] = 'new'
        $newFirewall.localPortRanges | Should -Be @('new', 'bar', 'baz') -Because 'Object is shallow copied'
    }
}

Describe 'Get-SplitIntuneFirewallRuleChoice' {
    It "Should return '$($Strings.Yes)' if given the -splitConflictingAttributes flag with a true value" {
        $foo = New-IntuneFirewallRule
        Get-SplitIntuneFirewallRuleChoice -firewallObject $foo -splitConflictingAttributes $true | Should -Be $Strings.Yes
    }

    It "Should return '$($Strings.Yes)' if user selected '$($Strings.Yes)'" {
        $foo = New-IntuneFirewallRule
        Mock Get-UserPrompt -MockWith { return 0 }
        Get-SplitIntuneFirewallRuleChoice -firewallObject $foo | Should -Be $Strings.Yes
    }

    It "Should return '$($Strings.No)' if user selected '$($Strings.No)'" {
        $foo = New-IntuneFirewallRule
        Mock Get-UserPrompt -MockWith { return 1 }
        Get-SplitIntuneFirewallRuleChoice -firewallObject $foo | Should -Be $Strings.No
    }

    It "Should return '$($Strings.YesToAll)' if user selected '$($Strings.YesToAll)'" {
        $foo = New-IntuneFirewallRule
        Mock Get-UserPrompt -MockWith { return 2 }
        Get-SplitIntuneFirewallRuleChoice -firewallObject $foo | Should -Be $Strings.YesToAll
    }

    It "Should return '$($Strings.Continue)' if user selected '$($Strings.Continue)'" {
        $foo = New-IntuneFirewallRule
        Mock Get-UserPrompt -MockWith { return 3 }
        Get-SplitIntuneFirewallRuleChoice -firewallObject $foo | Should -Be $Strings.Continue
    }
}