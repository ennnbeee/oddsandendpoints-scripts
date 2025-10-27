$windowsRecallStatus = 0
$complianceSummary = New-Object -TypeName PSObject

$featureRecall = (Get-WindowsOptionalFeature -Online -FeatureName 'Recall')
if ($featureRecall.State -eq 'Enabled') {
    [PsObject[]]$regKeysRecall = @()
    $regKeysRecall += [PsObject]@{ Name = 'AllowRecallEnablement'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\'; value = 0; type = 'DWord' }
    $regKeysRecall += [PsObject]@{ Name = 'DisableAIDataAnalysis'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\'; value = 1; type = 'DWord' }

    foreach ($regKeyRecall in $regKeysRecall) {
        if ((Get-Item $regKeyRecall.path -ErrorAction Ignore).Property -contains $regKeyRecall.name) {
            if ((Get-ItemPropertyValue -Path $regKeyRecall.Path -Name $regKeyRecall.Name) -ne $regKeyRecall.value) {
                $windowsRecallStatus++
            }
        }
    }
}

if ($windowsRecallStatus -eq 0) {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall' -Value 'Disabled'
}
else {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall' -Value 'Enabled'
}

return $complianceSummary | ConvertTo-Json -Compress