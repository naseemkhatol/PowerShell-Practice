<#
.SYNOPSIS
Hydro One Tier 1 Device Health Audit Report

.DESCRIPTION
Collects device health, performance, security, update, network,
and Active Directory information to assist Tier 1 support
engineers with troubleshooting and health assessments.

.AUTHOR
Naseem Khatol

.VERSION
1.0

.CREATED
September 2026

.REQUIREMENTS
- Windows PowerShell 5.1 or later
- Administrative privileges recommended
- Domain connectivity recommended
- Active Directory module (optional)

.OUTPUT
Formatted Device Health Report

.NOTES
Created for Hydro One Tier 1 Support Operations.
Designed to provide a quick health assessment of a Windows device.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ComputerName
)

function Get-RiskLevel {
    param([int]$Score)

    if ($Score -lt 20) { "Low" }
    elseif ($Score -lt 50) { "Medium" }
    elseif ($Score -lt 80) { "High" }
    else { "Critical" }
}
function Write-Checkpoint {
    param([string]$Message)

    Write-Host ""
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [INFO] $Message..." -ForegroundColor Green
}


Write-Host ""
Write-Host "Collecting information from $ComputerName..." -ForegroundColor Cyan
Write-Host ""

Write-Checkpoint "Getting Computer Information"

try {

    # =====================================================
    # SYSTEM INFORMATION
    # =====================================================

    $ComputerSystem = Get-CimInstance Win32_ComputerSystem
    $BIOS = Get-CimInstance Win32_BIOS
    $OS = Get-CimInstance Win32_OperatingSystem
    $CPU = Get-CimInstance Win32_Processor
    $Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

    $Adapters = Get-NetAdapter | Sort-Object Status -Descending

    $IPAddresses = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "169.254*" -and
            $_.IPAddress -ne "127.0.0.1"
        }

    $Services = Get-Service
    Write-Checkpoint "Getting Memory and Disk Status"
    # =====================================================
    # MEMORY
    # =====================================================

    $TotalRAMGB = $OS.TotalVisibleMemorySize / 1MB
    $FreeRAMGB = $OS.FreePhysicalMemory / 1MB

    $MemoryUsedPercent =
        (($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory) /
            $OS.TotalVisibleMemorySize) * 100

    # =====================================================
    # DISK
    # =====================================================

    $DiskFreePercent =
        ($Disk.FreeSpace / $Disk.Size) * 100

    # =====================================================
    # UPTIME
    # =====================================================

    $Uptime = (Get-Date) - $OS.LastBootUpTime

    # =====================================================
    # BITLOCKER
    # =====================================================
try {

    $BitLockerText = manage-bde -status C: | Out-String

    if ($BitLockerText -match "Protection Status:\s+Protection On") {

        $BitLockerProtection = "Enabled"
        $BitLockerVolumeStatus = "Protected"

    }
    elseif ($BitLockerText -match "Protection Status:\s+Protection Off") {

        $BitLockerProtection = "Disabled"
        $BitLockerVolumeStatus = "Unprotected"

    }
    else {

        $BitLockerProtection = "Not Configured"
        $BitLockerVolumeStatus = "Unknown"

    }

}
catch {

    $BitLockerProtection = "Unknown"
    $BitLockerVolumeStatus = "Unknown"

}

    # =====================================================
    # WINDOWS UPDATES
    # =====================================================

    try {

        $LastHotFix = Get-HotFix |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 1

        $LastInstalledUpdate = $LastHotFix.HotFixID

        $LastUpdateDate = $LastHotFix.InstalledOn

        $DaysSinceLastUpdate =
            (New-TimeSpan -Start $LastHotFix.InstalledOn -End (Get-Date)).Days
    }
    catch {

        $LastInstalledUpdate = "Unknown"
        $LastUpdateDate = "Unknown"
        $DaysSinceLastUpdate = "Unknown"
    }

    # =====================================================
    # BATTERY
    # =====================================================

    try {

        $Battery = Get-CimInstance Win32_Battery

        if ($Battery) {

        $BatteryStatus =
        switch ($Battery.BatteryStatus) {

        1 {"Discharging"}
        2 {"Connected to AC"}
        3 {"Fully Charged"}
        4 {"Low"}
        5 {"Critical"}
        default {"Unknown"}
        }

        $BatteryChemistry =
        switch ($Battery.Chemistry) {

        3 {"Lithium-Ion"}
        6 {"Nickel Metal Hydride"}
        default {"Unknown"}
        }

        }
        else {

            $BatteryStatus = "No Battery Detected"
            $BatteryChemistry = "N/A"

        }

    }
    catch {

        $BatteryStatus = "Unknown"
        $BatteryChemistry = "Unknown"

    }

    # =====================================================
    # ENTRA / DOMAIN STATUS
    # =====================================================

    try {

        $DSReg = dsregcmd /status

        $AzureAdJoined =
            (($DSReg | Select-String "AzureAdJoined").Line -split ":")[1].Trim()

        $DomainJoined =
            (($DSReg | Select-String "DomainJoined").Line -split ":")[1].Trim()

        $DeviceId =
            (($DSReg | Select-String "DeviceId").Line -split ":")[1].Trim()

    }
    catch {

        $AzureAdJoined = "Unknown"
        $DomainJoined = "Unknown"
        $DeviceId = "Unknown"

    }

