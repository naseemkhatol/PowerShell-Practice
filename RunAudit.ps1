<#
.SYNOPSIS
Hydro One Help 1 Audit Launcher

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

$GitHubRawUrl = "https://raw.githubusercontent.com/naseemkhatol/PowerShell-Practice/refs/heads/main/HydroOneTier1AuditReport.ps1"

$LocalReportFolder = "C:\Temp\Audit Reports"

if (!(Test-Path $LocalReportFolder)) {
    New-Item -Path $LocalReportFolder -ItemType Directory -Force | Out-Null
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
        Write-Host " - If the user is working from home, it is highly likely:"
        Write-Host "    - The device is not connected to VPN"
        Write-Host "    - SMB traffic (TCP 445) is blocked"
        Write-Host "    - Administrative shares are unavailable"
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

    Write-Host "Downloading latest audit script..." -ForegroundColor Cyan

    .\PsExec.exe "\\$ComputerName" powershell.exe `
        -ExecutionPolicy Bypass `
        -Command "Invoke-WebRequest -Uri '$GitHubRawUrl' -OutFile 'C:\Temp\HydroOneTier1AuditReport.ps1'"

    # =====================================================
    # VERIFY DOWNLOAD
    # =====================================================

    if (!(Test-Path "\\$ComputerName\C$\Temp\HydroOneTier1AuditReport.ps1")) {

        Write-Host ""
        Write-Host "ERROR: Audit script failed to download." -ForegroundColor Red
        Write-Host "The target device may not be able to access GitHub." -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host " - No Internet connectivity"
        Write-Host " - GitHub access is blocked"
        Write-Host " - Proxy or firewall restrictions"
        Write-Host " - Virtual machine network limitations"
        Write-Host ""

        continue
    }

    Write-Host "Running audit..." -ForegroundColor Cyan

    .\PsExec.exe "\\$ComputerName" powershell.exe `
        -ExecutionPolicy Bypass `
        -Command "& 'C:\Temp\HydroOneTier1AuditReport.ps1' -ComputerName '$ComputerName' | Out-File 'C:\Temp\Audit Reports\$($ComputerName)_AuditReport.txt'"

    $RemoteReportPath = "\\$ComputerName\C$\Temp\Audit Reports\$($ComputerName)_AuditReport.txt"

    $LocalReportPath = Join-Path `
        $LocalReportFolder `
        "$($ComputerName)_AuditReport.txt"

    if (Test-Path $RemoteReportPath) {

        Copy-Item `
            $RemoteReportPath `
            $LocalReportPath `
            -Force

     # =====================================================
    # PASSWORD LAST SET
    # =====================================================
    
    $PasswordLastSet = "Unable to Query"
    
    try {
    
        $CurrentUserLine = Select-String `
            -Path $LocalReportPath `
            -Pattern "^CurrentUser"
    
        if ($CurrentUserLine) {
    
            $CurrentUser = (
                $CurrentUserLine.Line -split ":" , 2
            )[1].Trim()
    
            if ($CurrentUser -match "\\") {
    
                $SamAccountName = (
                    $CurrentUser -split "\\"
                )[-1]
    
                $PasswordLastSet = (
                    Get-ADUser `
                        $SamAccountName `
                        -Properties PasswordLastSet
                ).PasswordLastSet
            }
        }
    
    }
    catch {
    
        $PasswordLastSet = "Unable to Query"
    
    }
    
    Add-Content -Path $LocalReportPath ""
    Add-Content -Path $LocalReportPath "DIRECTORY INFORMATION"
    Add-Content -Path $LocalReportPath "-----------------------------------------------"
    Add-Content -Path $LocalReportPath "ADStatus           : $ADStatus"
    Add-Content -Path $LocalReportPath "OrganizationalUnit : $OUPath"
    Add-Content -Path $LocalReportPath "PasswordLastSet    : $PasswordLastSet"

        Write-Host ""
        Write-Host "Audit completed successfully." -ForegroundColor Green
        Write-Host "Report copied locally." -ForegroundColor Green
        Write-Host "Opening report..." -ForegroundColor Green
        Write-Host ""

        notepad $LocalReportPath

        Write-Host "Cleaning up remote files..." -ForegroundColor Cyan

        .\PsExec.exe "\\$ComputerName" cmd /c del /f /q "C:\Temp\HydroOneTier1AuditReport.ps1" > $null 2>&1

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
