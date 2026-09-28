# ============================================================
# HELPONE REMOTE DEVICE DIAGNOSTIC TOOLKIT
# Phase 1
#
# Purpose
# - Validate the local environment
# - Ask for a target computer
# - Test remote PsExec access
# - Display the initial investigation menu
#
# Safety
# - Read-only
# - Does not restart services
# - Does not change registry values
# - Does not reboot the target
# - Does not install or remove software
# ============================================================


# ------------------------------------------------------------
# SCRIPT SETTINGS
# ------------------------------------------------------------

$ToolName = "HelpOne Remote Device Diagnostic Toolkit"
$ToolVersion = "0.1"
$PsExecTimeoutSeconds = 10
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$PsExecPath = Join-Path $ScriptFolder "PsExec.exe"


# ------------------------------------------------------------
# DISPLAY TOOL HEADER
# ------------------------------------------------------------

function Show-ToolHeader
{
    param
    (
        [string]$ComputerName
    )

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " HELPONE REMOTE DEVICE DIAGNOSTIC TOOLKIT" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Tool version  " -NoNewline
    Write-Host $ToolVersion -ForegroundColor White

    Write-Host "Technician    " -NoNewline
    Write-Host $env:USERDOMAIN"\"$env:USERNAME -ForegroundColor White

    Write-Host "PowerShell    " -NoNewline
    Write-Host $PSVersionTable.PSVersion -ForegroundColor White

    if ($ComputerName -eq $null -or $ComputerName.Trim().Length -eq 0)
    {
        Write-Host "Target device " -NoNewline
        Write-Host "Not selected" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Target device " -NoNewline
        Write-Host $ComputerName -ForegroundColor Green
    }

    Write-Host "Mode          " -NoNewline
    Write-Host "Investigation only" -ForegroundColor Green

    Write-Host ""
}


# ------------------------------------------------------------
# CHECK IF POWERSHELL IS RUNNING AS ADMINISTRATOR
# ------------------------------------------------------------

function Test-Administrator
{
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    $AdministratorRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    $IsAdministrator = $CurrentPrincipal.IsInRole($AdministratorRole)

    return $IsAdministrator
}


# ------------------------------------------------------------
# CHECK LOCAL REQUIREMENTS
# ------------------------------------------------------------

function Test-LocalRequirements
{
    $RequirementsPassed = $true

    Write-Host "Checking local requirements..." -ForegroundColor Cyan
    Write-Host ""

    $AdministratorCheck = Test-Administrator

    if ($AdministratorCheck -eq $true)
    {
        Write-Host "[PASS] PowerShell is running as administrator." -ForegroundColor Green
    }
    else
    {
        Write-Host "[FAIL] PowerShell is not running as administrator." -ForegroundColor Red
        Write-Host "       Close this window and open PowerShell as administrator." -ForegroundColor Yellow

        $RequirementsPassed = $false
    }

    if (Test-Path $PsExecPath)
    {
        Write-Host "[PASS] PsExec.exe was found." -ForegroundColor Green
        Write-Host "       $PsExecPath" -ForegroundColor DarkGray
    }
    else
    {
        Write-Host "[FAIL] PsExec.exe was not found." -ForegroundColor Red
        Write-Host "       Expected location" -ForegroundColor Yellow
        Write-Host "       $PsExecPath" -ForegroundColor Yellow

        $RequirementsPassed = $false
    }

    Write-Host ""

    return $RequirementsPassed
}


# ------------------------------------------------------------
# ASK FOR AND VALIDATE TARGET COMPUTER NAME
# ------------------------------------------------------------

