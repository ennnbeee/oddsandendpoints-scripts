$scriptName = 'RemoveBuiltInHPApps'
$removeApps = @(
    'HPJumpStarts'
    'HPPCHardwareDiagnosticsWindows'
    'HPPowerManager'
    'HPPrivacySettings'
    'HPSupportAssistant'
    'HPSureShieldAI'
    'HPSystemInformation'
    'HPQuickDrop'
    'HPWorkWell'
    'myHP'
    'HPDesktopSupportUtilities'
    'HPQuickTouch'
    'HPEasyClean'
    'HPSystemInformation'
    'HP Client Security Manager'
    'HP Connection Optimizer'
    'HP Documentation'
    'HP MAC Address Manager'
    'HP Notifications'
    'HP Presence Video'
    'HP System Default Settings'
    'HP Sure Click'
    'HP Sure Click Security Browser'
    'HP Sure Run'
    'HP Sure Recover'
    'HP Sure Sense'
    'HP Sure Sense Installer'
    'HP Wolf Security Application Support for Sure Sense'
    'HP Wolf Security Application Support for Windows'
    'HP Wolf Security'
    'HP Wolf Security - Console'
    'HP Security Update Service'
    'AD2F1837'
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
function Get-InstalledAppFromRegistry {
    param ([string]$DisplayName)
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($path in $registryPaths) {
        $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*$DisplayName*"
        }
        foreach ($app in $apps) {
            [PSCustomObject]@{
                DisplayName     = $app.DisplayName
                UninstallString = $app.UninstallString
                QuietUninstall  = $app.QuietUninstallString
                RegistryPath    = $path
            }
        }
    }
}

Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Starting App removal process"
foreach ($removeApp in $removeApps) {
    $appxPackage = Get-AppxPackage -AllUsers "*$removeApp*" -ErrorAction SilentlyContinue
    $appxProvisioningPackage = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp -ErrorAction SilentlyContinue
    $package = Get-Package -AllVersions | Where-Object { $_.Name -like "*$removeApp*" } -ErrorAction SilentlyContinue
    $registry = Get-InstalledAppFromRegistry -DisplayName $removeApp

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxPackage for $removeApp"
    if ($appxPackage) {
        try {
            Get-AppxPackage -AllUsers "*$removeApp*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appxPackage.PackageFullName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($appxPackage.PackageFullName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxPackage $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxProvisioningPackage for $removeApp"
    if ($appxProvisioningPackage) {
        try {
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appxProvisioningPackage.PackageName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($appxProvisioningPackage.PackageName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxProvisioningPackage $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding Package for $removeApp"
    if ($package) {
        try {
            Get-Package -AllVersions | Where-Object { $_.Name -like "*$removeApp*" } | Remove-Package -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($package.name)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($package.name)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find Package $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding Registry uninstall for $removeApp"
    if ($registry) {
        $appRegistry = Get-InstalledAppFromRegistry -DisplayName $AppName | Select-Object -First 1
        $appUninstallCmd = if ($appRegistry.QuietUninstall) { $appRegistry.QuietUninstall } else { $appRegistry.UninstallString }
        try {
            Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "$appUninstallCmd" -Wait -NoNewWindow
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appRegistry.DisplayName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($registry.DisplayName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find Registry uninstall for $removeApp"
    }

    # double loop to ensure all apps are removed, as some apps may not be removed on the first pass
    $appxPackage = Get-AppxPackage -AllUsers "*$removeApp*" -ErrorAction SilentlyContinue
    $appxProvisioningPackage = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp -ErrorAction SilentlyContinue
    $package = Get-Package -AllVersions | Where-Object { $_.Name -like "*$removeApp*" } -ErrorAction SilentlyContinue
    $registry = Get-InstalledAppFromRegistry -DisplayName $removeApp

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxPackage for $removeApp"
    if ($appxPackage) {
        try {
            Get-AppxPackage -AllUsers "*$removeApp*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appxPackage.PackageFullName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($appxPackage.PackageFullName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxPackage $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding AppxProvisioningPackage for $removeApp"
    if ($appxProvisioningPackage) {
        try {
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $removeApp | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appxProvisioningPackage.PackageName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($appxProvisioningPackage.PackageName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find AppxProvisioningPackage $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding Package for $removeApp"
    if ($package) {
        try {
            Get-Package -AllVersions | Where-Object { $_.Name -like "*$removeApp*" } | Remove-Package -ErrorAction SilentlyContinue
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($package.name)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($package.name)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find Package $removeApp"
    }

    Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Finding Registry uninstall for $removeApp"
    if ($registry) {
        $appRegistry = Get-InstalledAppFromRegistry -DisplayName $AppName | Select-Object -First 1
        $appUninstallCmd = if ($appRegistry.QuietUninstall) { $appRegistry.QuietUninstall } else { $appRegistry.UninstallString }
        try {
            Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "$appUninstallCmd" -Wait -NoNewWindow
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed App $($appRegistry.DisplayName)"
        }
        catch {
            Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Unable to remove App $($registry.DisplayName)"
        }
    }
    else {
        Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Could not find Registry uninstall for $removeApp"
    }
}

Write-LogEntry -Value "$(Get-Date -Format yyy.MM.dd-hh:mm:ss) - Removed Built in HP apps."
exit 0