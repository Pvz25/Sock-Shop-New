# INCIDENT-8C Recovery Script
# Stops all background jobs causing database latency

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8C RECOVERY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$endTime = Get-Date
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] INCIDENT END TIME: $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow

# Get all running jobs
$jobs = Get-Job

if ($jobs.Count -eq 0) {
    Write-Host "`nNo background jobs found. Incident may already be recovered.`n" -ForegroundColor Yellow
    exit
}

Write-Host "`nFound $($jobs.Count) background jobs" -ForegroundColor White
Write-Host "Job IDs: $($jobs.Id -join ', ')`n" -ForegroundColor Gray

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Stopping all jobs..." -ForegroundColor Yellow
Get-Job | Stop-Job

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Removing all jobs..." -ForegroundColor Yellow
Get-Job | Remove-Job

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ✅ All jobs stopped and removed!" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "INCIDENT-8C RECOVERED" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Database load has been removed." -ForegroundColor White
Write-Host "System should return to normal within 30 seconds.`n" -ForegroundColor White

Write-Host "Verify recovery:" -ForegroundColor Cyan
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue-db" -ForegroundColor Gray
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue" -ForegroundColor Gray
Write-Host "  Measure-Command { Invoke-WebRequest http://localhost:2025/catalogue }`n" -ForegroundColor Gray

Write-Host "Wait 30 seconds for metrics to stabilize, then check Datadog for incident timeline.`n" -ForegroundColor Yellow
