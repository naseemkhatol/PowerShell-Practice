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
        TotalSizeGB = $Drive.Size / 1GB
        FreeSpaceGB = $Drive.SizeRemaining / 1GB
        FreeSpacePercentage = $FreeSpacePercentage
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
$DiskReport | select-object DriveLetter,
    @{Name="TotalSizeGB"; Expression={"{0:N2}" -f ($_.TotalSizeGB)}},
    @{Name="FreeSpaceGB"; Expression={"{0:N2}" -f ($_.FreeSpaceGB)}},
    @{Name="FreeSpacePercentage"; Expression={"{0:P2}" -f ($_.FreeSpacePercentage)}},
    DiskStatus

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
        TotalMemoryGB = $TotalMemoryGB
        FreeMemoryGB = $FreeMemoryGB
        UsedMemoryGB = $UsedMemoryGB
        UsedMemoryPercentage = $UsedMemoryPercentage
        MemoryStatus = $MemoryStatus
    }
    return $MemoryReport
}
$MemStatus =Get-MemoryHealth
$MemStatus | select-object @{Name="TotalMemoryGB"; Expression={"{0:N2}" -f ($_.TotalMemoryGB)}},
    @{Name="FreeMemoryGB"; Expression={"{0:N2}" -f ($_.FreeMemoryGB)}},
    @{Name="UsedMemoryGB"; Expression={"{0:N2}" -f ($_.UsedMemoryGB)}},
    @{Name="UsedMemoryPercentage"; Expression={"{0:P2}" -f ($_.UsedMemoryPercentage)}},
    MemoryStatus

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
            MemoryUsagePercentage = $MemoryHealth.UsedMemoryPercentage
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

$PCHealthReports | select-object ComputerName, DiskLetter, DiskStatus, 
@{Name="DiskFreeSpaceGB"; Expression={"{0:N2}" -f ($_.DiskFreeSpaceGB)}}, MemoryStatus, 
@{Name="MemoryUsagePercentage"; Expression={"{0:P2}" -f ($_.MemoryUsagePercentage)}} | ft -AutoSize | Out-Host

"===================== Disk Equation ======================"
$DiskReport | Where FreeSpaceGB -lt 250 | Sort FreeSpaceGB | ForEach-Object {
    Write-Host "Drive: $($_.DriveLetter) has $("{0:N2}" -f $_.FreeSpaceGB) GB free"
}


"===================== Service Health Report======================================"

Function Get-ServiceHealth {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ServiceName
    )
    Try{
        $Service= Get-Service -Name $ServiceName -ErrorAction Stop

        $ServiceReport= [PSCustomObject]@{
            Name=$Service.Name
            DisplayName=$Service.DisplayName
            Status=$Service.Status
            StartType=$Service.StartType
        }
        Return $ServiceReport         
    }
    catch {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $ErrorMessage = "$Timestamp | ERROR | Service '$ServiceName' was not found"
        Write-Host $ErrorMessage
        Add-Content -Path ".\ServiceHealth.log" -Value $ErrorMessage
        Return
    }
}

$Services = @(
    "Spooler"
    "wuauserv"
    "BITS"
    "sppsvc"
    "edgeupdate"
    "WinRM"
    "ewe"
)

$ServiceReports = @()

ForEach ($Service in $Services)
    {
        $Report = Get-ServiceHealth -ServiceName $Service
        If ($Report) 
        {$ServiceReports += $Report}
    }

$StoppedServices = $ServiceReports | Where-Object Status -eq "Stopped"
$StoppedAutomaticServices = $ServiceReports | Where-Object {$_.Status -eq "Stopped" -and $_.StartType -eq "Automatic"}

If ($StoppedAutomaticServices.Count -eq 0) {
    $ServiceHealth = "HEALTHY"
}
ElseIf ($StoppedAutomaticServices.Count -le 2) {
    $ServiceHealth = "WARNING"
}
Else {
    $ServiceHealth = "CRITICAL"
}

Write-Host "Service Health: $ServiceHealth"

" "
Write-Host "Total Services Checked: $($ServiceReports.count)"
Write-Host "Stopped Services: $($StoppedServices.Count)" 
Write-Host "Automatic Services that're Stopped: $($StoppedAutomaticServices.Count)"
" "
Write-Host "Problem Services: Services that are automatic but stopped:"
$StoppedAutomaticServices | 
    Select-Object Name, DisplayName, status, starttype| ft


$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$Message = "$Timestamp | Services Checked: $($ServiceReports.Count) | Stopped: $($StoppedServices.Count) | Automatic Stopped: $($StoppedAutomaticServices.Count) | Service Health: $ServiceHealth"

Add-Content -Path ".\ServiceHealth.log" -Value $Message

Write-Host ""
Write-Host "==================== Overall Health ===================="

# Determine Overall Disk Health
if ($DiskReport.DiskStatus -contains "CRITICAL") {
    $OverallDiskHealth = "CRITICAL"
}
elseif ($DiskReport.DiskStatus -contains "WARNING") {
    $OverallDiskHealth = "WARNING"
}
else {
    $OverallDiskHealth = "HEALTHY"
}

# Determine Overall PC Health
if ($OverallDiskHealth -eq "CRITICAL" -or
    $MemStatus.MemoryStatus -eq "CRITICAL" -or
    $ServiceHealth -eq "CRITICAL") {

    $OverallHealth = "CRITICAL"
}
elseif ($OverallDiskHealth -eq "WARNING" -or
        $MemStatus.MemoryStatus -eq "WARNING" -or
        $ServiceHealth -eq "WARNING") {

    $OverallHealth = "WARNING"
}
else {
    $OverallHealth = "HEALTHY"
}

Write-Host ""
Write-Host "===== PC HEALTH SUMMARY ====="
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "Disk Health: $OverallDiskHealth"
Write-Host "Memory Health: $($MemStatus.MemoryStatus)"
Write-Host "Service Health: $ServiceHealth"
Write-Host "Overall PC Health: $OverallHealth"
