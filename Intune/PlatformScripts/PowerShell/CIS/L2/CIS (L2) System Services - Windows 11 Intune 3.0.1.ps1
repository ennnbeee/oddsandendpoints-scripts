<##############################################################################

    CIS Microsoft Intune for Windows 11 Benchmark v3.0.1 Build Kit script
    Section #69 - System Services
    Level 2 (L2) - High Security/Sensitive Data Environment (limited functionality)

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

$L2Services = @(
    'BTAGService', # Bluetooth Audio Gateway Service
    'bthserv', # Bluetooth Support Service
    'MapsBroker', # Downloaded Maps Manager
    'lfsvc', # Geolocation Service
    'lltdsvc', # Link-Layer Topology Discovery Mapper
    'MSiSCSI', # Microsoft iSCSI Initiator Service
    'PNRPsvc', # Peer Name Resolution Protocol
    'p2psvc', # Peer Networking Grouping
    'p2pimsvc', # Peer Networking Identity Manager
    'PNRPAutoReg', # PNRP Machine Name Publication Service
    'Spooler', # Print Spooler
    'wercplsupport', # Problem Reports and Solutions Control Panel Support
    'RasAuto', # Remote Access Auto Connection Manager
    'SessionEnv', # Remote Desktop Configuration
    'TermService', # Remote Desktop LocalServices
    'UmRdpService', # Remote Desktop LocalServices UserMode Port Redirector
    'RemoteRegistry', # Remote Registry
    'LanmanServer', # Server
    'SNMP', # SNMP Service
    'WerSvc', # Windows Error Reporting Service
    'Wecsvc', # Windows Event Collector
    'WpnService', # Windows Push Notifications System Service
    'PushToInstall', # Windows PushToInstall Service
    'WinRM'            # Windows Remote Management
)

# Get current state on the services in the array above.
$LocalServices = Get-Service -Name $L2Services -ErrorAction SilentlyContinue

$DisabledCount = 0
$AlreadyDisabledCount = 0
$NotInstalledCount = 0

foreach ($service in $L2Services) {
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