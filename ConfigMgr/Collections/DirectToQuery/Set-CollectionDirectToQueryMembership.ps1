#Load Configuration Manager PowerShell Module
Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0, $Env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-Location $SiteCode":"
Clear-Host

$RuleName = 'Direct Membership Replacement Query'
# CCM Client Name
#$QueryPart = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_SYSTEM.Name in ('
# AD Name
$QueryPart = 'select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System where SMS_R_System.Name in ('
$Merged = New-Object System.Collections.ArrayList

Write-Host '********************************************************************************'

Write-Host '**** Welcome to the Direct Membership Device Collection Converter Tool     ****' -ForegroundColor Green
Write-Host '**** This Script will convert Direct Memberships to Query Based Membership ****' -ForegroundColor Cyan

Write-Host '*******************************************************************************'

Write-Host

Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
Write-Host
Write-Host ' (1) Manually select the Device Collections your want to convert... ' -ForegroundColor Green
Write-Host
Write-Host ' (2) Run the Script on all Device Collection in your environment... ' -ForegroundColor Green
Write-Host
Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
Write-Host
$Choice_Number = ''
$Choice_Number = Read-Host -Prompt 'Based on which option you want to run, please type 1, 2 or E to exit the test, then click enter '

while ( !($Choice_Number -eq '1' -or $Choice_Number -eq '2' -or $Choice_Number -eq 'E')) {

    $Choice_Number = Read-Host -Prompt 'Invalid Option, Based on which option you want to run, please type 1, 2 or E to exit the test, then click enter '

}

if ($Choice_Number -eq 'E') {
    Break
}
if ($Choice_Number -eq '1') {
    Write-Host "Getting Device Collections with Direct Membership Rules..." -ForegroundColor Yellow
    $Collections = @(Get-CMDeviceCollection | Where-Object { $_.CollectionRules -like '*SMS_CollectionRuleDirect*' } | Select-Object Name, CollectionID, CollectionRules | Out-GridView -PassThru -Title 'Wait for all Collections to load, then select the Device Collections you want to convert. Use The ENTER Key or Mouse \ OK Button.')
}
if ($Choice_Number -eq '2') {
    Write-Host "Getting Device Collections with Direct Membership Rules..." -ForegroundColor Yellow
    $Collections = Get-CMDeviceCollection | Where-Object { $_.CollectionRules -like '*SMS_CollectionRuleDirect*' } | Select-Object Name, CollectionID, CollectionRules
}

if (!$Collections) {
    Write-Host 'No Collections selected, please run the script again...' -ForegroundColor Red
    Break
}


foreach ($Collection in $Collections) {

    if ($Collection.CollectionRules -like '*SMS_CollectionRuleDirect*') {

        $Output = New-Object -Type PSCustomObject
        $Output | Add-Member -type NoteProperty -Name ID -Value $Collection.CollectionID
        $Output | Add-Member -type NoteProperty -Name Collection -Value $Collection.Name

        Write-Host "The Collection $($Collection.Name) contains Direct Members..." -ForegroundColor Cyan
        Write-Host

        $DirectMembers = Get-CMDeviceCollectionDirectMembershipRule -CollectionName $Collection.Name
        Write-Host "Getting direct members for Collection $($Collection.Name)..." -ForegroundColor Cyan
        Write-Host

        $MembersArray = @()

        foreach ($DirectMember in $DirectMembers) {
            Write-Host "Direct Member $($DirectMember.RuleName) found." -ForegroundColor Yellow
            $MembersArray += $DirectMember.RuleName
        }

        $Members = '"{0}"' -f ($MembersArray -join '","')
        $Output | Add-Member -type NoteProperty -Name Members -Value $Members

        $QueryExpression = $QueryPart + $Members + ')'

        Try {
            Write-Host
            Write-Host "Adding Query based rule to Collection $($Collection.Name) to replace direct membership..." -ForegroundColor Cyan
            Write-Host
            Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $QueryExpression -RuleName $RuleName
            Write-Host 'Successfully added the query.' -ForegroundColor Green
            Write-Host
            $Output | Add-Member -type NoteProperty -Name Success -Value True
            Write-Host 'Removing Direct Membership Rules' -ForegroundColor Cyan
            Write-Host
            foreach ($DirectMember in $DirectMembers) {
                Try {
                    Remove-CMDeviceCollectionDirectMembershipRule -CollectionName $Collection.Name -ResourceID $DirectMember.ResourceID -Force
                    Write-Host "Successfully removed $($Directmember.RuleName)." -ForegroundColor Green
                    Write-Host

                }
                Catch {
                    Write-Host "Failed to remove $($Directmember.RuleName)." -ForegroundColor Red
                    Write-Host

                }
            }
        }
        Catch {
            Write-Host "Failed to convert Direct Membership to query for Collection $($Collection.Name)" -ForegroundColor Red
            $Output | Add-Member -type NoteProperty -Name Success -Value False
        }

        $Merged.Add($Output) | Out-Null

    }

}

Write-Host
Write-Host 'Results of the Collection Conversion...' -ForegroundColor Green
$Merged