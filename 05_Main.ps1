Import-Module "$PSScriptRoot\AuditTools.psm1"

# Create Reports folder if it doesn't exist
$ReportsFolder = "$PSScriptRoot\Reports"

if (-not (Test-Path $ReportsFolder)) {
    New-Item -Path $ReportsFolder -ItemType Directory | Out-Null
}

# Run system audit
$Report = Get-SystemAudit

# Display report
$Report | Format-List

# Export CSV
$Report | Export-Csv "$ReportsFolder\AuditReport.csv" -NoTypeInformation

# Export JSON
$Report | ConvertTo-Json -Depth 3 | Out-File "$ReportsFolder\AuditReport.json"

Write-Host ""
Write-Host "========================================"
Write-Host "Audit reports generated successfully!"
Write-Host "========================================"
Write-Host "CSV : $ReportsFolder\AuditReport.csv"
Write-Host "JSON: $ReportsFolder\AuditReport.json"
