[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 1)][string[]]$Password,
    [Parameter(Mandatory = $true, Position = 2)][string[]]$Settings = @(),
    [Parameter(Mandatory = $true, Position = 3)][string[]]$Values = @()
)

$DetectionRegPath = 'HKLM:\SOFTWARE\IntuneHelper\DellBIOSProvider'
Start-Transcript -Path "$env:TEMP\Set-DellBIOSSettings.log" | Out-Null
$ScriptPath = (Get-Location).Path


if (!(Test-Path -Path $DetectionRegPath)) {
    New-Item -Path $DetectionRegPath -Force | Out-Null
}

if (Test-Path -Path "$env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider") {
    Write-Output "DellBIOSProvider folder already exists @ $env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider."
    Write-Output 'Deleting the folder...'
    Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider" -Recurse -Force
}
 
Write-Output "Copying DellBIOSProvider module to: $env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider"
Copy-Item -Path "$ScriptPath\DellBIOSProvider\" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\" -Recurse -Force

try {
    Import-Module 'DellBIOSProvider' -Force -Verbose -ErrorAction Stop
    Write-Output 'Importing the Dell BIOS Provider module'
}
catch {
    Write-Output "Error importing module: $_"
    exit 1
}

$AdminPassSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).CurrentValue
$BIOSSettings = Get-ChildItem -Path DellSmbios:\ | ForEach-Object {
    Get-ChildItem -Path @('DellSmbios:\' + $_.Category)  | Select-Object attribute, currentvalue, possiblevalues, PSChildName
}

[int]$max = $Settings.count
$NewBIOSSettings = for ($i = 0; $i -lt $max; $i++) {
    [PSCustomObject]@{
        Setting = $Settings[$i]
        Value   = $Values[$i]
    }
}

foreach ($NewBIOSSetting in $NewBIOSSettings) {
    $NewItemSetting = $NewBIOSSetting.Setting 
    $NewItemValue = $NewBIOSSetting.Value 
		
    Write-Output "Changing: $NewItemSetting > $NewItemValue"  
		
    foreach ($BIOSSetting in $BIOSSettings | Where-Object { $_.attribute -eq $NewItemSetting }) {
        $SettingAttribute = $BIOSSetting.attribute
        $SettingCategory = $BIOSSetting.PSChildName

        If (($AdminPassSet -eq $true)) {   
            Try {
                Set-Item -Path Dellsmbios:\$SettingCategory\$SettingAttribute -Value $NewItemValue -Password $Password
                Write-Output "New value for $SettingAttribute is $NewItemValue"
                New-ItemProperty -Path "$DetectionRegPath" -Name "$SettingAttribute" -Value "$NewItemValue" -Force | Out-Null		
            }
            Catch {
                Write-Output "Cannot change setting $SettingAttribute (Return code $_)"  																		
            }
        }
        Else {
            Try {
                Set-Item -Path Dellsmbios:\$SettingCategory\$SettingAttribute -Value $NewItemValue
                Write-Output "New value for $SettingAttribute is $NewItemValue"
                New-ItemProperty -Path "$DetectionRegPath" -Name "$SettingAttribute" -Value "$NewItemValue" -Force | Out-Null	
            }
            Catch {
                Write-Output"Cannot change setting $Attribute (Return code $_)"
            }						
        }        
    }  
}  

Stop-Transcript