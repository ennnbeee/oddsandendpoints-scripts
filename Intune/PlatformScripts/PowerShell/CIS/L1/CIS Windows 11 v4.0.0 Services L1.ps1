<##############################################################################

    CIS Microsoft Intune for Windows 11 Benchmark v4.0.0 Build Kit script
    Section #81 - System Services
    Level 1 (L1)

    The purpose of this script is to configure a system using the recommendations
    provided in the Benchmark, section(s), and profile level listed above to a
    hardened state consistent with a CIS Benchmark.

    The script can be tailored to the organization's needs such as by creating
    exceptions or adding additional event logging.

    This script can be deployed through various means, including Intune script
    manager, running it locally, or through any automation tool.

    Version: 1.10
    Updated: 24.Apr.2025 by jjarose

##############################################################################>

#Requires -RunAsAdministrator

$L1Services = @{
    'Computer Browser'                             = 'HKLM:\SYSTEM\CurrentControlSet\Services\Browser'
    'IIS Admin Service'                            = 'HKLM:\SYSTEM\CurrentControlSet\Services\IISADMIN'
    'Infrared monitor service'                     = 'HKLM:\SYSTEM\CurrentControlSet\Services\irmon'
    'LxssManager'                                  = 'HKLM:\SYSTEM\CurrentControlSet\Services\LxssManager'
    'Microsoft FTP Service'                        = 'HKLM:\SYSTEM\CurrentControlSet\Services\FTPSVC'
    'OpenSSH SSH Server'                           = 'HKLM:\SYSTEM\CurrentControlSet\Services\sshd'
    'Remote Procedure Call (RPC) Locator'          = 'HKLM:\SYSTEM\CurrentControlSet\Services\RpcLocator'
    'Routing and Remote Access'                    = 'HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess'
    'Simple TCP/IP LocalServices'                  = 'HKLM:\SYSTEM\CurrentControlSet\Services\simptcp'
    'Special Administration Console Helper'        = 'HKLM:\SYSTEM\CurrentControlSet\Services\sacsvr'
    'SSDP Discovery'                               = 'HKLM:\SYSTEM\CurrentControlSet\Services\SSDPSRV'
    'UPnP Device Host'                             = 'HKLM:\SYSTEM\CurrentControlSet\Services\upnphost'
    'Web Management Service'                       = 'HKLM:\SYSTEM\CurrentControlSet\Services\WMSvc'
    'Windows Media Player Network Sharing Service' = 'HKLM:\SYSTEM\CurrentControlSet\Services\WMPNetworkSvc'
    'Windows Mobile Hotspot Service'               = 'HKLM:\SYSTEM\CurrentControlSet\Services\icssvc'
    'World Wide Web Publishing Service'            = 'HKLM:\SYSTEM\CurrentControlSet\Services\W3SVC'
    'Xbox Accessory Management Service'            = 'HKLM:\SYSTEM\CurrentControlSet\Services\XboxGipSvc'
    'Xbox Live Auth Manager'                       = 'HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager'
    'Xbox Live Game Save'                          = 'HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave'
    'Xbox Live Networking Service'                 = 'HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc'
}

$DisabledCount = 0
$AlreadyDisabledCount = 0
$NotInstalledCount = 0

foreach ($service in $L1Services.GetEnumerator()) {
    $ServiceName = $service.Key
    $ServicePath = $service.Value

    if (Test-Path -LiteralPath $ServicePath) {
        $StartValue = (Get-ItemProperty -LiteralPath $ServicePath).Start

        if ($StartValue -and $StartValue -ne 4) {
            Set-ItemProperty -LiteralPath $ServicePath -Name 'Start' -Value 4
            Write-Host "Disabled service $ServiceName." -ForegroundColor Yellow
            $DisabledCount++
        }
        elseif ($StartValue -eq 4) {
            Write-Host "Service $ServiceName is already disabled." -ForegroundColor Green
            $AlreadyDisabledCount++
        }
    }
    else {
        Write-Host "Service $ServiceName is not installed." -ForegroundColor Green
        $NotInstalledCount++
    }
}

Write-Host "`nThis script configured $DisabledCount services as 'Disabled'." -ForegroundColor Cyan
Write-Host "$AlreadyDisabledCount services were already disabled and $NotInstalledCount are not installed." -ForegroundColor Green