Try {
    $filePath = "$env:windir\system32\CompatTelRunner.exe"
    $argumentList = "-m:appraiser.dll -f:DoScheduledTelemetryRun"

    if (Test-Path -Path $filePath){
        Start-Process -WindowStyle Hidden -FilePath $filePath -ArgumentList $argumentList -Wait
        Write-Output "App Compat Assessment started"
        Exit 0
    }
    else {
        Write-Output "Unable to start App Compat Assessment"
        Exit 1
    }

}
Catch {
    Write-Error $_.Exception
    Exit 2000
}