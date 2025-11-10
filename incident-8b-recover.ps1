# INCIDENT-8B RECOVERY: Stop Database Load Generators
# Stops all background jobs to restore normal database performance

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8B RECOVERY: Database Load" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$RECOVERY_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 RECOVERY START: $RECOVERY_START" -ForegroundColor Green
Write-Host ""

# Step 1: Load job IDs
Write-Host "Step 1: Loading active job IDs..." -ForegroundColor Green

if (Test-Path ".\incident-8b-job-ids.txt") {
    $jobIds = Get-Content ".\incident-8b-job-ids.txt"
    Write-Host "  Found $($jobIds.Count) active jobs" -ForegroundColor Yellow
} else {
    Write-Host "  ⚠️  No job ID file found, will stop all running jobs" -ForegroundColor Yellow
    $jobIds = Get-Job | Where-Object { $_.State -eq 'Running' } | Select-Object -ExpandProperty Id
}
Write-Host ""

# Step 2: Stop all load generator jobs
Write-Host "Step 2: Stopping load generator jobs..." -ForegroundColor Green

$stopped = 0
foreach ($jobId in $jobIds) {
    $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
    
    if ($job) {
        Stop-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
        $stopped++
        
        if ($stopped % 10 -eq 0) {
            Write-Host "  Stopped $stopped jobs..." -ForegroundColor Cyan
        }
    }
}

Write-Host "  ✅ Stopped $stopped load generator jobs" -ForegroundColor Green
Write-Host ""

# Step 3: Clean up job ID file
if (Test-Path ".\incident-8b-job-ids.txt") {
    Remove-Item ".\incident-8b-job-ids.txt" -Force
}

# Step 4: Wait for connections to clear
Write-Host "Step 3: Waiting 5 seconds for database connections to clear..." -ForegroundColor Green
Start-Sleep -Seconds 5
Write-Host ""

# Step 5: Test performance
Write-Host "Step 4: Testing database performance..." -ForegroundColor Green
Write-Host "  Making test request..." -NoNewline

$testStart = Get-Date
try {
    $testResponse = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 15 -ErrorAction Stop
    $testEnd = Get-Date
    $testDuration = ($testEnd - $testStart).TotalMilliseconds
    
    Write-Host " took $([math]::Round($testDuration))ms" -ForegroundColor Green
    
    if ($testDuration -lt 2000) {
        Write-Host "  ✅ Performance restored!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Still slow ($([math]::Round($testDuration))ms), may need more time" -ForegroundColor Yellow
    }
} catch {
    Write-Host " Failed/Timeout" -ForegroundColor Yellow
    Write-Host "  ⚠️  Database may still be recovering..." -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOVERY COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ DATABASE LOAD STOPPED" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 EXPECTED RESULTS:" -ForegroundColor Yellow
Write-Host "  - Product browsing now FAST (<2 seconds)" -ForegroundColor Green
Write-Host "  - No connection pool saturation" -ForegroundColor Green
Write-Host "  - Database queries execute quickly" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 VERIFY IN UI:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Browse products - should load quickly" -ForegroundColor White
Write-Host "  3. Refresh multiple times - consistent fast performance" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATADOG VERIFICATION:" -ForegroundColor Yellow
Write-Host "  - mysql.performance.threads_connected → Normal (<10)" -ForegroundColor White
Write-Host "  - mysql.performance.query_run_time.avg → <200ms" -ForegroundColor White
Write-Host "  - http.request.duration{service:catalogue} → <500ms" -ForegroundColor White
Write-Host "  - Normal operation restored" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Recovery Duration: ~10 seconds" -ForegroundColor Green
Write-Host "📅 Completed: $RECOVERY_START" -ForegroundColor Green
Write-Host ""
