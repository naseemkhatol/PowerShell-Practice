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
<ComputerName>_HealthReport.txt

.NOTES
Created for Hydro One Tier 1 Support Operations.
Automates remote execution of the Hydro One Device Health Audit.
#>

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "        HYDRO ONE TIER 1 AUDIT LAUNCHER"
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

$GitHubRawUrl = "https://raw.githubusercontent.com/naseemkhatol/PowerShell-Practice/refs/heads/main/HydroOneTier1AuditReport.ps1"

while ($true) {

    $ComputerName = Read-Host "Enter Laptop Name (or type EXIT to quit)"

    if ($ComputerName.ToUpper() -eq "EXIT") {
        break
    }

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
        -Command "& 'C:\Temp\HydroOneTier1AuditReport.ps1' -ComputerName '$ComputerName' | Out-File 'C:\Temp\$($ComputerName)_AuditReport.txt'"

    $ReportPath = "\\$ComputerName\C$\Temp\$($ComputerName)_AuditReport.txt"

    if (Test-Path $ReportPath) {

        Write-Host ""
        Write-Host "Audit completed successfully." -ForegroundColor Green
        Write-Host "Opening report..." -ForegroundColor Green
        Write-Host ""

        $LocalReportFolder = ".\Audit Reports"

        if (!(Test-Path $LocalReportFolder)) {
            New-Item -Path $LocalReportFolder -ItemType Directory | Out-Null
        }

        Copy-Item `
            $ReportPath `
            "$LocalReportFolder\$($ComputerName)_AuditReport.txt" `
            -Force

        Write-Host "Report copied locally." -ForegroundColor Green

        notepad $ReportPath

    }
    else {

        Write-Host ""
        Write-Host "Audit completed but report was not found." -ForegroundColor Yellow
        Write-Host ""

    }

    Write-Host "Ready for next device..." -ForegroundColor Green
    Write-Host ""
}

Write-Host ""
Write-Host "Exiting Audit Tool." -ForegroundColor Yellow
Write-Host ""
