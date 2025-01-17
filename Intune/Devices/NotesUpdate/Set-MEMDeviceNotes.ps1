[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)

Function Get-IntuneDeviceNotes {
    <#
    .SYNOPSIS
    Gets the notes of a device in intune.

    .DESCRIPTION
    Gets the notes property on a device in intune using the beta Graph api

    .PARAMETER DeviceName
    The name of the device that you want to get the notes field from as it appears in intune.

    .EXAMPLE
    Get-IntuneDeviceNotes -DeviceName TestDevice01

    .NOTES
    Must connect to the graph api first with Connect-MSGraph.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $DeviceName
    )
    Try {
        $DeviceID = (Get-IntuneManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop).id
    }
    Catch {
        Write-Error $_.Exception.Message
        break
    }
    $Resource = "deviceManagement/managedDevices('$deviceId')"
    $properties = 'notes'
    $uri = "https://graph.microsoft.com/beta/$($Resource)?select=$properties"
    Try {
        (Invoke-MSGraphRequest -HttpMethod GET -Url $uri -ErrorAction Stop).notes
    }
    Catch {
        Write-Error $_.Exception.Message
        break
    }
}
Function Set-IntuneDeviceNotes {
    <#
    .SYNOPSIS
    Sets the notes on a device in intune.

    .DESCRIPTION
    Sets the notes property on a device in intune using the beta Graph api

    .PARAMETER DeviceName
    The name of the device as it appears in intune.

    .PARAMETER Notes
    A string of the notes that you would like recorded in the notes field in intune.

    .EXAMPLE
    Set-IntuneDeviceNotes -DeviceName TestDevice01 -Notes "This is a note on the stuff and things for this device."

    .NOTES
    Must connect to the graph api first with Connect-MSGraph.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $DeviceName,
        [Parameter(Mandatory = $false)]
        [String]
        $Notes
    )
    Try {
        $DeviceID = (Get-IntuneManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop).id
    }
    Catch {
        Write-Error $_.Exception.Message
        break
    }
    If (![string]::IsNullOrEmpty($DeviceID)) {
        $Resource = "deviceManagement/managedDevices('$DeviceID')"
        $GraphApiVersion = 'Beta'
        $URI = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        $JSONPayload = @"
{
notes:"$Notes"
}
"@
        Try {
            Write-Verbose "$URI"
            Write-Verbose "$JSONPayload"
            Invoke-MSGraphRequest -HttpMethod PATCH -Url $uri -Content $JSONPayload -Verbose -ErrorAction Stop
        }
        Catch {
            Write-Error $_.Exception.Message
            break
        }
    }
}
Function Set-BulkIntuneDeviceNotes {
    <#
    .SYNOPSIS
    Captures and sets the notes for a list of Intune devices.

    .DESCRIPTION
    Gets and sets the notes property on a device in intune using the beta Graph api.

    .PARAMETER Device List
    The path to the csv file containing the names of the device that you want to get the notes field from as it appears in intune and the notes to be added.
    i.e.    Device,Notes
            ENB-13F278,Updated devices notes via script

    .EXAMPLE
    Set-BulkIntuneDeviceNotes -DeviceList "C:\Temp\Devices.csv"

    .NOTES
    You must connect to the graph api first with Connect-MSGraph.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $DeviceList
    )
    if (Test-Path -Path $DeviceList) {
        $Devices = Import-Csv $DeviceList
        foreach ($Device in $Devices) {
            # Add Date stamp to the new notes
            $NewNotes = $Device.Notes
            $Notes = New-Object -TypeName System.Collections.ArrayList
            $Notes.AddRange(@(
                    $NewNotes.trim(),
                    "`n"
                ))
            # Get existing device notes
            Try {
                $OldNotes = Get-IntuneDeviceNotes -DeviceName $Device.Device
                If ($OldNotes -match '\d' -or $OldNotes -match '\w') {
                    Write-Host "Existing notes $OldNotes found on $($Device.Device), adding to Notes variable..." -ForegroundColor Cyan
                    $Notes.AddRange(@(
                            $OldNotes.trim()
                        ))
                }
                else {

                }
            }
            Catch {
                Write-Host 'Unable to get device notes, ensure you are connected to MSGraph' -ForegroundColor Red
                Break
            }
            # Add the new notes, included the old ones
            Try {
                Set-IntuneDeviceNotes -DeviceName $Device.Device -Notes $Notes
                Write-Host "Notes successfully added to $($Device.Device)" -ForegroundColor Green
            }
            Catch {
                Write-Host 'Unable to set device notes, ensure you are connected to MSGraph' -ForegroundColor Red
                Break
            }
        }
    }
    else {
        Write-Host 'Unable to access the provided device list, please check the csv file and re-run the script.' -ForegroundColor red
        Break
    }
}

Connect-MSGraph

Set-BulkIntuneDeviceNotes