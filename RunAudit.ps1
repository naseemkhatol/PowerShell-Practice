param(
    [Parameter(Mandatory)]
    [string]$ComputerName
)

$GitHubRawUrl = "https://raw.githubusercontent.com/naseemkhatol/PowerShell-Practice/main/HydroOneTier1AuditReport.ps1"

Write-Host ""
Write-Host "Creating Temp folder..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" cmd /c mkdir C:\Temp > $null 2>&1

Write-Host "Downloading latest audit script..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" powershell.exe `
    -ExecutionPolicy Bypass `
    -Command "Invoke-WebRequest -Uri '$GitHubRawUrl' -OutFile 'C:\Temp\HydroOneTier1AuditReport.ps1'"

Write-Host "Running audit..." -ForegroundColor Cyan

.\PsExec.exe "\\$ComputerName" powershell.exe `
    -ExecutionPolicy Bypass `
    -Command "& 'C:\Temp\HydroOneTier1AuditReport.ps1' -ComputerName '$ComputerName' | Out-File 'C:\Temp\AuditReport.txt'"

Write-Host ""
Write-Host "Audit completed." -ForegroundColor Green

$ReportPath = "\\$ComputerName\C$\Temp\AuditReport.txt"

if (Test-Path $ReportPath) {

    Write-Host "Opening report..." -ForegroundColor Green

    notepad $ReportPath

}
else {

    Write-Host "Audit completed but report could not be found." -ForegroundColor Yellow

}
