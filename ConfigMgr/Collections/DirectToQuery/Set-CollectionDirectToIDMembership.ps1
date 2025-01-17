#Load Configuration Manager PowerShell Module
Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0, $Env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1')

#Get SiteCode
$siteCode = Get-PSDrive -PSProvider CMSITE
Set-Location $siteCode":"
Clear-Host

$date = Get-Date -Format yyyyMMdd

$ruleName = "Direct Membership Replacement Query run on $date"

$queryStart = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_SYSTEM.SMSID in ('
$queryEnd = ')'


$conversionResults = New-Object System.Collections.ArrayList

Write-Host '***********************************************' -ForegroundColor white
Write-Host ''
Write-Host '█▀▄ █ █▀█ █▀▀ █▀▀ ▀█▀' -ForegroundColor Green
Write-Host '█▄▀ █ █▀▄ ██▄ █▄▄ ░█░' -ForegroundColor Green
Write-Host ''
Write-Host '█▀▄▀█ █▀▀ █▀▄▀█ █▄▄ █▀▀ █▀█ █▀ █░█ █ █▀█' -ForegroundColor Green
Write-Host '█░▀░█ ██▄ █░▀░█ █▄█ ██▄ █▀▄ ▄█ █▀█ █ █▀▀' -ForegroundColor Green
Write-Host ''
Write-Host '█▀▀ █▀█ █░░ █░░ █▀▀ █▀▀ ▀█▀ █ █▀█ █▄░█' -ForegroundColor Yellow
Write-Host '█▄▄ █▄█ █▄▄ █▄▄ ██▄ █▄▄ ░█░ █ █▄█ █░▀█' -ForegroundColor Yellow
Write-Host ''
Write-Host '█▀▀ █▀█ █▄░█ █░█ █▀▀ █▀█ ▀█▀ █▀▀ █▀█' -ForegroundColor Yellow
Write-Host '█▄▄ █▄█ █░▀█ ▀▄▀ ██▄ █▀▄ ░█░ ██▄ █▀▄' -ForegroundColor Yellow
Write-Host ''
Write-Host '***********************************************' -ForegroundColor white
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
    Write-Host 'Bye'
    Break
}
if ($Choice_Number -eq '1') {
    Write-Host 'Getting Device Collections with Direct Membership Rules...' -ForegroundColor Yellow
    $collections = @(Get-CMDeviceCollection | Where-Object { $_.CollectionRules -like '*SMS_CollectionRuleDirect*' } | Select-Object Name, CollectionID, CollectionRules | Out-GridView -PassThru -Title 'Wait for all Collections to load, then select the Device Collections you want to convert. Use The ENTER Key or Mouse \ OK Button.')
}
if ($Choice_Number -eq '2') {
    Write-Host 'Getting Device Collections with Direct Membership Rules...' -ForegroundColor Yellow
    $collections = Get-CMDeviceCollection | Where-Object { $_.CollectionRules -like '*SMS_CollectionRuleDirect*' } | Select-Object Name, CollectionID, CollectionRules
}

if (!$collections) {
    Write-Host 'No Collections found, please run the script again...' -ForegroundColor Red
    Break
}


foreach ($collection in $collections) {

    if ($collection.CollectionRules -like '*SMS_CollectionRuleDirect*') {

        $conversionResult = New-Object -Type PSCustomObject
        $conversionResult | Add-Member -type NoteProperty -Name ID -Value $collection.CollectionID
        $conversionResult | Add-Member -type NoteProperty -Name Collection -Value $collection.Name

        Write-Host "The Collection $($collection.Name) contains Direct Members..." -ForegroundColor Cyan
        Write-Host
        Write-Host "Getting direct members for Collection $($collection.Name)..." -ForegroundColor Cyan
        $directMembers = Get-CMDeviceCollectionDirectMembershipRule -CollectionName $collection.Name

        Write-Host

        $membersArray = @()
        $conversionResultArray = @()

        foreach ($directMember in $directMembers) {
            Write-Host "Direct Member $($directMember.RuleName) found." -ForegroundColor Cyan
            $ccmGUID = (Get-CMDevice -ResourceId $directMember.ResourceID -Fast).SMSUniqueIdentifier
            if (!([string]::IsNullOrEmpty($ccmGUID))) {
                Write-Host "$($directMember.RuleName) has a GUID." -ForegroundColor Green
                $membersArray += $ccmGUID
                $conversionResultArray += $directMember.RuleName
                Clear-Variable -Name ccmGUID
            }
            else {
                Write-Host "$($directMember.RuleName) does not have a GUID." -ForegroundColor Yellow
            }
        }

        $members = '"{0}"' -f ($membersArray -join '","')
        $conversionResultMembers = '"{0}"' -f ($conversionResultArray -join '","')
        $conversionResult | Add-Member -type NoteProperty -Name Members -Value $conversionResultMembers

        $queryExpression = $queryStart + $members + $queryEnd

        Try {
            Write-Host
            Write-Host "Adding Query based rule to Collection $($collection.Name) to replace direct membership..." -ForegroundColor Cyan
            Write-Host
            Add-CMDeviceCollectionQueryMembershipRule -CollectionName $collection.Name -QueryExpression $queryExpression -RuleName $ruleName
            Write-Host 'Successfully added the query.' -ForegroundColor Green
            Write-Host
            $conversionResult | Add-Member -type NoteProperty -Name Success -Value True
            Write-Host 'Removing Direct Membership Rules' -ForegroundColor Cyan
            Write-Host
            foreach ($directMember in $directMembers) {
                Try {
                    Remove-CMDeviceCollectionDirectMembershipRule -CollectionName $collection.Name -ResourceID $directMember.ResourceID -Force
                    Write-Host "Successfully removed $($directMember.RuleName)." -ForegroundColor Green
                    Write-Host

                }
                Catch {
                    Write-Host "Failed to remove $($directMember.RuleName)." -ForegroundColor Red
                    Write-Host

                }
            }
        }
        Catch {
            Write-Host "Failed to convert Direct Membership to query for Collection $($collection.Name)" -ForegroundColor Red
            $conversionResult | Add-Member -type NoteProperty -Name Success -Value False
        }

        $conversionResults.Add($conversionResult) | Out-Null

    }
    else {
        Write-Host "The collection $($collection.Name) does not have direct membership." -ForegroundColor Yellow
    }

}

Write-Host
Write-Host 'Results of the Collection Conversion...' -ForegroundColor Green
$conversionResults