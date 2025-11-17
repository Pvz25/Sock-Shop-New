# INCIDENT-8C: Controlled Database Latency (No Crashes)
# Simulates: Product search slowness due to database latency or connection pool exhaustion
# Method: 20 concurrent PowerShell background jobs (controlled load)
# Expected Impact: 2-5 second page load delays WITHOUT pod crashes
# Difference from 8B: Lower load (20 vs 60 jobs) = Latency without crashes

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8C: CONTROLLED DATABASE LATENCY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Client Requirement: Product search slowness due to database latency`n" -ForegroundColor Yellow

Write-Host "Method: 20 concurrent PowerShell background jobs (CONTROLLED)" -ForegroundColor White
Write-Host "Target: http://localhost:2025/catalogue" -ForegroundColor White
Write-Host "Duration: 2-5 minutes (or until manually stopped)`n" -ForegroundColor White

Write-Host "Expected Impact:" -ForegroundColor Green
Write-Host "  - Catalogue page load: 2-5 seconds (was ~1 second)" -ForegroundColor White
Write-Host "  - Database CPU: 30-50m (30-50x increase)" -ForegroundColor White
Write-Host "  - Connection pool: 15-20% saturation" -ForegroundColor White
Write-Host "  - Query latency: 2000-5000ms (20-50x slower)" -ForegroundColor White
Write-Host "  - NO POD CRASHES (controlled load)" -ForegroundColor Green
Write-Host "  - ABSOLUTE LATENCY visible in metrics`n" -ForegroundColor Green

$startTime = Get-Date
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] INCIDENT START TIME: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting 20 concurrent jobs...`n" -ForegroundColor Cyan

# Start 20 background jobs (controlled load)
$jobs = @()
for ($i = 1; $i -le 20; $i++) {
    $job = Start-Job -ScriptBlock {
        while ($true) {
            try {
                Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -UseBasicParsing -TimeoutSec 30 | Out-Null
            } catch {
                # Ignore errors, keep requesting
            }
            Start-Sleep -Milliseconds 200  # Slower than 8B (200ms vs 100ms)
        }
    }
    $jobs += $job
    
    if ($i % 5 -eq 0) {
        Write-Host "  Started $i jobs..." -ForegroundColor Gray
    }
}

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ✅ All 20 jobs started!" -ForegroundColor Green
Write-Host "Job IDs: $($jobs.Id -join ', ')" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "INCIDENT-8C ACTIVE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "`nDatabase is now under CONTROLLED load." -ForegroundColor White
Write-Host "Browse to http://localhost:2025/catalogue to experience slowness.`n" -ForegroundColor White

Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  ✅ Catalogue loads slowly (2-5 seconds)" -ForegroundColor Green
Write-Host "  ✅ Database CPU increases (30-50m)" -ForegroundColor Green
Write-Host "  ✅ NO pod crashes" -ForegroundColor Green
Write-Host "  ✅ Absolute latency visible`n" -ForegroundColor Green

Write-Host "To monitor:" -ForegroundColor Cyan
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue-db" -ForegroundColor Gray
Write-Host "  kubectl top pods -n sock-shop -l name=catalogue" -ForegroundColor Gray
Write-Host "  Measure-Command { Invoke-WebRequest http://localhost:2025/catalogue }`n" -ForegroundColor Gray

Write-Host "To stop:" -ForegroundColor Cyan
Write-Host "  .\incident-8c-recover.ps1" -ForegroundColor Gray
Write-Host "  OR: Get-Job | Stop-Job; Get-Job | Remove-Job`n" -ForegroundColor Gray

Write-Host "Recommended duration: 2-5 minutes for sufficient metrics" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to exit this script (jobs will continue in background)`n" -ForegroundColor Yellow

# Keep script alive to show monitoring
try {
    $iteration = 0
    while ($true) {
        Start-Sleep -Seconds 30
        $iteration++
        $runningJobs = (Get-Job -State Running).Count
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status: $runningJobs jobs running | Elapsed: $([math]::Round($elapsed, 1)) minutes" -ForegroundColor Gray
        
        # Show sample response time every 30 seconds
        if ($iteration % 1 -eq 0) {
            try {
                $responseTime = Measure-Command { 
                    Invoke-WebRequest http://localhost:2025/catalogue -UseBasicParsing -TimeoutSec 10 | Out-Null 
                }
                Write-Host "  Sample API response: $([math]::Round($responseTime.TotalSeconds, 2))s" -ForegroundColor Cyan
            } catch {
                Write-Host "  Sample API response: Timeout/Error" -ForegroundColor Red
            }
        }
    }
} finally {
    Write-Host "`nScript exited. Jobs are still running in background." -ForegroundColor Yellow
    Write-Host "Run .\incident-8c-recover.ps1 to stop the incident.`n" -ForegroundColor Yellow
}
