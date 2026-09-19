<#
.SYNOPSIS
Hydro One Tier 1 Audit Launcher

.DESCRIPTION
Prompts for a target device name, downloads the latest
HydroOneTier1AuditReport.ps1, executes the audit
remotely using PsExec, and generates an audit report.

.AUTHOR
Naseem Khatol

.VERSION
1.0

.CREATED
September 2026

.REQUIREMENTS
- PsExec.exe
- Administrative rights on target device
- Network connectivity to target device
- GitHub access

.OUTPUT
AuditReport.txt

.NOTES
Created for Hydro One Tier 1 Support Operations.
Automates remote execution of the Hydro One Device Health Audit.
#>

$ComputerName = Read-Host "Enter Laptop Name"

$GitHubRawUrl = "https://raw.githubusercontent.com/naseemkhatol/PowerShell-Practice/refs/heads/main/HydroOneTier1AuditReport.ps1"

Write-Host ""
Write-Host "Creating C:\Temp on $ComputerName..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" cmd /c mkdir C:\Temp > $null 2>&1

Write-Host "Downloading latest audit script from GitHub..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" powershell.exe `
    -ExecutionPolicy Bypass `
    -Command "Invoke-WebRequest -Uri '$GitHubRawUrl' -OutFile 'C:\Temp\HydroOneTier1AuditReport.ps1'"

Write-Host "Running audit..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" powershell.exe `
    -ExecutionPolicy Bypass `
    -Command "& 'C:\Temp\HydroOneTier1AuditReport.ps1' -ComputerName '$ComputerName' | Out-File 'C:\Temp\AuditReport.txt'"

$ReportPath = "\\$ComputerName\C$\Temp\AuditReport.txt"

if (Test-Path $ReportPath) {

    Write-Host ""
    Write-Host "Audit completed successfully." -ForegroundColor Green

    notepad $ReportPath

}
else {

    Write-Host ""
    Write-Host "Audit completed but report was not found." -ForegroundColor Yellow

}
