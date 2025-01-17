#Recovery Partition free size required for KB5028997
$freePartitionSpace = '250000000' #bytes

Try {

    $computerDisks = Get-PhysicalDisk
    foreach ($computerDisk in $computerDisks) {
        $diskPartitions = Get-Partition -DiskNumber $computerDisk.DeviceId -ErrorAction Ignore
        if ($diskPartitions.DriveLetter -contains 'C' -and $null -ne $diskPartitions) {
            $systemDrive = $computerDisk
        }
    }
    $recPartition = Get-Partition -DiskNumber $systemDrive.DeviceId | Where-Object { $_.Type -eq 'Recovery' }

    $recVolume = Get-Volume -Partition $recPartition

    if ($recVolume.SizeRemaining -le $freePartitionSpace) {
        Write-Output "Recovery Partition Free Space $($($recVolume.SizeRemaining) / 1000000) MB is smaller than required $($freePartitionSpace / 1000000) MB"
        Exit 1
    }
    else {
        Write-Output "Recovery Partition Free Space $($($recVolume.SizeRemaining) / 1000000) MB is larger than required $($freePartitionSpace / 1000000) MB"
        Exit 0
    }
}
Catch {
    Write-Output 'Recovery Partition not found.'
    Exit 2000
}