
$complianceSummary = New-Object -TypeName PSObject
$featureRecall = (Get-WindowsOptionalFeature -Online -FeatureName 'Recall')
if ($featureRecall.State -eq 'Enabled') {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall' -Value 'Enabled'
}
else {
    $complianceSummary | Add-Member -MemberType NoteProperty -Name 'Windows Recall' -Value 'Disabled'
}

return $complianceSummary | ConvertTo-Json -Compress