<##############################################################################

    CIS Microsoft Intune for Windows 11 Benchmark v3.0.1 Build Kit script
    Section #69 - System Services
    Level 1 (L1) - Corporate/Enterprise Environment (general use)

    The purpose of this script is to configure a system using the recommendations
    provided in the Benchmark, section(s), and profile level listed above to a
    hardened state consistent with a CIS Benchmark.

    The script can be tailored to the organization's needs such as by creating
    exceptions or adding additional event logging.

    This script can be deployed through various means, including Intune script
    manager, running it locally, or through any automation tool.

    Version: 1.0
    Updated: 12.Feb.2024 by ceifert

##############################################################################>

#Requires -RunAsAdministrator

$L1Services = @(
    'Browser', # Computer Browser
    'IISADMIN', # IIS Admin Service
    'irmon', # Infrared monitor service
    'SharedAccess', # Internet Connection Sharing
    'LxssManager', # LxssManager
    'FTPSVC', # Microsoft FTP Service
    'sshd', # OpenSSH SSH Server
    'RpcLocator', # Remote Procedure Call (RPC) Locator
    'RemoteAccess', # Routing and Remote Access
    'simptcp', # Simple TCP/IP LocalServices$LocalServices
    'sacsvr', # Special Administration Console Helper
    'SSDPSRV', # SSDP Discovery
    'upnphost', # UPnP Device Host
    'WMSvc', # Web Management Service
    'WMPNetworkSvc', # Windows Media Player Network Sharing Service
    'icssvc', # Windows Mobile Hotspot Service
    'W3SVC', # World Wide Web Publishing Service
    'XboxGipSvc', # Xbox Accessory Management Service
    'XblAuthManager', # Xbox Live Auth Manager
    'XblGameSave', # Xbox Live Game Save
    'XboxNetApiSvc'     # Xbox Live Networking Service
)

# Get current state on the services in the array above.
$LocalServices = Get-Service -Name $L1Services -ErrorAction SilentlyContinue

$DisabledCount = 0
$AlreadyDisabledCount = 0
$NotInstalledCount = 0

foreach ($service in $L1Services) {
    # Make sure service name in the list matches with local system services.
    # Added because of Computer Browser mismatch with "bowser" service
    $FoundService = $LocalServices | Where-Object { $_.Name -eq $service }

    if ($FoundService) {
        if ($FoundService.StartType -ne 'Disabled') {
            Set-Service $FoundService.Name -StartupType Disabled -Verbose
            $DisabledCount++

        }
        else {
            Write-Host "Service $($FoundService.DisplayName) is already disabled." -ForegroundColor Green
            $AlreadyDisabledCount++
        }
    }
    else {
        Write-Host "Service $service not installed." -ForegroundColor Green
        $NotInstalledCount++
    }
}

Write-Host "`nThis script configured $DisabledCount services as 'Disabled'." -ForegroundColor Cyan
Write-Host "$AlreadyDisabledCount services were already disabled and $NotInstalledCount are not installed." -ForegroundColor Green