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
