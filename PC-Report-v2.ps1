Function Get-ComputerName {
    Write-Host "Computer Name: $env:ComputerName"
}
Get-ComputerName

Write-Host "===== Disk Health Report ====="

Function Get-DiskHealth {
    Param([Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    $Drive = Get-Volume -DriveLetter $DriveLetter
    $FreeSpacePercentage = ($Drive.SizeRemaining / $Drive.Size)

    If ($FreeSpacePercentage -lt 0.10) {
        $DiskStatus = "CRITICAL"
    }
    ElseIf ($FreeSpacePercentage -lt 0.20) {
        $DiskStatus = "WARNING"
    }
    Else {
        $DiskStatus = "HEALTHY"
    }
    $DiskReport = [PSCustomObject]@{
        DriveLetter= $driveLetter
        TotalSize = $("{0:N2}" -f ($Drive.Size / 1GB))
        FreeSpace = $("{0:N2}" -f ($Drive.SizeRemaining / 1GB))
        FreeSpacePercentage = $("{0:P2}" -f ($FreeSpacePercentage))
        DiskStatus = $DiskStatus
    }
    return $DiskReport
}

$Status = Get-DiskHealth

$Status | fl

Write-Host "======Memory Health Report======"
Function Get-MemoryHealth {
    $Memory = Get-CimInstance Win32_OperatingSystem
    $TotalMemory = $Memory.TotalVisibleMemorySize / 1MB
    $FreeMemory = $Memory.FreePhysicalMemory / 1MB
    $UsedMemory = $TotalMemory - $FreeMemory
    $UsedMemoryPercentage = ($UsedMemory / $TotalMemory)

    If ($UsedMemoryPercentage -gt 0.90) {
        $MemoryStatus = "CRITICAL"
    }
    ElseIf ($UsedMemoryPercentage -gt 0.80) {
        $MemoryStatus = "WARNING"
    }
    Else {
        $MemoryStatus = "HEALTHY"
    }
    
    $MemoryReport = [PSCustomObject]@{
        TotalMemory = "{0:N2}" -f $TotalMemory
        FreeMemory = "{0:N2}" -f $FreeMemory
        UsedMemory = "{0:N2}" -f $UsedMemory
        UsedMemoryPercentage = "{0:P2}" -f $UsedMemoryPercentage
        MemoryStatus = $MemoryStatus
    }
    return $MemoryReport
}
$MemStatus =Get-MemoryHealth
$MemStatus | fl

Write-Host "===== PC Health Report ====="

Function Get-PCHealthReport {
    $DiskHealth = Get-DiskHealth -DriveLetter "C"
    $MemoryHealth = Get-MemoryHealth
    $PCHealthReport = [PSCustomObject]@{
        ComputerName = $env:ComputerName
        DiskStatus = $DiskHealth.DiskStatus
        DiskFreeSpace = $DiskHealth.FreeSpace
        MemoryStatus = $MemoryHealth.MemoryStatus
        MemoryUsage = $MemoryHealth.UsedMemoryPercentage
    }   
    return $PCHealthReport
}

$PCHealthReport = Get-PCHealthReport
$PCHealthReport | fl