function Get-TargetComputer
{
    $ValidComputerSelected = $false
    $SelectedComputer = ""

    while ($ValidComputerSelected -eq $false)
    {
        Write-Host ""
        Write-Host "Enter the laptop or computer name." -ForegroundColor Cyan
        Write-Host "Example  L-21K4PF54J1QW" -ForegroundColor DarkGray
        Write-Host "Enter Q to quit." -ForegroundColor DarkGray
        Write-Host ""

        $ComputerInput = Read-Host "Computer name"

        if ($ComputerInput -eq "Q")
        {
            return ""
        }

        if ($ComputerInput -eq "q")
        {
            return ""
        }

        $ComputerInput = $ComputerInput.Trim()
        $ComputerInput = $ComputerInput.ToUpper()

        if ($ComputerInput.Length -eq 0)
        {
            Write-Host ""
            Write-Host "[FAIL] A computer name was not entered." -ForegroundColor Red
        }
        elseif ($ComputerInput.Contains(" "))
        {
            Write-Host ""
            Write-Host "[FAIL] The computer name cannot contain spaces." -ForegroundColor Red
        }
        elseif ($ComputerInput.Contains("\"))
        {
            Write-Host ""
            Write-Host "[FAIL] Enter only the computer name." -ForegroundColor Red
            Write-Host "       Do not enter leading backslashes." -ForegroundColor Yellow
        }
        else
        {
            $SelectedComputer = $ComputerInput
            $ValidComputerSelected = $true
        }
    }

    return $SelectedComputer
}


# ------------------------------------------------------------
# RUN SAFE PSEXEC PREFLIGHT TEST
# ------------------------------------------------------------

function Test-RemoteConnection
{
    param
    (
        [string]$ComputerName
    )

    Write-Host ""
    Write-Host "Testing remote access to $ComputerName..." -ForegroundColor Cyan
    Write-Host ""

    $RemoteTarget = "\\" + $ComputerName

    $PsExecOutput = & $PsExecPath `
        $RemoteTarget `
        -accepteula `
        -nobanner `
        -n $PsExecTimeoutSeconds `
        cmd.exe `
        /c hostname 2>&1

    $PsExecExitCode = $LASTEXITCODE

    Write-Host "PsExec output" -ForegroundColor White
    Write-Host "------------------------------------------------------------"

    if ($PsExecOutput)
    {
        $PsExecOutput | ForEach-Object
        {
            Write-Host $_
        }
    }
    else
    {
        Write-Host "No output was returned." -ForegroundColor Yellow
    }

    Write-Host "------------------------------------------------------------"
    Write-Host ""

    if ($PsExecExitCode -eq 0)
    {
        Write-Host "[PASS] PsExec successfully executed a remote command." -ForegroundColor Green
        Write-Host "[PASS] The target returned hostname $ComputerName." -ForegroundColor Green
        Write-Host ""

        return $true
    }
    else
    {
        Write-Host "[FAIL] PsExec could not complete the remote test." -ForegroundColor Red
        Write-Host "       Exit code $PsExecExitCode" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Common causes" -ForegroundColor Cyan
        Write-Host " - The laptop is powered off."
        Write-Host " - The laptop is not connected to the corporate network or VPN."
        Write-Host " - The computer name is incorrect."
        Write-Host " - Your account does not have remote administrative access."
        Write-Host " - The administrative share or PsExec communication is blocked."
        Write-Host ""

        return $false
    }
}


# ------------------------------------------------------------
# DISPLAY MAIN MENU
# ------------------------------------------------------------

function Show-MainMenu
{
    param
    (
        [string]$ComputerName
    )

    Show-ToolHeader -ComputerName $ComputerName

    Write-Host "Select an investigation area." -ForegroundColor Cyan
    Write-Host ""

    Write-Host " [1] Computer overview"
    Write-Host " [2] Connectivity and remote access"
    Write-Host " [3] WMI and CIM health"
    Write-Host " [4] Windows Update and patch status"
    Write-Host " [5] Event log investigation"
    Write-Host " [6] Software and vulnerability evidence"
    Write-Host " [7] Windows services and permissions"
    Write-Host " [8] Defender and security health"
    Write-Host " [9] Configuration Manager and Tenable health"
    Write-Host " [10] Complete read-only assessment"
    Write-Host ""
    Write-Host " [C] Change target computer"
    Write-Host " [Q] Quit"
    Write-Host ""

    $MenuSelection = Read-Host "Selection"

    return $MenuSelection
}


# ------------------------------------------------------------
# DISPLAY PLACEHOLDER FOR FUTURE MODULES
# ------------------------------------------------------------

function Show-ComingSoon
{
    param
    (
        [string]$SectionName
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $SectionName -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This investigation section has not been added yet." -ForegroundColor Yellow
    Write-Host "The Phase 1 framework is working if you reached this screen." -ForegroundColor Green
    Write-Host ""

    Read-Host "Press Enter to return to the main menu"
}


# ------------------------------------------------------------
# MAIN SCRIPT
# ------------------------------------------------------------

Show-ToolHeader -ComputerName ""

$LocalRequirementsPassed = Test-LocalRequirements

if ($LocalRequirementsPassed -eq $false)
{
    Write-Host "The toolkit cannot continue until the failed requirement is corrected." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit
}

Read-Host "Press Enter to continue"

$ExitToolkit = $false
$ComputerName = ""

while ($ExitToolkit -eq $false)
{
    if ($ComputerName -eq $null -or $ComputerName.Trim().Length -eq 0)
    {
        Show-ToolHeader -ComputerName ""

        $ComputerName = Get-TargetComputer

        if ($ComputerName -eq $null -or $ComputerName.Trim().Length -eq 0)
        {
            $ExitToolkit = $true
            continue
        }

        Show-ToolHeader -ComputerName $ComputerName

        $RemoteConnectionPassed = Test-RemoteConnection -ComputerName $ComputerName

        if ($RemoteConnectionPassed -eq $false)
        {
            Write-Host "The target will not be saved because the remote test failed." -ForegroundColor Yellow
            Write-Host ""

            Read-Host "Press Enter to select another computer"

            $ComputerName = ""
            continue
        }

        Read-Host "Press Enter to open the investigation menu"
    }

    $Selection = Show-MainMenu -ComputerName $ComputerName

    if ($Selection -eq "1")
    {
        Show-ComingSoon -SectionName "COMPUTER OVERVIEW"
    }
    elseif ($Selection -eq "2")
    {
        Show-ComingSoon -SectionName "CONNECTIVITY AND REMOTE ACCESS"
    }
    elseif ($Selection -eq "3")
    {
        Show-ComingSoon -SectionName "WMI AND CIM HEALTH"
    }
    elseif ($Selection -eq "4")
    {
        Show-ComingSoon -SectionName "WINDOWS UPDATE AND PATCH STATUS"
    }
    elseif ($Selection -eq "5")
    {
        Show-ComingSoon -SectionName "EVENT LOG INVESTIGATION"
    }
    elseif ($Selection -eq "6")
    {
        Show-ComingSoon -SectionName "SOFTWARE AND VULNERABILITY EVIDENCE"
    }
    elseif ($Selection -eq "7")
    {
        Show-ComingSoon -SectionName "WINDOWS SERVICES AND PERMISSIONS"
    }
    elseif ($Selection -eq "8")
    {
        Show-ComingSoon -SectionName "DEFENDER AND SECURITY HEALTH"
    }
    elseif ($Selection -eq "9")
    {
        Show-ComingSoon -SectionName "CONFIGURATION MANAGER AND TENABLE HEALTH"
    }
    elseif ($Selection -eq "10")
    {
        Show-ComingSoon -SectionName "COMPLETE READ-ONLY ASSESSMENT"
    }
    elseif ($Selection -eq "C")
    {
        $ComputerName = ""
    }
    elseif ($Selection -eq "c")
    {
        $ComputerName = ""
    }
    elseif ($Selection -eq "Q")
    {
        $ExitToolkit = $true
    }
    elseif ($Selection -eq "q")
    {
        $ExitToolkit = $true
    }
    else
    {
        Write-Host ""
        Write-Host "[FAIL] Invalid selection." -ForegroundColor Red
        Write-Host ""

        Read-Host "Press Enter to return to the menu"
    }
}

Clear-Host
Write-Host ""
Write-Host "HelpOne Remote Device Diagnostic Toolkit closed." -ForegroundColor Cyan
Write-Host ""
