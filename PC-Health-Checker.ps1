# ==========================================
# PowerShell PC Health Checker
# ==========================================

Write-Host "=========================================="
Write-Host "        PC HEALTH CHECK REPORT"
Write-Host "=========================================="

# ==========================================
# DISK REPORT
# ==========================================

$Drive = Get-Volume | Where-Object DriveLetter -eq "C"

Write-Host ""
Write-Host "==== DISK REPORT ===="

Write-Host "Drive: $($Drive.DriveLetter)"
Write-Host "Total Size: $("{0:N0}" -f ($Drive.Size / 1GB)) GB"
Write-Host "Free Space: $("{0:N0}" -f ($Drive.SizeRemaining / 1GB)) GB"
Write-Host "Free Space %: $("{0:P0}" -f ($Drive.SizeRemaining / $Drive.Size))"
