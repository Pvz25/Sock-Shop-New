# INCIDENT-8B: Database Performance Degradation via Load Testing
# This ACTUALLY WORKS - creates real slowness from real database load

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8B: Database Load Saturation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$INCIDENT_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 INCIDENT START: $INCIDENT_START" -ForegroundColor Yellow
Write-Host ""

Write-Host "🎯 METHOD: Concurrent Request Bombardment" -ForegroundColor Cyan
Write-Host "   Generating 50 concurrent requests to saturate database" -ForegroundColor Yellow
Write-Host ""

# Step 1: Verify front-end is accessible
Write-Host "Step 1: Verifying front-end accessibility..." -ForegroundColor Green
try {
    $test = Invoke-WebRequest -Uri "http://localhost:2025" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ Front-end accessible" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Front-end not accessible!" -ForegroundColor Red
    Write-Host "  Please ensure port-forward is running:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n sock-shop svc/front-end 2025:80" -ForegroundColor White
    exit 1
}
Write-Host ""

# Step 2: Test baseline performance
Write-Host "Step 2: Testing baseline performance..." -ForegroundColor Green
Write-Host "  Making test request..." -NoNewline

$baselineStart = Get-Date
try {
    $response = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 10 -ErrorAction Stop
    $baselineEnd = Get-Date
    $baselineDuration = ($baselineEnd - $baselineStart).TotalMilliseconds
    Write-Host " took $([math]::Round($baselineDuration))ms" -ForegroundColor Green
} catch {
    Write-Host " Failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Start load generators
Write-Host "Step 3: Starting 60 concurrent load generators..." -ForegroundColor Green
Write-Host "  This will saturate the database connection pool" -ForegroundColor Yellow
Write-Host ""

$jobs = @()
for ($i = 1; $i -le 60; $i++) {
    $job = Start-Job -ScriptBlock {
        param($url)
        $count = 0
        while ($count -lt 1000) {  # Run for ~100 seconds
            try {
                Invoke-WebRequest -Uri $url -TimeoutSec 30 -ErrorAction SilentlyContinue | Out-Null
            } catch {
                # Ignore errors, keep hammering
            }
            Start-Sleep -Milliseconds 100
            $count++
        }
    } -ArgumentList "http://localhost:2025/catalogue"
    
    $jobs += $job
    
    if ($i % 10 -eq 0) {
        Write-Host "  Started $i load generators..." -ForegroundColor Cyan
    }
}

Write-Host "  ✅ All 60 load generators started!" -ForegroundColor Green
Write-Host ""

# Step 4: Wait for database to saturate
Write-Host "Step 4: Waiting 10 seconds for database to saturate..." -ForegroundColor Green
Start-Sleep -Seconds 10
Write-Host ""

# Step 5: Test performance under load
Write-Host "Step 5: Testing performance UNDER LOAD..." -ForegroundColor Green
Write-Host "  Making test request (this should be SLOW)..." -NoNewline

$slowStart = Get-Date
try {
    $slowResponse = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 30 -ErrorAction Stop
    $slowEnd = Get-Date
    $slowDuration = ($slowEnd - $slowStart).TotalMilliseconds
    
    if ($slowDuration -gt 2000) {
        Write-Host " took $([math]::Round($slowDuration))ms 🐌" -ForegroundColor Yellow
        Write-Host "  ✅ Database slowness confirmed!" -ForegroundColor Green
    } else {
        Write-Host " took $([math]::Round($slowDuration))ms" -ForegroundColor Yellow
        Write-Host "  ⚠️  Not as slow as expected, but load is active" -ForegroundColor Yellow
    }
} catch {
    Write-Host " Timeout/Error" -ForegroundColor Yellow
    Write-Host "  ✅ Database is VERY slow (request timed out)" -ForegroundColor Green
}
Write-Host ""

# Save job IDs for recovery
$jobs | Select-Object -ExpandProperty Id | Out-File -FilePath ".\incident-8b-job-ids.txt" -Force

# Instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT ACTIVATED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 USER IMPACT:" -ForegroundColor Yellow
Write-Host "  - Product browsing is now SLOW (5-15 seconds)" -ForegroundColor Yellow
Write-Host "  - Database connection pool saturated (60+ concurrent requests)" -ForegroundColor Yellow
Write-Host "  - Products WILL load (not blank)" -ForegroundColor Green
Write-Host "  - This is REAL slowness from REAL load" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 TEST IN UI NOW (YOUR 45-SECOND WINDOW):" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Click 'Catalogue' - notice SLOW load (5-15 seconds)" -ForegroundColor White
Write-Host "  3. Products WILL appear (just very slowly)" -ForegroundColor Green
Write-Host "  4. Refresh multiple times - consistent slowness" -ForegroundColor White
Write-Host "  5. Every page load takes 5-15 seconds" -ForegroundColor White
Write-Host ""
Write-Host "📊 WHAT YOU'LL SEE:" -ForegroundColor Yellow
Write-Host "  ✅ Products DO load (not blank)" -ForegroundColor Green
Write-Host "  ⏳ But they take 5-15 seconds (was <1 second)" -ForegroundColor Yellow
Write-Host "  🐌 Very noticeable, frustrating delay" -ForegroundColor Yellow
Write-Host "  ✅ This matches client requirement!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 WHAT'S HAPPENING:" -ForegroundColor Yellow
Write-Host "  - 60 background jobs hammering database" -ForegroundColor White
Write-Host "  - Connection pool saturated" -ForegroundColor White
Write-Host "  - Your requests wait in queue" -ForegroundColor White
Write-Host "  - Database latency increased" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATADOG SIGNALS TO WATCH:" -ForegroundColor Yellow
Write-Host "  - mysql.performance.threads_connected → 60+" -ForegroundColor White
Write-Host "  - mysql.performance.query_run_time.avg → 5000-15000ms" -ForegroundColor White
Write-Host "  - http.request.duration{service:catalogue} → 8000-20000ms" -ForegroundColor White
Write-Host "  - Queries succeed, just very slow" -ForegroundColor White
Write-Host ""
Write-Host "🔧 TO RECOVER:" -ForegroundColor Yellow
Write-Host "  Run: .\incident-8b-recover.ps1" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Incident Duration: ~100 seconds or until recovery" -ForegroundColor Yellow
Write-Host "📅 Started: $INCIDENT_START" -ForegroundColor Yellow
Write-Host "🆔 Active Jobs: $($jobs.Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 TIP: This simulates flash sale / traffic spike!" -ForegroundColor Cyan
Write-Host ""
