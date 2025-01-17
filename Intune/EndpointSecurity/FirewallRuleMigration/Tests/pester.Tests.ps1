. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Public\ConvertTo-IntuneFirewallRule.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\ConvertTo-IntuneFirewallRule-Helper.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Strings.ps1"

Describe 'ConvertTo-IntuneFirewallRule' {
    Context 'ConvertTo-IntuneFirewallRule expected cases' {
        It 'Should return empty array if no rules found' {
            Mock -CommandName 'Get-NetFirewallRule' -MockWith { return @() }
            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0 -Because 'Get-NetFirewallRule returned empty array, nothing to process'
        }
    }

    Context 'Splitting Firewall Rule tests' {
        Mock Get-FirewallPackageFamilyName -MockWith { return 'foo' }
        Mock Get-FirewallFilePath -MockWith { return 'foo' }
        Mock Get-FirewallServiceName -MockWith { return 'foo' }
        Mock Get-FirewallProtocol -MockWith { return 0 }
        Mock Get-FirewallLocalPortRange -MockWith { return @() }
        Mock Get-FirewallRemotePortRange -MockWith { return @() }
        Mock Get-FirewallLocalAddressRange -MockWith { return @() }
        Mock Get-FirewallRemoteAddressRange -MockWith { return @() }
        Mock Get-FirewallProfileType -MockWith { return 2 }
        Mock Get-FirewallAction -MockWith { return 'foo' }
        Mock Get-FirewallDirection -MockWith { return 'foo' }
        Mock Get-FirewallInterfaceType -MockWith { return 'foo' }
        Mock Get-FirewallLocalUserAuthorization -MockWith { return 'foo' }
        Mock Get-useAnyLocalAddressRangeOption -MockWith { return $true }
        Mock Get-useAnyRemoteAddressRangeOption -MockWith { return $false }

        # There is an array of only one object provided.
        $mockFirewallObject = @{displayName = 'foo'; description = 'foo'; Profiles = 2; Action = 2; Direction = 2 }
        Mock Get-NetFirewallRule -MockWith { return @($mockFirewallObject) }

        It 'Should skip splitting prompt if no split is determined necessary and just add object as normal' {
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $false }
            Mock Get-SplitIntuneFirewallRuleChoice
            Mock Split-IntuneFirewallRule

            $mockFirewallObject.displayName | Should -Be 'foo'
            #Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 1
            Assert-MockCalled Get-SplitIntuneFirewallRuleChoice -Exactly 0
            Assert-MockCalled Split-IntuneFirewallRule -Exactly 0
        }
    }
}