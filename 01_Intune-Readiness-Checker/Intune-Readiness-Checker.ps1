<#
===============================================================================
                           INTUNE READINESS CHECKER
===============================================================================

.SYNOPSIS
    Performs a readiness assessment for Microsoft Intune application deployment.

.DESCRIPTION
    Collects and evaluates key system information to determine whether a
    Windows device meets basic deployment requirements.
    
.AUTHOR
    Naseem Khatol

.CREATED
    August 2026

.NOTES
    This project was created for learning purposes to develop PowerShell
    scripting skills related to Windows administration, Microsoft Intune,
    and application deployment workflows.

===============================================================================
#>

Write-Host "=========================================="
Write-Host "      INTUNE READINESS CHECK"
Write-Host "=========================================="
Write-Host ""

$ChecksPassed = 0

Write-Host "Computer Name: $env:COMPUTERNAME"
Write-Host ""

$Computer= Get-computerinfo
Write-Host "Windows Product: $($computer.WindowsProductName)"
Write-Host "Windows Version: $($Computer.WindowsVersion)"

If ($Computer.WindowsProductName -match "Windows 10|Windows 11")
{
    Write-Host "Supported: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Supported: No"
}

" "

$PowerShellVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $PowerShellVersion"

If ($PowerShellVersion.Major -ge 5)
{
    Write-Host "Supported: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Supported: No"
}

" "

$TotalRam = $Computer.CsTotalPhysicalMemory / 1GB

Write-Host "Installed RAM: $("{0:N2}" -f ($TotalRam)) GB"
Write-Host "Required RAM: 8 GB"

If ($TotalRam -ge 8) 
{
    Write-Host "Supported: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Supported: No"
}
" "
$Disk= Get-Volume | Where DriveLetter -eq "C"

Write-Host "Free Disk Space: $("{0:N2}" -f ($Disk.SizeRemaining/1GB)) GB"
Write-Host "Requirement: 20 GB"

If ($Disk.SizeRemaining -ge 20GB)
{
    Write-Host "Supported: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Supported: No"
}
" "

Write-Host "Checking Internet Connection..."
$Connected = Test-Connection 8.8.8.8 -Count 1 -Quiet
If ($Connected)
{
    Write-Host "Connected: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Connected: No"
}
" "

$WindowsUpdateService = Get-Service | Where DisplayName -Like "*Windows Update*"

Write-Host "Windows Update Service:"
Write-Host "Status: $($WindowsUpdateService.Status)"

If ($WindowsUpdateService.Status -like "Running")
{
    Write-Host "Pass: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "Pass: No"
}

" "

$Applications = @("Google Chrome", "Microsoft Edge", "Microsoft Teams", "GitHub Desktop")

Write-Host "Checking for Required Applications..."

ForEach ($App in $Applications)
{
    $AppInstalled = Get-Package | Where Name -Like "*$App*"
    If ($AppInstalled)
    {
        Write-Host "$App Installed: Yes"
    }
    else
    {
        Write-Host "$App Installed: No"
    }
}

$Chrome = Get-Package | Where Name -Like "*Google Chrome*"
$MsEdge = Get-Package | Where Name -Like "*Microsoft Edge*"
$MsTeams = Get-Package | Where Name -Like "*Microsoft Teams*"
$GitHub= Get-Package | Where Name -Like "*GitHub Desktop*"

If ($Chrome -and $MsEdge -and $MsTeams -and $GitHub)
{
    Write-Host "All Required Applications Installed: Yes"
    $ChecksPassed++
}
else
{
    Write-Host "All Required Applications Installed: No"
}


" "

"======================================================"
" "
Write-Host "Checks Passed: $ChecksPassed / 7"
If ($ChecksPassed -eq 7)
{
    Write-Host "Overall Status: Ready for Intune"
}
else
{
    Write-Host "Overall Status: Not Ready for Intune"
}

