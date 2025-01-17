#Script to fix the recovery partition for KB5028997 by /u/InternetStranger4You, updated by Nick Benton
#Mostly Powershell version of Microsoft's support article: https://support.microsoft.com/en-us/topic/kb5028997-instructions-to-manually-resize-your-partition-to-install-the-winre-update-400faa27-9343-461c-ada9-24c8229763bf
#Test in your own environment before running. Not responsible for any damages.

Try {
    #Run reagentc.exe /info and save the output
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = 'reagentc.exe'
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = '/info'
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()

    #Verify that disk and partition are listed in reagentc.exe /info. If blank, then something is wrong with WinRE
    if (($stdout.IndexOf('harddisk') -ne -1) -and ($stdout.IndexOf('partition') -ne -1)) {

        #Disable Windows recovery environment
        Start-Process 'reagentc.exe' -ArgumentList '/disable' -Wait -NoNewWindow
        #Get recovery disk number and partition number
        $diskNum = $stdout.substring($stdout.IndexOf('harddisk') + 8, 1)
        $recPartNum = $stdout.substring($stdout.IndexOf('partition') + 9, 1)

        #Resize partition before the recovery partition
        $size = Get-Disk $diskNum | Get-Partition -PartitionNumber ($recPartNum - 1) | Select-Object -ExpandProperty Size
        Get-Disk $diskNum | Resize-Partition -PartitionNumber ($recPartNum - 1) -Size ($size - 250MB)

        #Remove the recovery partition
        Get-Disk $diskNum | Remove-Partition -PartitionNumber $recPartNum -Confirm:$false

        #Create new partion with diskpart script
        $diskpartScriptPath = $env:TEMP
        $diskpartScriptName = 'ResizeREScript.txt'
        $diskpartScript = $diskpartScriptPath + '\' + $diskpartScriptName
        "sel disk $($diskNum)" | Out-File -FilePath $diskpartScript -Encoding utf8 -Force
        $PartStyle = Get-Disk $diskNum | Select-Object -ExpandProperty PartitionStyle
        if ($partStyle -eq 'GPT') {
            #GPT partition commands
            'create partition primary id=de94bba4-06d1-4d40-a16a-bfd50179d6ac' | Out-File -FilePath $diskpartScript -Encoding utf8 -Append -Force
            'gpt attributes =0x8000000000000001' | Out-File -FilePath $diskpartScript -Encoding utf8 -Append -Force
        }
        else {
            #MBR partition command
            'create partition primary id=27' | Out-File -FilePath $diskpartScript -Encoding utf8 -Append -Force
        }
        "format quick fs=ntfs label=`"Windows RE tools`"" | Out-File -FilePath $diskpartScript -Encoding utf8 -Append -Force
        Start-Process 'diskpart.exe' -ArgumentList "/s $($diskpartScriptName)" -Wait -NoNewWindow -WorkingDirectory $diskpartScriptPath

        #Enable the recovery environment
        Start-Process 'reagentc.exe' -ArgumentList '/enable' -Wait -NoNewWindow
        Write-Output 'Recovery Partition Extended Successfully.'
        Exit 0

    }
    else {
        Write-Output 'Recovery partition not found. Aborting script.'
        Exit 1
    }
}
Catch {
    Write-Output 'Unable to update Recovery Partition on the device.'
    Exit 2000
}
