$scriptName = 'RemoveBuiltInApps'
$ErrorActionPreference = 'silentlycontinue'

$removeApps = @(
    #Unnecessary Windows 10/11 AppX Apps
    'Clipchamp.Clipchamp'
    'Microsoft.Copilot'
    'Microsoft.OutlookForWindows'
    'Microsoft.549981C3F5F10' #cortana
    'Microsoft.XboxGameCallableUI'
    'Microsoft.BingNews'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.Messaging'
    'Microsoft.Microsoft3DViewer'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.NetworkSpeedTest'
    'Microsoft.MixedReality.Portal'
    'Microsoft.News'
    'Microsoft.Office.Lens'
    'Microsoft.Office.OneNote'
    'Microsoft.Office.Sway'
    'Microsoft.OneConnect'
    'Microsoft.People'
    'Microsoft.Print3D'
    #"Microsoft.RemoteDesktop"
    'Microsoft.SkypeApp'
    'Microsoft.StorePurchaseApp'
    'Microsoft.Office.Todo.List'
    'Microsoft.Whiteboard'
    'Microsoft.WindowsAlarms'
    #"Microsoft.WindowsCamera"
    'microsoft.windowscommunicationsapps'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'MicrosoftTeams'
    'Microsoft.YourPhone'
    'Microsoft.XboxGamingOverlay_5.721.10202.0_neutral_~_8wekyb3d8bbwe'
    'Microsoft.GamingApp'
    'Microsoft.Todos'
    'Microsoft.PowerAutomateDesktop'
    'SpotifyAB.SpotifyMusic'
    'Disney.37853FC22B2CE'
    '*EclipseManager*'
    '*ActiproSoftwareLLC*'
    '*AdobeSystemsIncorporated.AdobePhotoshopExpress*'
    '*Duolingo-LearnLanguagesforFree*'
    '*PandoraMediaInc*'
    '*CandyCrush*'
    '*BubbleWitch3Saga*'
    '*Wunderlist*'
    '*Flipboard*'
    '*Twitter*'
    '*Facebook*'
    '*Spotify*'
    '*Minecraft*'
    '*Royal Revolt*'
    '*Sway*'
    '*Speed Test*'
    '*Dolby*'
    '*Office*'
    '*Disney*'
    '*gaming*'
    'MicrosoftCorporationII.MicrosoftFamily'
    'C27EB4BA.DropboxOEM*'
    '*DevHome*'
    #Optional: Typically not removed but you can if you need to for some reason
    #"*Microsoft.Advertising.Xaml_10.1712.5.0_x64__8wekyb3d8bbwe*"
    #"*Microsoft.Advertising.Xaml_10.1712.5.0_x86__8wekyb3d8bbwe*"
    '*Microsoft.BingWeather*'
    #"*Microsoft.MSPaint*"
    #'*Microsoft.MicrosoftStickyNotes*'
    #"*Microsoft.Windows.Photos*"
    #"*Microsoft.WindowsCalculator*"
)
function Write-LogEntry {
    param(
        [parameter(Mandatory = $true, HelpMessage = 'Value added to the RemovedApps.log file.')]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory = $false, HelpMessage = 'Name of the log file that the entry will written to.')]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = 'RemovedApps.log'
    )
    # Determine log file location
    $logFilePath = Join-Path -Path $env:ProgramData\Microsoft\IntuneManagementExtension\Logs -ChildPath "$scriptName.log"

    # Add value to log file
    try {
        Out-File -InputObject $Value -Append -NoClobber -Encoding Default -FilePath $logFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $scriptName file"
    }
}

Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Starting App removal process"

foreach ($removeApp in $removeApps) {

    $appxPackage = Get-AppxPackage -Name $removeApp -AllUsers -ErrorAction SilentlyContinue
    $appxProvisioningPackage = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp -ErrorAction SilentlyContinue

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxPackage for $removeApp"
    if ($appxPackage) {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removing App $($appxPackage.PackageFullName)"
        Get-AppxPackage -AllUsers -Name $removeApp | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxPackage $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxProvisioningPackage for $removeApp"
    if ($appxProvisioningPackage) {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removing App $($appxProvisioningPackage.PackageName)"
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxProvisioningPackage $removeApp"
    }

    $appxPackage = Get-AppxPackage -Name $removeApp -AllUsers -ErrorAction SilentlyContinue
    $appxProvisioningPackage = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp -ErrorAction SilentlyContinue

    if ($appxPackage) {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removing App $($appxPackage.PackageFullName)"
        Get-AppxPackage -AllUsers -Name $removeApp | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
    if ($appxProvisioningPackage) {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removing App $($appxProvisioningPackage.PackageName)"
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed Built in apps."
Exit 0