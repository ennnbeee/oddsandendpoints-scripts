$cisServices = @(
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
    'XboxNetApiSvc' # Xbox Live Networking Service
)

# Get current state on the services in the array above.
$localServices = Get-Service -Name $cisServices -ErrorAction SilentlyContinue
$notDisabled = 0

foreach ($cisService in $cisServices) {
    # Make sure service name in the list matches with local system services.
    # Added because of Computer Browser mismatch with "bowser" service
    $foundService = $localServices | Where-Object { $_.Name -eq $cisService }

    if ($foundService) {
        if ($foundService.StartType -ne 'Disabled') {
            $notDisabled++
        }
    }
}

if ($notDisabled -gt 0) {
    Write-Output "Found $notDisabled service(s) that should be disabled for CIS Level 1."
    Exit 1
}
else {
    Write-Output "All required servicess are disabled for CIS Level 1."
    Exit 0
}