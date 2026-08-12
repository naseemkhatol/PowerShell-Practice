# ==========================================
# PowerShell PC Health Checker
# ==========================================

Write-Host "=========================================="
Write-Host "        PC HEALTH CHECK REPORT"
Write-Host "=========================================="

# ==========================================
# SYSTEM INFORMATION
# ==========================================
$computerInfo=get-computerinfo
$IPAddress = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {$_.IPAddress -ne "127.0.0.1"} |
    Select-Object -First 1 -ExpandProperty IPAddress

Write-Host "==== SYSTEM INFORMATION ===="
Write-Host "Computer Name: $env:ComputerName"
Write-Host "Windows Product Name: $($computerInfo.WindowsProductName)"
Write-Host "Windows Version: $($computerInfo.WindowsVersion)"
Write-Host "IP Address: $IPAddress"
Write-Host "TotalRAM: $("{0:N0}" -f ($computerInfo.CsTotalPhysicalMemory/ 1GB)) GB"

# ==========================================
# MEMORY HEALTH
# ==========================================

$Memory = Get-CimInstance Win32_OperatingSystem

$TotalMemoryGB = $Memory.TotalVisibleMemorySize / 1MB
$FreeMemoryGB = $Memory.FreePhysicalMemory / 1MB
$UsedMemoryGB = $TotalMemoryGB - $FreeMemoryGB

$MemoryUsagePercentage = $UsedMemoryGB / $TotalMemoryGB

if ($MemoryUsagePercentage -gt 0.90) {
    $MemoryStatus = "CRITICAL"
}
elseif ($MemoryUsagePercentage -gt 0.80) {
    $MemoryStatus = "WARNING"
}
else {
    $MemoryStatus = "HEALTHY"
}

Write-Host ""
Write-Host "==== MEMORY HEALTH ===="

Write-Host "Total Memory: $("{0:N1}" -f $TotalMemoryGB) GB"
Write-Host "Used Memory: $("{0:N1}" -f $UsedMemoryGB) GB"
Write-Host "Free Memory: $("{0:N1}" -f $FreeMemoryGB) GB"
Write-Host "Memory Usage: $("{0:P0}" -f $MemoryUsagePercentage)"
Write-Host "Memory Status: $MemoryStatus"

# ==========================================
# SERVICE HEALTH
# ==========================================

$AutomaticServices = Get-Service | Where-Object StartType -eq "Automatic"
$StoppedAutomaticServices = $AutomaticServices | Where-Object Status -eq "Stopped"

Write-Host ""
Write-Host "==== SERVICE HEALTH ===="

Write-Host "Automatic Services: $($AutomaticServices.Count)"
Write-Host "Stopped Automatic Services: $($StoppedAutomaticServices.Count)"

if ($StoppedAutomaticServices.Count -gt 0) {

    Write-Host ""
    Write-Host "Stopped Automatic Services:"

    $StoppedAutomaticServices |
        Select-Object Name, DisplayName, Status | ft | Out-Host
}

# ==========================================
# DISK REPORT
# ==========================================

$Drive = Get-Volume | Where-Object DriveLetter -eq "C"
$FreeSpacePercentage = ($Drive.SizeRemaining / $Drive.Size)

Write-Host ""
Write-Host "==== DISK REPORT ===="

Write-Host "Drive: $($Drive.DriveLetter)"
Write-Host "Total Size: $("{0:N0}" -f ($Drive.Size / 1GB)) GB"
Write-Host "Free Space: $("{0:N0}" -f ($Drive.SizeRemaining / 1GB)) GB"
Write-Host "Free Space %: $("{0:P0}" -f $FreeSpacePercentage)"

if ($FreeSpacePercentage -lt 0.10) {
    $DiskStatus = "CRITICAL"
}
elseif ($FreeSpacePercentage -lt 0.20) {
    $DiskStatus = "WARNING"
}
else {
    $DiskStatus = "HEALTHY"}
Write-Host "Disk Status: $DiskStatus"

# ==========================================
# PROCESS HEALTH
# ==========================================

Write-Host ""
Write-Host "==== PROCESS HEALTH ===="

$TopProcess = Get-Process | Sort-Object WS -Descending | Select-Object -First 5 Name, Id, WS
$TopProcess | ForEach-Object {
    Write-Host "Process Name: $($_.Name), (Process ID: $($_.Id)) - $("{0:N0}" -f ($_.WS / 1MB)) MB"
}

$HighMemoryProcess= $Topprocess | Where WS -gt 2GB

If ($HighMemoryProcess) 
{$ProcessStatus = "WARNING"}
Else 
{$ProcessStatus = "HEALTHY"}

Write-Host ""
Write-Host "Process Status: $ProcessStatus"

# ==========================================
# APPLICATION HEALTH
# ==========================================

Write-Host ""
Write-Host "==== APPLICATION HEALTH ===="

$Applications = @(
    "Google Chrome",
    "Microsoft Edge",
    "Microsoft Visual Studio Code",
    "Adobe Acrobat",
    "Git"
)

ForEach ($App in $Applications)
{
    $Installed= Get-Package | Where-Object Name -like "*$App*"
If ($Installed)
{Write-Host "$App is installed"}
Else
{Write-Host "$App is NOT installed"}}

#### End of Report ####