# =====================================================
# ACTIVE DIRECTORY STATUS
# =====================================================

try {

    Import-Module ActiveDirectory -ErrorAction Stop

    $ADComputer = Get-ADComputer $ComputerName -Properties Enabled, DistinguishedName

    $ADStatus = if ($ADComputer.Enabled) {
        "Enabled"
    }
    else {
        "Disabled"
    }

    $OUPath = (
        (($ADComputer.DistinguishedName -split ",") |
            Where-Object { $_ -like "OU=*" } |
            ForEach-Object { $_ -replace "^OU=","" }
        ) -join " > "
    )

}
catch {
    Write-Host "AD Error:" $_.Exception.Message -ForegroundColor Red
    $ADStatus = "Unable to Query"
    $OUPath = "Unknown"

}


    # =====================================================
    # STOPPED AUTOMATIC SERVICES
    # =====================================================

    $AutoStopped = $Services | Where-Object {
        $_.Status -eq 'Stopped' -and
        $_.StartType -eq 'Automatic'
    }

    # =====================================================
    # DISK RISK
    # =====================================================

    if ($DiskFreePercent -gt 30) {
        $DiskRisk = 0
        $DiskHealth = "Healthy"
    }
    elseif ($DiskFreePercent -gt 20) {
        $DiskRisk = 10
        $DiskHealth = "Healthy"
    }
    elseif ($DiskFreePercent -gt 10) {
        $DiskRisk = 30
        $DiskHealth = "Warning"
    }
    elseif ($DiskFreePercent -gt 5) {
        $DiskRisk = 60
        $DiskHealth = "High Risk"
    }
    else {
        $DiskRisk = 100
        $DiskHealth = "Critical"
    }

    # =====================================================
    # MEMORY RISK
    # =====================================================

    if ($MemoryUsedPercent -lt 70) {
        $MemoryRisk = 0
        $MemoryHealth = "Healthy"
    }
    elseif ($MemoryUsedPercent -lt 80) {
        $MemoryRisk = 15
        $MemoryHealth = "Healthy"
    }
    elseif ($MemoryUsedPercent -lt 90) {
        $MemoryRisk = 40
        $MemoryHealth = "Warning"
    }
    else {
        $MemoryRisk = 80
        $MemoryHealth = "Critical"
    }

    # =====================================================
    # CPU RISK
    # =====================================================

    if ($CPU.LoadPercentage -lt 50) {
        $CPURisk = 0
        $CPUHealth = "Healthy"
    }
    elseif ($CPU.LoadPercentage -lt 70) {
        $CPURisk = 20
        $CPUHealth = "Healthy"
    }
    elseif ($CPU.LoadPercentage -lt 90) {
        $CPURisk = 50
        $CPUHealth = "Warning"
    }
    else {
        $CPURisk = 80
        $CPUHealth = "Critical"
    }

    # =====================================================
    # SERVICE RISK
    # =====================================================

    if ($AutoStopped.Count -eq 0) {
        $ServiceRisk = 0
    }
    elseif ($AutoStopped.Count -le 5) {
        $ServiceRisk = 20
    }
    else {
        $ServiceRisk = 50
    }
    Write-Checkpoint "Getting Network and Security Information"
    # =====================================================
    # UPTIME RISK
    # =====================================================

    if ($Uptime.TotalDays -lt 14) {
        $UptimeRisk = 0
    }
    elseif ($Uptime.TotalDays -lt 30) {
        $UptimeRisk = 10
    }
    elseif ($Uptime.TotalDays -lt 90) {
        $UptimeRisk = 25
    }
    else {
        $UptimeRisk = 50
    }

    # =====================================================
    # OVERALL RISK
    # =====================================================

    $OverallRisk = ($DiskRisk * 0.35 +
        ($MemoryRisk * 0.25) +
        ($CPURisk * 0.15) +
        ($ServiceRisk * 0.15) +
        ($UptimeRisk * 0.10)
    )

    # =====================================================
    # RECOMMENDATIONS
    # =====================================================
    Write-Checkpoint "Analyzing Device Health"
    $Recommendations = @()

    if ($DiskFreePercent -lt 20) {
        $Recommendations += "Disk is running low on free space."
    }

    if ($MemoryUsedPercent -gt 80) {
        $Recommendations += "Memory utilization is high."
    }

    if ($CPU.LoadPercentage -gt 80) {
        $Recommendations += "CPU utilization is high."
    }

    if ($AutoStopped.Count -gt 0) {
        $Recommendations += "$($AutoStopped.Count) automatic services are stopped."
    }

    if ($Uptime.TotalDays -gt 30) {
        $Recommendations += "Device has not been rebooted recently."
    }

    if ($DaysSinceLastUpdate -is [int] -and $DaysSinceLastUpdate -gt 45) {
        $Recommendations += "Windows updates may be outdated."
    }

    if ($BitLockerProtection -ne 1) {
        $Recommendations += "BitLocker protection may not be enabled."
    }

    if ($AzureAdJoined -ne "YES") {
        $Recommendations += "Device is not Entra joined."
    }

    if ($Recommendations.Count -eq 0) {
        $Recommendations += "No major issues detected."
    }

    # =====================================================
    # REPORT
    # =====================================================
    
    Write-Checkpoint "Generating Audit Report"

    $Report = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        CurrentUser = $ComputerSystem.UserName
        LastLoggedOnUser = $ComputerSystem.UserName
        Manufacturer = $ComputerSystem.Manufacturer
        Model = $ComputerSystem.Model
        SerialNumber = $BIOS.SerialNumber

        WindowsVersion = $OS.Caption
        OSVersion = $OS.Version
        BuildNumber = $OS.BuildNumber
        InstallDate = $OS.InstallDate
        LastBootTime = $OS.LastBootUpTime
        UptimeDays = "{0:N1}" -f $Uptime.TotalDays

        CPUName = $CPU.Name
        CPUCores = $CPU.NumberOfCores
        LogicalProcessors = $CPU.NumberOfLogicalProcessors
        CPULoad = "$($CPU.LoadPercentage)%"
        CPURisk = "$CPURisk%"
        CPUHealth = $CPUHealth

        TotalRAMGB = "{0:N2}" -f $TotalRAMGB
        FreeRAMGB = "{0:N2}" -f $FreeRAMGB
        MemoryUsed = "{0:N2}%" -f $MemoryUsedPercent
        MemoryRisk = "$MemoryRisk%"
        MemoryHealth = $MemoryHealth

        DiskSizeGB = "{0:N2}" -f ($Disk.Size / 1GB)
        DiskFreeGB = "{0:N2}" -f ($Disk.FreeSpace / 1GB)
        DiskFreePercent = "{0:N2}%" -f $DiskFreePercent
        DiskRisk = "$DiskRisk%"
        DiskHealth = $DiskHealth

        IPv4Addresses = ($IPAddresses.IPAddress -join ", ")

        NetworkAdapters = (
            $Adapters |
            ForEach-Object {
                "$($_.Name) | Status=$($_.Status) | Speed=$($_.LinkSpeed) | MAC=$($_.MacAddress)"
            }
        ) -join "; "

        BitLockerProtection = $BitLockerProtection
        BitLockerVolumeStatus = $BitLockerVolumeStatus

        ADStatus = $ADStatus
        OrganizationalUnit = $OUPath
        AzureAdJoined = $AzureAdJoined
        DomainJoined = $DomainJoined
        DeviceId = $DeviceId

        BatteryStatus = $BatteryStatus
        BatteryChemistry = $BatteryChemistry

        LastInstalledUpdate = $LastInstalledUpdate
        LastUpdateDate = $LastUpdateDate
        DaysSinceLastUpdate = $DaysSinceLastUpdate

        RunningServices = (
            $Services |
            Where-Object Status -eq Running
        ).Count

        AutoStoppedServices = $AutoStopped.Count
        ServiceRisk = "$ServiceRisk%"

        OverallRiskScore = "$OverallRisk%"
        OverallRiskLevel = Get-RiskLevel $OverallRisk

        Recommendations = ($Recommendations -join " | ")
    }

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "      HYDRO ONE TIER 1 DEVICE HEALTH REPORT"
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""

    $Report | Format-List
    Write-Host ""
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Audit Complete." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error $_.Exception.Message
}
