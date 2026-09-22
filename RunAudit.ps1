<#
.SYNOPSIS
Hydro One Help 1 Audit Launcher

.DESCRIPTION
Prompts for a target device name, executes the audit
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


.OUTPUT
<ComputerName>_AuditReport.txt

.NOTES
Created for Hydro One Tier 1 Support Operations.
Automates remote execution of the Hydro One Device Health Audit.
#>

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "              HELP 1 AUDIT LAUNCHER"
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

$LocalReportFolder = "C:\Temp\Audit Reports"

if (!(Test-Path $LocalReportFolder)) {
    New-Item -Path $LocalReportFolder -ItemType Directory -Force | Out-Null
}

if (!(Test-Path ".\HelpOneAuditTools.ps1")) {

    Write-Host ""
    Write-Host "ERROR: HelpOneAuditTools.ps1 was not found." -ForegroundColor Red
    Write-Host "Place HelpOneAuditTools.ps1 in the same folder as RunAudit.ps1 and PsExec.exe." -ForegroundColor Red
    Write-Host ""

    exit
}

while ($true) {

    $ComputerName = Read-Host "Enter Laptop Name (or type EXIT to quit)"

    if ($ComputerName.ToUpper() -eq "EXIT") {
        break
    }
    # =====================================================
    # CONNECTIVITY CHECK
    # =====================================================

    if (!(Test-Path "\\$ComputerName\C$")) {

        Write-Host ""
        Write-Host "ERROR: Unable to connect to $ComputerName" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host " - Device is offline"
        Write-Host " - Device is asleep"
        Write-Host " - If the user is working from home, it is highly likely the device:"
        Write-Host "    - Is not connected to VPN"
        Write-Host "    - Has SMB traffic (TCP 445) blocked"
        Write-Host "    - Has administrative shares unavailable"
        Write-Host " - The audit tool will be unable to establish a connection"
        Write-Host ""

        continue
    }

    # =====================================================
    # ACTIVE DIRECTORY LOOKUP
    # =====================================================

    try {

        Import-Module ActiveDirectory -ErrorAction Stop

        $ADComputer = Get-ADComputer `
            $ComputerName `
            -Properties Enabled, DistinguishedName

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

        $ADStatus = "Unable to Query"
        $OUPath = "Unknown"

    }

    Write-Host ""
    Write-Host "Creating C:\Temp on $ComputerName..." -ForegroundColor Cyan

    .\PsExec.exe "\\$ComputerName" cmd /c mkdir C:\Temp > $null 2>&1

    Write-Host "Creating remote report folder..." -ForegroundColor Cyan

    .\PsExec.exe "\\$ComputerName" cmd /c mkdir "C:\Temp\Audit Reports" > $null 2>&1

    Write-Host "Copying audit script..." -ForegroundColor Cyan

    Copy-Item `
        ".\HelpOneAuditTools.ps1" `
        "\\$ComputerName\C$\Temp\HelpOneAuditTools.ps1" `
        -Force

    Write-Host "Running audit..." -ForegroundColor Cyan

    .\PsExec.exe "\\$ComputerName" powershell.exe `
        -ExecutionPolicy Bypass `
        -Command "& 'C:\Temp\HelpOneAuditTools.ps1' -ComputerName '$ComputerName' | Out-File 'C:\Temp\Audit Reports\$($ComputerName)_AuditReport.txt'"

    $RemoteReportPath = "\\$ComputerName\C$\Temp\Audit Reports\$($ComputerName)_AuditReport.txt"

    $LocalReportPath = Join-Path `
        $LocalReportFolder `
        "$($ComputerName)_AuditReport.txt"

    if (Test-Path $RemoteReportPath) {

        Copy-Item `
            $RemoteReportPath `
            $LocalReportPath `
            -Force

        Add-Content -Path $LocalReportPath "DIRECTORY INFORMATION"
        Add-Content -Path $LocalReportPath "-----------------------------------------------"
        Add-Content -Path $LocalReportPath "ADStatus           : $ADStatus"
        Add-Content -Path $LocalReportPath "OrganizationalUnit : $OUPath"

        Write-Host ""
        Write-Host "Audit completed successfully." -ForegroundColor Green
        Write-Host "Report copied locally." -ForegroundColor Green
        Write-Host "Opening report..." -ForegroundColor Green
        Write-Host ""

        notepad $LocalReportPath

        Write-Host "Cleaning up remote files..." -ForegroundColor Cyan

        .\PsExec.exe "\\$ComputerName" cmd /c del /f /q "C:\Temp\HelpOneAuditTools.ps1" > $null 2>&1

        .\PsExec.exe "\\$ComputerName" cmd /c del /f /q "C:\Temp\Audit Reports\$($ComputerName)_AuditReport.txt" > $null 2>&1

        Write-Host "Cleanup complete." -ForegroundColor Green

    }
    else {

        Write-Host ""
        Write-Host "Audit completed but report was not found." -ForegroundColor Yellow
        Write-Host ""

    }

    Write-Host ""
    Write-Host "Ready for next device..." -ForegroundColor Green
    Write-Host ""

}

Write-Host ""
Write-Host "Exiting Audit Tool." -ForegroundColor Yellow
Write-Host ""
