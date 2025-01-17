Try {
    $registry = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $setting = 'AutoAdminLogon'
    $path = Test-Path $registry
    # checks if the key exists, if not creates the key and AutoAdminLogon string.
    if ($path -eq $false) {
        New-Item -Path $registry -Force | Out-Null
        New-ItemProperty -Path $registry -Name $setting  -Value 0 -PropertyType String -Force | Out-Null
        Write-Output "$setting disabled."
        Exit 0
    }
    else {
        # checks if the AutoAdminLogon string exists, if not creates it.
        Try {
            # if the AutoAdminLogon dword exists updates it.
            Get-ItemPropertyValue -Path $registry -Name $setting
            Set-ItemProperty -Path $registry -Name $setting -Value 0
            Write-Output "$setting disabled."
            Exit 0
        }
        Catch {
            New-ItemProperty -Path $registry -Name $setting -Value 0 -PropertyType string -Force | Out-Null
            Write-Output "$setting disabled."
            Exit 0
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}