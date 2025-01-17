Try {
    $registry = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $setting = 'AutoAdminLogon'
    # Checks if the key and if the string value AutoAdminLogon exists
    Try {
        $value = Get-ItemPropertyValue -Path $registry -Name $setting
    }
    Catch {
        Write-Warning "$setting not configured."
        Exit 1
    }

    # if the key and dword exist checks the value.
    if ($value -ne '0') {
        Write-Warning "$setting enabled."
        Exit 1
    }
    else {
        Write-Output "$setting disabled."
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}