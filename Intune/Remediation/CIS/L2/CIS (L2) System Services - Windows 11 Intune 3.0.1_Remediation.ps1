$cisServices = @(
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
    'WinRM' # Windows Remote Management
)

# Get current state on the services in the array above.
$localServices = Get-Service -Name $cisServices -ErrorAction SilentlyContinue
$notDisabled = 0

try {
    foreach ($service in $cisServices) {
        # Make sure service name in the list matches with local system services.
        # Added because of Computer Browser mismatch with "bowser" service
        $foundService = $localServices | Where-Object { $_.Name -eq $service }

        if ($foundService) {
            if ($foundService.StartType -ne 'Disabled') {
                $notDisabled++
                Set-Service $FoundService.Name -StartupType Disabled -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Output "Found $notDisabled service(s) that are now disabled."
    Exit 0
}
catch {
    Write-Output "Unable to disable $notDisabled service(s)."
    Exit 2000
}

