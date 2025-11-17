# INCIDENT-8B: Database Performance Degradation via Load Testing
# Simulates: Product search slowness due to database latency or connection pool exhaustion
# Method: 60 concurrent HTTP requests to /catalogue endpoint
# Expected Impact: 5-15 second page load delays (was <1 second)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8B: DATABASE PERFORMANCE DEGRADATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Client Requirement: Product search slowness due to database latency or connection pool exhaustion`n" -ForegroundColor Yellow

Write-Host "Method: 60 concurrent PowerShell background jobs" -ForegroundColor White
Write-Host "Target: http://localhost:2025/catalogue" -ForegroundColor White
Write-Host "Duration: ~2 minutes (or until manually stopped)`n" -ForegroundColor White

Write-Host "Expected Impact:" -ForegroundColor Green
Write-Host "  - Catalogue page load: 5-15 seconds (was <1 second)" -ForegroundColor White
Write-Host "  - Database CPU: 100-200m (10-20x increase)" -ForegroundColor White
Write-Host "  - Connection pool: 40-60% saturation" -ForegroundColor White
Write-Host "  - Query latency: 5000-10000ms (100-200x slower)`n" -ForegroundColor White

# Confirm execution
$confirm = Read-Host "Start INCIDENT-8B? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "`nIncident activation cancelled." -ForegroundColor Yellow
    exit
}

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Starting 60 concurrent jobs..." -ForegroundColor Cyan

# Start 60 background jobs
$jobs = @()
for ($i = 1; $i -le 60; $i++) {
    $job = Start-Job -ScriptBlock {
        while ($true) {
            try {
                Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -UseBasicParsing -TimeoutSec 30 | Out-Null
            } catch {
                # Ignore errors, keep hammering
            }
            Start-Sleep -Milliseconds 100
        }
    }
    $jobs += $job
    
    if ($i % 10 -eq 0) {
        Write-Host "  Started $i jobs..." -ForegroundColor Gray
    }
}

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ✅ All 60 jobs started!" -ForegroundColor Green
Write-Host "`nJob IDs: $($jobs.Id -join ', ')" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "INCIDENT-8B ACTIVE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "`nDatabase is now under heavy load." -ForegroundColor White
Write-Host "Browse to http://localhost:2025/catalogue to experience slowness.`n" -ForegroundColor White

Write-Host "To monitor:" -ForegroundColor Cyan
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue-db" -ForegroundColor Gray
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue" -ForegroundColor Gray

Write-Host "`nTo stop:" -ForegroundColor Cyan
Write-Host "  .\incident-8b-recover.ps1" -ForegroundColor Gray
Write-Host "  OR: Get-Job | Stop-Job; Get-Job | Remove-Job`n" -ForegroundColor Gray

Write-Host "Press Ctrl+C to exit this script (jobs will continue in background)" -ForegroundColor Yellow
Write-Host "Jobs will run until you execute the recovery script.`n" -ForegroundColor Yellow

# Keep script alive to show monitoring
try {
    while ($true) {
        Start-Sleep -Seconds 30
        $runningJobs = (Get-Job -State Running).Count
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status: $runningJobs jobs running" -ForegroundColor Gray
    }
} finally {
    Write-Host "`nScript exited. Jobs are still running in background." -ForegroundColor Yellow
    Write-Host "Run .\incident-8b-recover.ps1 to stop the incident.`n" -ForegroundColor Yellow
}
