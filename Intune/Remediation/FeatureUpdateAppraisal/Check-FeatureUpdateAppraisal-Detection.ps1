$schedule = 36 # update based on the remediation schedule
$featureUpdate = 'GE24H2' # Windows 11 24H2
#$featureUpdate = 'NI23H2' # Windows 11 23H2

Try {
    $registry = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers\$featureUpdate"
    # Checks if the key exists and the last run of the App Compat
    Try {
        $lastRun = Get-ItemPropertyValue -Path $registry -Name TimestampEpochString -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Warning "App Compat not run for Windows 11 $featureUpdate"
        Exit 1
    }

    # if the key and dword exist checks the last run time
    $nowLessHours = Get-Date $((Get-Date).AddHours(-$schedule)) -UFormat +%s
    if ($lastRun -lt $nowLessHours) {
        Write-Warning "App Compat not run in last $schedule hours"
        Exit 1
    }
    else {
        Write-Output "App Compat run in last $schedule hours"
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}