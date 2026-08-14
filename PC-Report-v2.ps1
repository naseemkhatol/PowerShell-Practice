Function Get-ComputerName {
    Write-Host "Computer Name: $env:ComputerName"
}
Get-ComputerName

" "
Write-Host "===================== Disk Health Report ======================="

Function Get-DiskHealth {
    Param([Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
   Try {
        $Drive = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
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
        TotalSizeGB = $("{0:N2}" -f ($Drive.Size / 1GB))
        FreeSpaceGB = $("{0:N2}" -f ($Drive.SizeRemaining / 1GB))
        FreeSpacePercentage = $("{0:P2}" -f ($FreeSpacePercentage))
        DiskStatus = $DiskStatus
        }
    
    return $DiskReport
    }
    Catch {
        Write-Host "Error: Drive Letter $DriveLetter Not Found"
        Write-Host $_.Exception.Message
        return
    } 
}

$DriveLetters = @("C", "B", "D")
$DiskReport = @()

ForEach ($Drive in $DriveLetters) {
    $Status = Get-DiskHealth -DriveLetter $Drive
    If ($Status) {
        $DiskReport += $Status
    }
}
$DiskReport | ft

Write-Host "===================== Memory Health Report ======================"
Function Get-MemoryHealth {
    $Memory = Get-CimInstance Win32_OperatingSystem
    $TotalMemoryGB = $Memory.TotalVisibleMemorySize / 1MB
    $FreeMemoryGB = $Memory.FreePhysicalMemory / 1MB
    $UsedMemoryGB = $TotalMemoryGB - $FreeMemoryGB
    $UsedMemoryPercentage = ($UsedMemoryGB / $TotalMemoryGB)

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
        TotalMemoryGB = "{0:N2}" -f $TotalMemoryGB
        FreeMemoryGB = "{0:N2}" -f $FreeMemoryGB
        UsedMemoryGB = "{0:N2}" -f $UsedMemoryGB
        UsedMemoryPercentage = "{0:P2}" -f $UsedMemoryPercentage
        MemoryStatus = $MemoryStatus
    }
    return $MemoryReport
}
$MemStatus =Get-MemoryHealth
$MemStatus | fl

Write-Host "===================== PC Health Report ======================"

Function Get-PCHealthReport 
{
    Param([Parameter(Mandatory=$True)]
        [string]$DriveLetter 
    )
    Try 
    {
        $DiskHealth = Get-DiskHealth -DriveLetter $driveLetter
        $MemoryHealth = Get-MemoryHealth
        $PCHealthReport = [PSCustomObject]@{
            ComputerName = $env:ComputerName
            DiskLetter = $DiskHealth.DriveLetter
            DiskStatus = $DiskHealth.DiskStatus
            DiskFreeSpaceGB = $DiskHealth.FreeSpaceGB
            MemoryStatus = $MemoryHealth.MemoryStatus
            MemoryUsageercentage = $MemoryHealth.UsedMemoryPercentage
        }   
        return $PCHealthReport
    }
    Catch
    {
        Write-Host "Error: Unable to generate PC Health Report"
        Write-Host $_.Exception.Message
        Return
    }
}

$PCHealthReports = @()

ForEach ($Drive in $DriveLetters) {
    $Report = Get-PCHealthReport -DriveLetter $Drive
    If ($Report) {
        $PCHealthReports += $Report
    }
}
$PCHealthReports | ft

