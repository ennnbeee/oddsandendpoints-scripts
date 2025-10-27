$complianceSummary = New-Object -TypeName PSObject
$featureRecall = (Get-WindowsOptionalFeature -Online -FeatureName 'Recall')
if ($featureRecall.State -eq 'Enabled') {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall Feature' -Value 'Enabled'
}
else {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall Feature' -Value 'Disabled'
}

if ((Get-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\' -ErrorAction Ignore).Property -contains 'AllowRecallEnablement') {
    if ((Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\' -Name 'AllowRecallEnablement') -eq 0) {
        $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall AllowRecallEnablement' -Value 'Disabled'
    }
    else {
        $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall AllowRecallEnablement' -Value 'Enabled'
    }
}
else {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall AllowRecallEnablement' -Value 'Enabled'
}

if ((Get-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\' -ErrorAction Ignore).Property -contains 'DisableAIDataAnalysis') {
    if ((Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\' -Name 'DisableAIDataAnalysis') -eq 1) {
        $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall DisableAIDataAnalysis' -Value 'Enabled'
    }
    else {
        $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall DisableAIDataAnalysis' -Value 'Disabled'
    }
}
else {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall DisableAIDataAnalysis' -Value 'Disabled'
}

return $complianceSummary | ConvertTo-Json -Compress